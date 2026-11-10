from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.exceptions import PermissionDenied
from django.db.models import Q

from .models import Subject, SubjectAssignment, StudentWork
from .serializers import SubjectSerializer, SubjectAssignmentSerializer, StudentWorkSerializer
from academics.models import Department, AcademicYear, Schema
from faculty.models import Faculty


class AddSubjectView(generics.CreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SubjectSerializer
    queryset = Subject.objects.all()

    def create(self, request, *args, **kwargs):
        from timetable.views import _resolve_department_for_user
        data = request.data
        required = ["department", "semester", "subject_name", "subject_code"]
        missing = [k for k in required if data.get(k) is None or (isinstance(data.get(k), str) and not data.get(k).strip())]
        if missing:
            errors = {k: ["This field is mandatory."] for k in missing}
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and str(data["department"]) != str(dept.id):
                return Response(
                    {"error": f"You are the HOD of {dept.name}. You cannot create subjects for another department."},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Parse and validate credits & teaching hours per week
        try:
            credits = int(data.get("credits", 4))
            theory_hours = int(data.get("theory_hours", 3))
            tutorial_hours = int(data.get("tutorial_hours", 0))
            practical_hours = int(data.get("practical_hours", 0))
            practical_sessions = int(data.get("practical_sessions", 0))
            practical_dur = int(data.get("practical_duration_per_session", 0))

            if any(x < 0 for x in [credits, theory_hours, tutorial_hours, practical_hours, practical_sessions, practical_dur]):
                return Response({"error": "Teaching hours and credits cannot be negative."}, status=status.HTTP_400_BAD_REQUEST)

            if practical_sessions > 0 and practical_dur > 0 and practical_hours == 0:
                practical_hours = practical_sessions * practical_dur

            total_hours = theory_hours + tutorial_hours + practical_hours
        except (ValueError, TypeError):
            return Response({"error": "Invalid format for credits or teaching hours."}, status=status.HTTP_400_BAD_REQUEST)

        code = str(data.get("subject_code", "")).strip()
        dept_id = data["department"]
        sem_id = data["semester"]
        ay_id = data.get("academic_year") or data.get("academic_year_id")

        # 1. Subject Master Reuse check across Academic Years
        existing_subject = Subject.objects.filter(
            department_id=dept_id,
            semester_id=sem_id,
            subject_code=code
        ).first()

        if existing_subject:
            if ay_id:
                ay = AcademicYear.objects.filter(id=ay_id).first()
                if not ay:
                    return Response({"error": f"Academic year {ay_id} not found."}, status=status.HTTP_400_BAD_REQUEST)
                # Check if already offered in this academic year
                existing_offering = SubjectAssignment.objects.filter(
                    subject=existing_subject,
                    academic_year=ay,
                    department_id=dept_id,
                    semester_id=sem_id
                ).first()
                if existing_offering:
                    return Response({
                        "error": f"Subject with code '{code}' is already offered for {ay.year_name}.",
                        "subject": SubjectSerializer(existing_subject).data
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                # Create academic year offering for existing master subject
                SubjectAssignment.objects.create(
                    subject=existing_subject,
                    academic_year=ay,
                    department_id=existing_subject.department_id,
                    semester_id=existing_subject.semester_id,
                    is_active=True
                )
                return Response({
                    "message": f"Existing master subject '{existing_subject.subject_name}' ({existing_subject.subject_code}) successfully enabled for Academic Year {ay.year_name}.",
                    **SubjectSerializer(existing_subject).data
                }, status=status.HTTP_201_CREATED)
            else:
                return Response(
                    {"error": f"Subject with code '{code}' already exists in this department and semester."},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # Validate subject type (Theory, Lab, or Both)
        has_theory = data.get("has_theory")
        has_lab = data.get("has_lab")
        subject_type = data.get("subject_type")

        if isinstance(has_theory, str):
            has_theory = has_theory.lower() in ["true", "1", "yes"]
        if isinstance(has_lab, str):
            has_lab = has_lab.lower() in ["true", "1", "yes"]

        resolved_type = None
        if subject_type:
            st = str(subject_type).upper()
            if "PROJECT" in st:
                has_theory = False
                has_lab = False
                resolved_type = "PROJECT"
            elif "BOTH" in st or ("PRACTICAL" in st and "THEORY" in st):
                has_theory = True
                has_lab = True
                resolved_type = "BOTH"
            elif "LAB" in st or "PRACTICAL" in st:
                has_theory = False
                has_lab = True
                resolved_type = "LAB"
            elif "THEORY" in st:
                has_theory = True
                has_lab = False
                resolved_type = "THEORY"

        if has_theory is None and has_lab is None and not resolved_type:
            if len(code) >= 4 and code[3].upper() == 'L':
                has_lab = True
                has_theory = False
                resolved_type = "LAB"
            else:
                has_theory = True
                has_lab = False
                resolved_type = "THEORY"

        if resolved_type != "PROJECT" and not has_theory and not has_lab:
            return Response(
                {"error": "Please select a valid subject type (Theory, Lab/Practical, Theory + Lab, or Project)."},
                status=status.HTTP_400_BAD_REQUEST
            )

        mutable_data = request.data.copy() if hasattr(request.data, "copy") else dict(request.data)
        if resolved_type == "PROJECT":
            mutable_data["has_theory"] = False
            mutable_data["has_lab"] = False
            mutable_data["subject_type"] = "PROJECT"
            mutable_data["credits"] = credits
            mutable_data["theory_hours"] = theory_hours or 0
            mutable_data["tutorial_hours"] = tutorial_hours or 0
            mutable_data["practical_hours"] = practical_hours or 0
            mutable_data["practical_sessions"] = practical_sessions or 0
            mutable_data["practical_duration_per_session"] = practical_dur or 0
            mutable_data["total_teaching_hours"] = int(data.get("total_teaching_hours", total_hours) or total_hours)
        else:
            resolved_type = "BOTH" if (has_theory and has_lab) else ("LAB" if has_lab else "THEORY")
            mutable_data["has_theory"] = bool(has_theory)
            mutable_data["has_lab"] = bool(has_lab)
            mutable_data["subject_type"] = resolved_type
            mutable_data["credits"] = credits
            mutable_data["theory_hours"] = theory_hours
            mutable_data["tutorial_hours"] = tutorial_hours
            mutable_data["practical_hours"] = practical_hours
            mutable_data["practical_sessions"] = practical_sessions
            mutable_data["practical_duration_per_session"] = practical_dur
            mutable_data["total_teaching_hours"] = total_hours

        # Offering department for elective subjects
        offering_dept_id = data.get("offering_department") or data.get("offering_department_id")
        if offering_dept_id:
            mutable_data["offering_department"] = offering_dept_id

        # Schema can default to first schema if omitted
        if not mutable_data.get("schema"):
            first_schema = Schema.objects.first()
            if first_schema:
                mutable_data["schema"] = first_schema.id

        serializer = self.get_serializer(data=mutable_data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        new_subject = serializer.instance

        if ay_id:
            ay = AcademicYear.objects.filter(id=ay_id).first()
            if ay:
                SubjectAssignment.objects.get_or_create(
                    subject=new_subject,
                    academic_year=ay,
                    department_id=new_subject.department_id,
                    semester_id=new_subject.semester_id,
                    defaults={"is_active": True}
                )

        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)


class GetSubjectsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from timetable.views import _resolve_department_for_user
        schema_id = request.query_params.get("schema", None)
        semester = request.query_params.get("semester", None)
        department_id = request.query_params.get("department_id", None)
        include_all = (request.query_params.get("include_all", "") or request.query_params.get("all", "")).lower() in ["true", "1"]
        cross_dept = (request.query_params.get("cross_department", "")).lower() in ["true", "1"]

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD" and not department_id and not (include_all or cross_dept):
            dept = _resolve_department_for_user(request.user)
            if dept:
                department_id = dept.id

        subjects = Subject.objects.all().select_related('department', 'semester')

        if department_id and str(department_id).lower() != "all":
            subjects = subjects.filter(department_id=department_id)
        if schema_id:
            subjects = subjects.filter(schema_id=schema_id)
        if semester:
            subjects = subjects.filter(semester_id=semester)

        assigned_subject_ids = set()
        if user_role in ["PROFESSOR", "FACULTY"]:
            from timetable.views import _resolve_faculty_for_user
            fac = _resolve_faculty_for_user(request.user)
            if fac:
                assigned_subject_ids = set(SubjectAssignment.objects.filter(faculty=fac).values_list('subject_id', flat=True))

        ay_param = request.query_params.get("academic_year", None) or request.query_params.get("academic_year_id", None)
        assignments_map = {}
        if ay_param and str(ay_param).lower() != "all":
            from django.db.models import Q
            ay_filter = Q(academic_year_id=int(ay_param)) if str(ay_param).isdigit() else Q(academic_year__year_name=ay_param)
            assignments = SubjectAssignment.objects.filter(ay_filter).select_related('faculty', 'academic_year')
            for a in assignments:
                assignments_map[a.subject_id] = a
        else:
            # Under 'All Academic Years', populate each unique master subject with its latest assignment
            all_assignments = SubjectAssignment.objects.select_related('faculty', 'academic_year').order_by('-academic_year__year_name', '-id')
            for a in all_assignments:
                if a.subject_id not in assignments_map:
                    assignments_map[a.subject_id] = a

        result = []
        for s in subjects:
            assign = assignments_map.get(s.id)
            is_assigned = bool(assign and assign.faculty_id)
            fac_name = assign.faculty.name if (assign and assign.faculty) else None
            fac_id = assign.faculty_id if assign else None
            ay_label = assign.academic_year.year_name if (assign and assign.academic_year) else (
                str(ay_param) if ay_param else None
            )

            offering_dept = s.get_offering_department() if getattr(s, "is_elective", False) else s.department
            offering_dept_id = offering_dept.id if offering_dept else s.department_id
            offering_dept_name = getattr(offering_dept, "name", getattr(s.department, "name", ""))

            result.append({
                "id": s.id,
                "code": s.subject_code,
                "name": s.subject_name,
                "semester": s.semester_id,
                "semester_no": getattr(getattr(s, "semester", None), "sem_number", s.semester_id),
                "department_id": s.department_id,
                "department_name": getattr(s.department, "name", ""),
                "offering_department_id": offering_dept_id,
                "offering_department_name": offering_dept_name,
                "is_elective": getattr(s, "is_elective", False),
                "has_theory": getattr(s, "has_theory", True),
                "has_lab": getattr(s, "has_lab", False),
                "subject_type": getattr(s, "subject_type", "THEORY"),
                "parent_subject_id": s.parent_subject_id,
                "subject_group": s.subject_group,
                "credits": getattr(s, "credits", 4),
                "theory_hours": getattr(s, "theory_hours", 3),
                "tutorial_hours": getattr(s, "tutorial_hours", 0),
                "practical_hours": getattr(s, "practical_hours", 0),
                "practical_sessions": getattr(s, "practical_sessions", 0),
                "practical_duration_per_session": getattr(s, "practical_duration_per_session", 0),
                "practical_display": getattr(s, "practical_display", str(getattr(s, "practical_hours", 0))),
                "total_teaching_hours": getattr(s, "total_teaching_hours", 3),
                "is_assigned": is_assigned,
                "assigned_faculty_id": fac_id,
                "assigned_faculty_name": fac_name,
                "academic_year": ay_label,
                "is_offered": bool(assign.is_active) if assign else True,
                "is_assigned_to_me": (s.id in assigned_subject_ids) if user_role in ["PROFESSOR", "FACULTY"] else True,
            })
        return Response(result, status=status.HTTP_200_OK)


ASSIGNMENT_CONFLICT_ERROR = (
    "This subject is already assigned to another faculty member for the selected department, "
    "semester, and academic year. Each subject can be assigned to only one faculty member per "
    "academic offering. Please select a different subject or update the existing assignment."
)


class AssignSubjectsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from timetable.views import _resolve_department_for_user
        from django.db import transaction
        from attendance.models import LabBatch

        data = request.data
        department_id = data.get('department_id')
        assignments = data.get('assignments')
        update_existing = data.get('update_existing', False)
        if isinstance(update_existing, str):
            update_existing = update_existing.lower() in ['true', '1', 'yes']

        if not department_id or not assignments:
            return Response({"error": "Missing required parameters"}, status=status.HTTP_400_BAD_REQUEST)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and str(department_id) != str(dept.id):
                return Response(
                    {"error": f"You are the HOD of {dept.name}. You cannot assign subjects for another department."},
                    status=status.HTTP_403_FORBIDDEN
                )

        # 1. Intra-payload duplicate check
        seen_keys = set()
        for assignment in assignments:
            sub_key = str(assignment.get('subject_id') or assignment.get('subject_code'))
            sem_key = str(assignment.get('semester'))
            ay_key = str(assignment.get('academic_year'))
            key = (sub_key, sem_key, ay_key)
            if key in seen_keys:
                return Response({
                    "error": ASSIGNMENT_CONFLICT_ERROR,
                    "detail": f"Duplicate subject '{assignment.get('subject_code') or assignment.get('subject_id')}' in assignment list."
                }, status=status.HTTP_400_BAD_REQUEST)
            seen_keys.add(key)

        # 2. Pre-validate all assignments against database conflicts
        validated_items = []
        for assignment in assignments:
            subject_id = assignment.get('subject_id')
            subject_code = assignment.get('subject_code')
            faculty_id = assignment.get('faculty_id')
            semester_id = assignment.get('semester')
            academic_year_id = assignment.get('academic_year')

            if not all([faculty_id, semester_id, academic_year_id]) or not (subject_id or subject_code):
                return Response({"error": "Missing required fields in assignment"}, status=status.HTTP_400_BAD_REQUEST)

            subject = None
            if subject_id:
                subject = Subject.objects.filter(id=subject_id).first()
            if not subject and subject_code:
                subject = Subject.objects.filter(subject_code=subject_code, department_id=department_id, semester_id=semester_id).first()
                if not subject:
                    subject = Subject.objects.filter(subject_code=subject_code, department_id=department_id).first()
                if not subject:
                    subject = Subject.objects.filter(subject_code=subject_code).first()

            if not subject:
                return Response({"error": f"Subject '{subject_code or subject_id}' not found."}, status=status.HTTP_400_BAD_REQUEST)

            try:
                faculty = Faculty.objects.get(id=faculty_id)
            except Faculty.DoesNotExist:
                return Response({"error": f"Faculty with id {faculty_id} not found"}, status=status.HTTP_400_BAD_REQUEST)

            # Elective offering department faculty validation
            if getattr(subject, 'is_elective', False):
                offering_dept = subject.get_offering_department()
                offering_dept_id = offering_dept.id if offering_dept else subject.department_id
                offering_dept_name = getattr(offering_dept, 'name', getattr(subject.department, 'name', 'another department'))
                if faculty.department_id != offering_dept_id:
                    return Response({
                        "error": f"Faculty '{faculty.name}' belongs to {getattr(faculty.department, 'name', 'another department')}. "
                                 f"For elective subject '{subject.subject_code} - {subject.subject_name}', "
                                 f"only faculty members belonging to offering department ({offering_dept_name}) can be assigned."
                    }, status=status.HTTP_400_BAD_REQUEST)
            else:
                if faculty.department_id != department_id:
                    home_dept_name = getattr(subject.department, 'name', 'the home department')
                    return Response({
                        "error": f"Faculty '{faculty.name}' belongs to {getattr(faculty.department, 'name', 'another department')}. "
                                 f"For core subject '{subject.subject_code} - {subject.subject_name}', "
                                 f"only faculty members belonging to {home_dept_name} can be assigned."
                    }, status=status.HTTP_400_BAD_REQUEST)

            existing = SubjectAssignment.objects.filter(
                subject=subject,
                department_id=department_id,
                semester_id=semester_id,
                academic_year_id=academic_year_id,
            ).select_related('faculty').first()

            if existing and existing.faculty and existing.faculty_id != faculty.id and not update_existing:
                return Response({
                    "error": ASSIGNMENT_CONFLICT_ERROR,
                    "conflicting_subject": subject.subject_code,
                    "conflicting_subject_name": subject.subject_name,
                    "current_faculty": existing.faculty.name if existing.faculty else "Unassigned",
                    "current_faculty_id": existing.faculty_id,
                    "assignment_id": existing.id
                }, status=status.HTTP_400_BAD_REQUEST)

            validated_items.append({
                "subject": subject,
                "faculty": faculty,
                "department_id": department_id,
                "semester_id": semester_id,
                "academic_year_id": academic_year_id,
            })

        # 3. Save atomically, sync lab batches, and auto-pair Theory+Lab components
        assigned_details = []
        with transaction.atomic():
            for item in validated_items:
                assignment, _ = SubjectAssignment.objects.update_or_create(
                    subject=item["subject"],
                    academic_year_id=item["academic_year_id"],
                    department_id=item["department_id"],
                    semester_id=item["semester_id"],
                    defaults={
                        "faculty": item["faculty"],
                    }
                )
                LabBatch.objects.filter(
                    subject=item["subject"],
                    academic_year_id=item["academic_year_id"],
                ).update(faculty=item["faculty"])

                # Theory+Lab same faculty default pairing:
                # When assigning a Theory component, find paired Lab component via parent_subject or subject_group
                subject = item["subject"]
                paired_labs = []
                if subject.has_theory:
                    child_labs = list(Subject.objects.filter(parent_subject=subject, has_lab=True))
                    paired_labs.extend(child_labs)
                    if subject.subject_group:
                        group_labs = list(Subject.objects.filter(
                            department_id=item["department_id"],
                            semester_id=item["semester_id"],
                            subject_group=subject.subject_group,
                            has_lab=True
                        ).exclude(id=subject.id))
                        for gl in group_labs:
                            if gl not in paired_labs:
                                paired_labs.append(gl)

                linked_assigned_names = []
                for lab_sub in paired_labs:
                    SubjectAssignment.objects.update_or_create(
                        subject=lab_sub,
                        academic_year_id=item["academic_year_id"],
                        department_id=item["department_id"],
                        semester_id=item["semester_id"],
                        defaults={
                            "faculty": item["faculty"],
                        }
                    )
                    LabBatch.objects.filter(
                        subject=lab_sub,
                        academic_year_id=item["academic_year_id"],
                    ).update(faculty=item["faculty"])
                    linked_assigned_names.append(f"{lab_sub.subject_code} - {lab_sub.subject_name}")

                detail_msg = f"Assigned {subject.subject_code} to {item['faculty'].name}."
                if linked_assigned_names:
                    detail_msg += f" Automatically assigned paired lab component(s): {', '.join(linked_assigned_names)}."
                elif subject.has_theory and not subject.has_lab:
                    detail_msg += " Note: No linked lab component found for this theory subject. You can link a lab component via parent_subject or subject_group."

                assigned_details.append({
                    "subject_code": subject.subject_code,
                    "subject_name": subject.subject_name,
                    "faculty_name": item["faculty"].name,
                    "linked_labs": linked_assigned_names,
                    "detail": detail_msg
                })

        return Response({
            "message": "Subjects assigned successfully!",
            "assignments": assigned_details
        }, status=status.HTTP_200_OK)


class DeleteSubjectView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        from timetable.views import _resolve_department_for_user
        try:
            subject = Subject.objects.get(pk=pk)
        except Subject.DoesNotExist:
            return Response({"error": "Subject not found."}, status=status.HTTP_404_NOT_FOUND)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if not dept or subject.department_id != dept.id:
                return Response(
                    {"error": f"You can only delete subjects in your own department ({dept.name if dept else 'None'})."},
                    status=status.HTTP_403_FORBIDDEN
                )
        elif user_role not in ["PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
            return Response({"error": "You do not have permission to delete subjects."}, status=status.HTTP_403_FORBIDDEN)

        subject_name = subject.subject_name
        subject_code = subject.subject_code
        subject.delete()
        return Response({"message": f"Subject '{subject_code} - {subject_name}' deleted successfully."}, status=status.HTTP_200_OK)


class GetAssignedProfessorsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        semester = request.query_params.get('semester')
        department_id = request.query_params.get('department_id')
        academic_year = request.query_params.get('academic_year')
        subject_id = request.query_params.get('subject_id')
        subject_code = request.query_params.get('subject_code')

        assignments = SubjectAssignment.objects.all().select_related(
            'faculty', 'subject', 'subject__department', 'subject__semester', 'department', 'semester', 'academic_year'
        )

        if subject_id:
            assignments = assignments.filter(subject_id=subject_id)
        if subject_code:
            assignments = assignments.filter(subject__subject_code=subject_code)
        if semester:
            assignments = assignments.filter(Q(semester_id=semester) | Q(subject__semester_id=semester))
        if department_id:
            assignments = assignments.filter(Q(department_id=department_id) | Q(subject__department_id=department_id))
        if academic_year:
            assignments = assignments.filter(Q(academic_year_id=academic_year) | Q(academic_year__year_name=academic_year))
  
        if not assignments.exists():
            return Response([], status=status.HTTP_200_OK)

        result = []
        for a in assignments:
            result.append({
                "id": a.id,
                "subject_id": a.subject.id,
                "subject_name": a.subject.subject_name,
                "subject_code": a.subject.subject_code,
                "faculty_id": a.faculty.id if a.faculty else None,
                "professor_name": a.faculty.name if a.faculty else "Unassigned",
                "department": getattr(a.department or a.subject.department, "name", ""),
                "department_id": a.department_id or getattr(a.subject, "department_id", None),
                "semester": getattr(a.semester or a.subject.semester, "sem_number", ""),
                "semester_id": a.semester_id or getattr(a.subject, "semester_id", None),
                "academic_year_id": a.academic_year_id,
            })

        return Response(result, status=status.HTTP_200_OK)


class ViewAssignedByDepartmentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        department_id = request.query_params.get('department_id')
        if not department_id:
            return Response({"error": "Department ID is required"}, status=status.HTTP_400_BAD_REQUEST)

        assignments = SubjectAssignment.objects.filter(department_id=department_id).select_related('faculty', 'subject')
        result = []
        for a in assignments:
            result.append({
                "faculty_id": a.faculty.id if a.faculty else None,
                "professor_name": a.faculty.name if a.faculty else "Unassigned",
                "subject_code": a.subject.subject_code,
                "subject_name": a.subject.subject_name,
                "semester": a.subject.semester_id,
                "academic_year": a.academic_year_id
            })

        return Response(result, status=status.HTTP_200_OK)


class GetAssignedSubjectsForProfessorView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        requested_faculty_id = request.query_params.get('faculty_id')
        target_faculty_id = None

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
            # A professor can NEVER query another professor's assigned subjects
            if requested_faculty_id and str(requested_faculty_id) != str(fac.id):
                return Response({"error": "You are not authorized to view other professors' assigned subjects."}, status=status.HTTP_403_FORBIDDEN)
            target_faculty_id = fac.id

        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if requested_faculty_id:
                target_fac = Faculty.objects.filter(id=requested_faculty_id).first()
                if not target_fac:
                    return Response({"error": "Faculty member not found."}, status=status.HTTP_404_NOT_FOUND)
                if dept and target_fac.department_id != dept.id:
                    return Response({"error": "Faculty does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)
                target_faculty_id = target_fac.id
            else:
                # Under Faculty Access, return only subjects assigned to the logged-in HOD for teaching
                fac = _resolve_faculty_for_user(request.user)
                if fac:
                    target_faculty_id = fac.id
                else:
                    return Response([], status=status.HTTP_200_OK)

        elif user_role in ["PRINCIPAL", "SYSTEM"] or request.user.is_superuser:
            if requested_faculty_id:
                target_faculty_id = requested_faculty_id
            else:
                fac = _resolve_faculty_for_user(request.user)
                if fac:
                    target_faculty_id = fac.id
                else:
                    return Response({"error": "faculty_id query parameter is required for administrator query."}, status=status.HTTP_400_BAD_REQUEST)
        else:
            return Response({"error": "You do not have permission to view faculty subjects."}, status=status.HTTP_403_FORBIDDEN)

        if not target_faculty_id:
            return Response({"error": "Faculty profile could not be determined."}, status=status.HTTP_400_BAD_REQUEST)

        assignments = SubjectAssignment.objects.filter(faculty_id=target_faculty_id).select_related('subject', 'faculty', 'academic_year', 'semester')

        if not assignments.exists():
            return Response([], status=status.HTTP_200_OK)

        # Handle academic year filtering and deduplication for 'All Academic Years'
        ay_param = request.query_params.get("academic_year") or request.query_params.get("academic_year_id")
        if ay_param and str(ay_param).lower() != "all":
            from django.db.models import Q
            ay_filter = Q(academic_year_id=int(ay_param)) if str(ay_param).isdigit() else Q(academic_year__year_name=ay_param)
            assignments = assignments.filter(ay_filter)
        else:
            # Under 'All Academic Years', ensure each unique Subject Master record appears only ONCE
            # (e.g. Parallel Computing BCS702 assigned in both 2025-2026 and 2026-2027 should not appear duplicated)
            seen_subject_ids = set()
            unique_assignments = []
            for a in assignments.order_by('-academic_year__year_name', '-id'):
                if a.subject_id not in seen_subject_ids:
                    seen_subject_ids.add(a.subject_id)
                    unique_assignments.append(a)
            assignments = unique_assignments

        result = []
        for a in assignments:
            result.append({
                "id": a.subject.id,
                "subject_id": a.subject.id,
                "assignment_id": a.id,
                "faculty_id": a.faculty_id,
                "faculty_name": getattr(a.faculty, "name", ""),
                "subject_code": a.subject.subject_code,
                "subject_name": a.subject.subject_name,
                "has_theory": getattr(a.subject, "has_theory", True),
                "has_lab": getattr(a.subject, "has_lab", False),
                "subject_type": getattr(a.subject, "subject_type", "THEORY"),
                "semester": getattr(a.semester, "sem_number", None) or getattr(getattr(a.subject, "semester", None), "sem_number", None),
                "academic_year": getattr(a.academic_year, "year_name", None),
                "department_name": getattr(getattr(a.subject, "department", None), "name", "")
            })

        return Response(result, status=status.HTTP_200_OK)


class StudentWorkListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = StudentWorkSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        subject_id = self.request.query_params.get("subject_id")
        qs = StudentWork.objects.all().select_related("subject", "faculty", "subject__department", "subject__semester")

        if user_role == "STUDENT":
            from students.models import Student
            student = getattr(user, "student", None) or Student.objects.filter(user=user).first()
            if student:
                qs = qs.filter(
                    subject__department=student.department,
                    subject__semester=student.semester
                )
            else:
                qs = qs.none()
        elif user_role == "PROFESSOR":
            from timetable.views import _resolve_faculty_for_user
            fac = _resolve_faculty_for_user(user)
            if fac:
                qs = qs.filter(Q(faculty=fac) | Q(created_by_user=user))
            else:
                qs = qs.filter(created_by_user=user)
        elif user_role == "HOD":
            from timetable.views import _resolve_department_for_user, _resolve_faculty_for_user
            assigned_only = self.request.query_params.get('assigned_only') == 'true'
            if assigned_only:
                fac = _resolve_faculty_for_user(user)
                if fac:
                    qs = qs.filter(Q(faculty=fac) | Q(created_by_user=user))
                else:
                    qs = qs.filter(created_by_user=user)
            else:
                dept = _resolve_department_for_user(user)
                if dept:
                    qs = qs.filter(subject__department=dept)

        if subject_id and str(subject_id).isdigit():
            qs = qs.filter(subject_id=int(subject_id))

        return qs

    def perform_create(self, serializer):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        subject = serializer.validated_data.get("subject")
        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(user)

        if user_role == "PROFESSOR":
            if fac and not SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists():
                raise PermissionDenied("You can only assign work for subjects assigned to you.")

        work = serializer.save(faculty=fac, created_by_user=user)

        # Notify enrolled students
        try:
            from students.models import Student
            from announcements.models import Notification
            enrolled_students = Student.objects.filter(
                department=subject.department,
                semester=subject.semester,
                user__isnull=False
            )
            for st in enrolled_students:
                if st.user:
                    Notification.objects.create(
                        recipient=st.user,
                        title=f"New Assignment: {work.title}",
                        message=f"Faculty assigned new work for {subject.subject_code} - {subject.subject_name}. Due: {work.due_date or 'No deadline'}. Max marks: {work.max_marks}.",
                        notification_type="GENERAL"
                    )
        except Exception as e:
            pass


class StudentWorkDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = StudentWorkSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    queryset = StudentWork.objects.all()


class LinkSubjectsView(APIView):
    """
    API endpoint for HOD to link a Theory subject and a Lab subject
    via parent_subject or subject_group.
    Usage: POST /subjects/link_components/
    Body: {"parent_subject_id": 1, "component_subject_id": 2} OR {"subject_ids": [1, 2], "subject_group": "CS501_GRP"}
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from timetable.views import _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        dept = None
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)

        parent_id = request.data.get("parent_subject_id")
        comp_id = request.data.get("component_subject_id")
        subject_group = request.data.get("subject_group")
        subject_ids = request.data.get("subject_ids", [])

        if parent_id and comp_id:
            try:
                parent = Subject.objects.get(id=parent_id)
                comp = Subject.objects.get(id=comp_id)
            except Subject.DoesNotExist:
                return Response({"error": "Subject not found."}, status=status.HTTP_404_NOT_FOUND)

            if dept and (parent.department_id != dept.id or comp.department_id != dept.id):
                return Response({"error": "You can only link subjects within your own department."}, status=status.HTTP_403_FORBIDDEN)

            comp.parent_subject = parent
            if subject_group:
                comp.subject_group = subject_group
                parent.subject_group = subject_group
                parent.save(update_fields=["subject_group"])
            comp.save(update_fields=["parent_subject"] + (["subject_group"] if subject_group else []))

            return Response({
                "message": f"Successfully linked '{comp.subject_code}' as component of '{parent.subject_code}'.",
                "parent_subject": {"id": parent.id, "code": parent.subject_code},
                "component_subject": {"id": comp.id, "code": comp.subject_code}
            }, status=status.HTTP_200_OK)

        elif subject_group and subject_ids:
            subs = Subject.objects.filter(id__in=subject_ids)
            if dept:
                for s in subs:
                    if s.department_id != dept.id:
                        return Response({"error": "All subjects must belong to your department."}, status=status.HTTP_403_FORBIDDEN)
            subs.update(subject_group=subject_group)
            return Response({
                "message": f"Successfully grouped {subs.count()} subjects under group '{subject_group}'.",
                "subject_ids": subject_ids
            }, status=status.HTTP_200_OK)

        return Response({"error": "Provide either parent_subject_id & component_subject_id or subject_ids & subject_group."}, status=status.HTTP_400_BAD_REQUEST)
