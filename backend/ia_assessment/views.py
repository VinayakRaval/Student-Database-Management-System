from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied, ValidationError
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Sum, Q, Count
from django.db import transaction
from django.utils import timezone

from .models import IATestSetup, IAMark, IAAggregate, MarksCorrectionRequest, MarksSecurityAuditLog
from .serializers import (
    IATestSetupSerializer, IAMarkSerializer, IAAggregateSerializer,
    MarksCorrectionRequestSerializer, MarksSecurityAuditLogSerializer
)
from academics.models import SemesterFinalization
from students.models import Student
from subjects.models import Subject, SubjectAssignment
from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user



class IATestSetupListView(generics.ListAPIView):
    serializer_class = IATestSetupSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        subject_id = self.request.query_params.get("subject_id")
        if not subject_id:
            return IATestSetup.objects.none()
        return IATestSetup.objects.filter(subject_id=subject_id).order_by('id')


# -------------------------------
# 1️⃣ Create IA Test Setup
# -------------------------------
class IATestSetupCreateView(generics.CreateAPIView):
    serializer_class = IATestSetupSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        subject = serializer.validated_data.get('subject')

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                raise PermissionDenied("Faculty profile not found for user.")
            if not SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists():
                raise PermissionDenied("You are not assigned to teach this subject.")

        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and subject.department_id != dept.id:
                raise PermissionDenied("This subject does not belong to your department.")

        elif user_role not in ["PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
            raise PermissionDenied("You do not have permission to create an IA test.")

        ia_type = serializer.validated_data.get('ia_type')
        ia_name = serializer.validated_data.get('ia_name')
        max_marks = serializer.validated_data.get('max_marks')
        component_type = request.data.get('component_type')
        batch_id = request.data.get('batch_id') or request.data.get('batch')
        batch = None
        if batch_id:
            from attendance.models import LabBatch
            batch = LabBatch.objects.filter(id=batch_id).first()

        if not component_type:
            if ia_type in ["LabTest1", "LabTest2"] or batch:
                component_type = "LAB"
            else:
                component_type = "THEORY"

        # Look up existing test setup by (subject, ia_type, ia_name) matching DB uniqueness constraint
        test_obj = IATestSetup.objects.filter(
            subject=subject,
            ia_type=ia_type,
            ia_name=ia_name
        ).first()

        # Check if semester is finalized and locked
        is_sem_finalized = False
        if subject.department and subject.semester:
            is_sem_finalized = SemesterFinalization.objects.filter(
                department=subject.department,
                semester=subject.semester,
                is_finalized=True
            ).exists()

        if test_obj and (test_obj.is_locked or is_sem_finalized):
            MarksSecurityAuditLog.objects.create(
                event_type='REJECTED_MODIFICATION_ATTEMPT',
                actor=request.user,
                role=user_role,
                subject=subject,
                ia_test=test_obj,
                details=f"Unauthorized attempt to modify locked IA test setup '{test_obj.ia_name}' ({test_obj.ia_type}) for subject {subject.subject_code}.",
                reason="Semester Completed – Marks Locked",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {"error": "Semester Completed – Marks Locked. Modifications to this assessment are permanently locked."},
                status=status.HTTP_403_FORBIDDEN
            )

        if not test_obj and is_sem_finalized:
            MarksSecurityAuditLog.objects.create(
                event_type='REJECTED_MODIFICATION_ATTEMPT',
                actor=request.user,
                role=user_role,
                subject=subject,
                details=f"Unauthorized attempt to create new IA test setup in finalized semester {subject.semester.sem_number} for {subject.department.name}.",
                reason="Semester Completed – Marks Locked",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {"error": "Semester Completed – Marks Locked. No new tests can be created for a finalized semester."},
                status=status.HTTP_403_FORBIDDEN
            )

        assessment_date = request.data.get('assessment_date') or serializer.validated_data.get('assessment_date')
        submission_deadline = request.data.get('submission_deadline') or serializer.validated_data.get('submission_deadline')
        instructions = request.data.get('instructions') or serializer.validated_data.get('instructions')
        test_status = request.data.get('status') or serializer.validated_data.get('status') or "CONFIGURED"

        if test_obj:
            update_fields = ['max_marks', 'faculty', 'component_type', 'batch', 'updated_at']
            if test_obj.max_marks != max_marks:
                test_obj.max_marks = max_marks
            test_obj.faculty = request.user
            test_obj.component_type = component_type
            if batch:
                test_obj.batch = batch
            if assessment_date:
                test_obj.assessment_date = assessment_date
                update_fields.append('assessment_date')
            if submission_deadline:
                test_obj.submission_deadline = submission_deadline
                update_fields.append('submission_deadline')
            if instructions is not None:
                test_obj.instructions = instructions
                update_fields.append('instructions')
            if test_status and test_obj.status not in ['LOCKED', 'PUBLISHED', 'SUBMITTED', 'APPROVED', 'VERIFIED']:
                test_obj.status = test_status
                update_fields.append('status')
            test_obj.save(update_fields=list(set(update_fields)))
            created = False
        else:
            test_obj = IATestSetup.objects.create(
                subject=subject,
                faculty=request.user,
                ia_type=ia_type,
                ia_name=ia_name,
                component_type=component_type,
                batch=batch,
                max_marks=max_marks,
                assessment_date=assessment_date if assessment_date else None,
                submission_deadline=submission_deadline if submission_deadline else None,
                instructions=instructions if instructions else "",
                status=test_status if test_status else "CONFIGURED"
            )
            created = True

        resp_serializer = self.get_serializer(test_obj)
        return Response(resp_serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


# -------------------------------
# 2️⃣ Fetch Active Students for IA Entry
# -------------------------------
class FacultyActiveStudentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        subject_id = request.query_params.get("subject_id", "").strip().replace("/", "")
        if not subject_id.isdigit():
            return Response({"error": "Invalid subject_id"}, status=status.HTTP_400_BAD_REQUEST)

        subject = get_object_or_404(Subject, id=int(subject_id))

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        assignment = None
        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
            assignment = SubjectAssignment.objects.filter(subject=subject, faculty=fac).first()
            if not assignment:
                return Response({"error": "You are not assigned to teach this subject."}, status=status.HTTP_403_FORBIDDEN)

        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and subject.department_id != dept.id:
                return Response({"error": "This subject does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)
            assignment = SubjectAssignment.objects.filter(subject=subject).first()

        else:
            assignment = SubjectAssignment.objects.filter(subject=subject).first()

        target_dept = (assignment.department or assignment.subject.department) if assignment else subject.department
        target_sem = (assignment.semester or assignment.subject.semester) if assignment else subject.semester

        if getattr(subject, 'is_elective', False):
            from subjects.models import ElectiveSubjectEnrollment
            enrolled_ids = list(ElectiveSubjectEnrollment.objects.filter(
                subject=subject, is_active=True
            ).values_list('student_id', flat=True))
            students_qs = Student.objects.filter(id__in=enrolled_ids)
        else:
            students_qs = Student.objects.filter(status__iexact="active")
            if target_dept:
                students_qs = students_qs.filter(department=target_dept)
            if target_sem:
                students_qs = students_qs.filter(semester=target_sem)
            if assignment and assignment.academic_year:
                students_qs = students_qs.filter(academic_year=assignment.academic_year)

        # Batch filter for LAB IA
        batch_id = request.query_params.get("batch_id")
        test_id = request.query_params.get("test_id")
        if test_id and str(test_id).isdigit():
            t_obj = IATestSetup.objects.filter(id=int(test_id)).first()
            if t_obj and t_obj.batch:
                batch_id = t_obj.batch_id

        if batch_id and str(batch_id).isdigit():
            from attendance.models import LabBatchStudent
            batch_student_ids = LabBatchStudent.objects.filter(batch_id=int(batch_id)).values_list('student_id', flat=True)
            students_qs = students_qs.filter(id__in=batch_student_ids)

        students = students_qs.order_by("usn").values("id", "name", "usn")
        return Response(list(students))


# -------------------------------
# 3️⃣ Bulk Mark Entry / Update
# -------------------------------
class BulkIAMarkUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, test_id):
        try:
            ia_test = get_object_or_404(IATestSetup, id=test_id)

            user_role = (getattr(request.user, "role", "") or "").upper()
            if user_role == "FACULTY":
                user_role = "PROFESSOR"

            # 🔒 CRITICAL: Check permanent lock status BEFORE ANY ROLE PROCESSING
            is_sem_finalized = False
            if ia_test.subject.department and ia_test.subject.semester:
                is_sem_finalized = SemesterFinalization.objects.filter(
                    department=ia_test.subject.department,
                    semester=ia_test.subject.semester,
                    is_finalized=True
                ).exists()

            if ia_test.is_locked or is_sem_finalized:
                MarksSecurityAuditLog.objects.create(
                    event_type='REJECTED_MODIFICATION_ATTEMPT',
                    actor=request.user,
                    role=user_role,
                    subject=ia_test.subject,
                    ia_test=ia_test,
                    details=f"Attempted marks update for locked IA test '{ia_test.ia_name}' ({ia_test.subject.subject_code}). Permanently rejected for role {user_role}.",
                    reason="Semester Completed – Marks Locked",
                    ip_address=request.META.get('REMOTE_ADDR')
                )
                return Response(
                    {
                        "error": "Semester Completed – Marks Locked. Student marks for this semester are permanently finalized and cannot be modified, deleted, or overwritten by any role.",
                        "is_locked": True,
                        "lock_reason": ia_test.lock_reason or "Semester Completed – Marks Locked"
                    },
                    status=status.HTTP_403_FORBIDDEN
                )

            if user_role == "PROFESSOR":
                fac = _resolve_faculty_for_user(request.user)
                if not fac:
                    return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)

                # Strictly enforce: Only the faculty member assigned to teach this subject can enter or update IA marks
                if not SubjectAssignment.objects.filter(subject=ia_test.subject, faculty=fac).exists():
                    return Response(
                        {"error": "You are not assigned to teach this subject. Only the assigned faculty member can enter or update IA marks."},
                        status=status.HTTP_403_FORBIDDEN
                    )

                # Lockout check: If already submitted, approved, published or locked, faculty cannot modify
                if ia_test.status in ["SUBMITTED", "APPROVED", "VERIFIED", "PUBLISHED", "LOCKED"]:
                    return Response(
                        {
                            "error": f"Assessment is in '{ia_test.status}' status and cannot be edited. Please contact your HOD to return the assessment for correction if changes are needed.",
                            "status": ia_test.status,
                            "is_locked": ia_test.is_locked,
                        },
                        status=status.HTTP_403_FORBIDDEN
                    )

            elif user_role == "HOD":
                dept = _resolve_department_for_user(request.user)
                if dept:
                    is_dept_subject = (ia_test.subject.department_id == dept.id)
                    is_assigned_to_dept = SubjectAssignment.objects.filter(subject=ia_test.subject, department=dept).exists()
                    if not is_dept_subject and not is_assigned_to_dept:
                        return Response({"error": "This subject does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)

            elif user_role not in ["PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
                return Response({"error": "You do not have permission to update IA marks."}, status=status.HTTP_403_FORBIDDEN)

            marks_data = request.data.get("marks", [])
            if not marks_data:
                return Response({"error": "No marks data provided."}, status=status.HTTP_400_BAD_REQUEST)

            # Collect allowed departments and semesters from subject and subject assignments
            allowed_dept_ids = set()
            allowed_sem_ids = set()
            if ia_test.subject.department_id:
                allowed_dept_ids.add(ia_test.subject.department_id)
            if ia_test.subject.semester_id:
                allowed_sem_ids.add(ia_test.subject.semester_id)

            for a in SubjectAssignment.objects.filter(subject=ia_test.subject):
                if a.department_id:
                    allowed_dept_ids.add(a.department_id)
                if a.semester_id:
                    allowed_sem_ids.add(a.semester_id)

            submit_action = bool(request.data.get("submit", False) or (request.data.get("status", "").upper() == "SUBMITTED"))

            with transaction.atomic():
                for entry in marks_data:
                    student_id = entry.get("student_id")
                    student = Student.objects.filter(id=student_id).first()
                    if not student:
                        return Response({"error": f"Student with ID {student_id} not found."}, status=status.HTTP_400_BAD_REQUEST)

                    # Validate student eligibility against allowed departments/semesters
                    if allowed_dept_ids and student.department_id not in allowed_dept_ids:
                        return Response(
                            {"error": f"Student {getattr(student, 'usn', student.id)} does not belong to an eligible department for this subject."},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    if allowed_sem_ids and student.semester_id not in allowed_sem_ids:
                        return Response(
                            {"error": f"Student {getattr(student, 'usn', student.id)} does not belong to an eligible semester for this subject."},
                            status=status.HTTP_400_BAD_REQUEST
                        )

                    is_absent = bool(entry.get("is_absent", False))
                    is_exempted = bool(entry.get("is_exempted", False))
                    remarks = str(entry.get("remarks") or "").strip()

                    if is_absent or is_exempted:
                        obtained_val = 0.0
                    else:
                        obtained = entry.get("obtained_marks", 0)
                        try:
                            obtained_val = float(obtained)
                        except (ValueError, TypeError):
                            return Response({"error": f"Invalid mark value for student {getattr(student, 'usn', student.id)}."}, status=status.HTTP_400_BAD_REQUEST)

                        # Validate mark limits
                        if obtained_val < 0 or obtained_val > ia_test.max_marks:
                            return Response(
                                {"error": f"Obtained mark {obtained_val} for student {getattr(student, 'usn', student.id)} is invalid. Must be between 0 and {ia_test.max_marks}."},
                                status=status.HTTP_400_BAD_REQUEST
                            )

                    IAMark.objects.update_or_create(
                        ia_test=ia_test,
                        student=student,
                        defaults={
                            "obtained_marks": obtained_val,
                            "is_absent": is_absent,
                            "is_exempted": is_exempted,
                            "remarks": remarks,
                            "status": "SUBMITTED" if submit_action else "DRAFT"
                        }
                    )

                if submit_action:
                    ia_test.status = "SUBMITTED"
                    ia_test.submitted_at = timezone.now()
                    ia_test.submitted_by = request.user
                    ia_test.save(update_fields=['status', 'submitted_at', 'submitted_by', 'updated_at'])

                    # Audit log
                    MarksSecurityAuditLog.objects.create(
                        event_type='IA_TEST_SUBMITTED',
                        actor=request.user,
                        role=user_role,
                        subject=ia_test.subject,
                        ia_test=ia_test,
                        details=f"IA Marks for '{ia_test.ia_name}' ({ia_test.subject.subject_code}) submitted to HOD by {request.user.get_full_name() or request.user.email}.",
                        ip_address=request.META.get('REMOTE_ADDR')
                    )

                    # Send in-app notification to HOD(s)
                    from announcements.models import Notification
                    from django.contrib.auth import get_user_model
                    UserModel = get_user_model()
                    hod_users = UserModel.objects.filter(role__iexact="HOD")
                    if ia_test.subject.department:
                        hod_users = hod_users.filter(department=ia_test.subject.department)
                    for hod in hod_users:
                        try:
                            Notification.objects.create(
                                recipient=hod,
                                title=f"IA Marks Submitted: {ia_test.subject.subject_code} - {ia_test.ia_name}",
                                message=f"Faculty {request.user.get_full_name() or request.user.email} has submitted marks for {ia_test.ia_name} ({ia_test.subject.subject_name}) for verification.",
                                notification_type="IA"
                            )
                        except Exception:
                            pass

                elif ia_test.status not in ["APPROVED", "VERIFIED", "PUBLISHED", "LOCKED"]:
                    ia_test.status = "IN_PROGRESS"
                    ia_test.save(update_fields=['status', 'updated_at'])

                self.update_aggregates(ia_test)

            msg = "Marks submitted to HOD successfully" if submit_action else "Marks draft saved successfully"
            return Response({"message": msg, "status": ia_test.status}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": f"Failed to save IA marks: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

    def update_aggregates(self, ia_test):
        try:
            from .calculation import recalculate_subject_aggregates
            recalculate_subject_aggregates(ia_test.subject)
        except Exception as e:
            import logging
            logging.getLogger(__name__).exception("Error updating IA aggregates: %s", e)



# -------------------------------
# 4️⃣ Faculty View IA Marks
# -------------------------------
class FacultyIAMarkListView(generics.ListAPIView):
    serializer_class = IAMarkSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        subject_id = self.request.query_params.get("subject_id")
        if not subject_id:
            return IAMark.objects.none()

        user_role = (getattr(self.request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(self.request.user)
            if not fac or not SubjectAssignment.objects.filter(subject_id=subject_id, faculty=fac).exists():
                return IAMark.objects.none()
            qs = IAMark.objects.filter(
                ia_test__subject_id=subject_id
            )

        elif user_role == "HOD":
            dept = _resolve_department_for_user(self.request.user)
            qs = IAMark.objects.filter(
                ia_test__subject_id=subject_id,
                ia_test__subject__department=dept
            )
        else:
            qs = IAMark.objects.filter(ia_test__subject_id=subject_id)

        component_type = self.request.query_params.get("component_type")
        if component_type:
            qs = qs.filter(ia_test__component_type__iexact=component_type)
        return qs.select_related("ia_test", "student")


# -------------------------------
# 5️⃣ Student View Own IA Marks
# -------------------------------
class StudentIAMarkListView(generics.ListAPIView):
    serializer_class = IAMarkSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        student = getattr(self.request.user, "student", None)
        if not student:
            student = Student.objects.filter(user=self.request.user).first()
        if not student:
            return IAMark.objects.none()
        # Students can only view published IA marks
        qs = IAMark.objects.filter(student=student, ia_test__is_published=True)
        component_type = self.request.query_params.get("component_type")
        if component_type:
            qs = qs.filter(ia_test__component_type__iexact=component_type)
        return qs.select_related("ia_test", "ia_test__subject")


class StudentIAPortalView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        student = getattr(request.user, "student", None)
        if not student:
            student = Student.objects.filter(user=request.user).first()
        if not student:
            return Response(
                {"error": "Student profile not found for authenticated user."},
                status=status.HTTP_404_NOT_FOUND
            )

        from subjects.models import Subject, ElectiveSubjectEnrollment
        regular_subjects = Subject.objects.filter(
            department=student.department,
            semester=student.semester
        )
        elective_sub_ids = ElectiveSubjectEnrollment.objects.filter(
            student=student, is_active=True
        ).values_list('subject_id', flat=True)
        elective_subjects = Subject.objects.filter(id__in=elective_sub_ids)

        all_subjects = (regular_subjects | elective_subjects).distinct().order_by('subject_code')

        from .calculation import calculate_student_final_ia

        subjects_data = []
        for sub in all_subjects:
            agg = calculate_student_final_ia(student, sub, only_published=True)

            published_marks = IAMark.objects.filter(
                student=student,
                ia_test__subject=sub,
                ia_test__is_published=True
            ).select_related("ia_test").order_by("ia_test__id")

            tests = []
            for m in published_marks:
                max_m = float(m.ia_test.max_marks) if m.ia_test.max_marks > 0 else 25.0
                obt_m = float(m.obtained_marks) if not m.is_absent else 0.0
                pct = round((obt_m / max_m * 100), 1) if max_m > 0 else 0.0

                if m.is_exempted:
                    status_str = "Exempted"
                elif m.is_absent:
                    status_str = "Absent"
                elif pct >= 40.0:
                    status_str = "Satisfactory"
                else:
                    status_str = "Needs Improvement"

                tests.append({
                    "id": m.ia_test.id,
                    "test_name": m.ia_test.ia_name,
                    "type": m.ia_test.ia_type,
                    "component_type": m.ia_test.component_type,
                    "date_conducted": m.ia_test.assessment_date.strftime("%d %b %Y") if m.ia_test.assessment_date else "N/A",
                    "max_marks": max_m,
                    "obtained_marks": obt_m,
                    "percentage": pct,
                    "status": status_str,
                    "remarks": m.remarks or (m.ia_test.hod_remarks if m.ia_test.hod_remarks else "-"),
                    "is_absent": m.is_absent,
                    "is_exempted": m.is_exempted,
                })

            subjects_data.append({
                "subject_id": sub.id,
                "code": sub.subject_code,
                "name": sub.subject_name,
                "semester": f"Semester {sub.semester.sem_number}" if sub.semester else "N/A",
                "final_ia_marks": float(agg.final_ia_marks),
                "max_marks": float(agg.max_marks),
                "average_score": float(agg.average_marks),
                "calculation_method": agg.calculation_method,
                "breakdown": agg.breakdown,
                "tests": tests,
            })

        return Response({
            "student": {
                "id": student.id,
                "name": student.name,
                "usn": student.usn,
                "semester": student.semester.sem_number if student.semester else "N/A",
                "department": student.department.name if student.department else "N/A",
            },
            "subjects": subjects_data
        }, status=status.HTTP_200_OK)



# -------------------------------
# 6️⃣ HOD IA & Academic Performance View
# -------------------------------
class HODAcademicPerformanceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        dept = None
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if not dept:
                return Response({"error": "Department not found for HOD user."}, status=status.HTTP_404_NOT_FOUND)
        elif user_role in ["PRINCIPAL", "SYSTEM"] or request.user.is_superuser:
            dept_id = request.query_params.get("department_id")
            if dept_id:
                from academics.models import Department
                dept = Department.objects.filter(id=dept_id).first()

        from subjects.models import SubjectAssignment
        from django.db.models import Q
        subjects_qs = Subject.objects.all()
        if dept:
            subjects_qs = subjects_qs.filter(
                Q(department=dept) | Q(subjectassignment__department=dept)
            ).distinct()

        tests_qs = IATestSetup.objects.filter(subject__in=subjects_qs).select_related("subject", "faculty")
        
        # Apply filters
        sem_id = request.query_params.get("semester_id")
        if sem_id:
            tests_qs = tests_qs.filter(subject__semester_id=sem_id)
        sub_id = request.query_params.get("subject_id")
        if sub_id:
            tests_qs = tests_qs.filter(subject_id=sub_id)
        ia_type = request.query_params.get("ia_type")
        if ia_type:
            tests_qs = tests_qs.filter(ia_type__iexact=ia_type)
        ay_id = request.query_params.get("academic_year_id") or request.query_params.get("academic_year")
        if ay_id:
            assigned_sub_ids = SubjectAssignment.objects.filter(academic_year_id=ay_id).values_list("subject_id", flat=True)
            tests_qs = tests_qs.filter(subject_id__in=assigned_sub_ids)

        # 1. Submission Tracker
        submissions = []
        for t in tests_qs:
            submitted_count = IAMark.objects.filter(ia_test=t).count()
            assignment = SubjectAssignment.objects.filter(subject=t.subject).first()
            target_dept = (assignment.department or t.subject.department) if assignment else t.subject.department
            if t.batch:
                eligible_count = Student.objects.filter(lab_batch_assignments__batch=t.batch).count()
            else:
                target_sem = (assignment.semester or t.subject.semester) if assignment else t.subject.semester
                eligible_count = Student.objects.filter(department=target_dept, semester=target_sem, status__iexact="active").count() if target_dept and target_sem else 0

            if eligible_count == 0 and submitted_count == 0:
                status_text = "NO_STUDENTS"
                status_label = "No students assigned"
            elif eligible_count > 0 and submitted_count == 0:
                status_text = "NOT_STARTED"
                status_label = "Not started"
            elif eligible_count > 0 and submitted_count < eligible_count:
                status_text = "IN_PROGRESS"
                status_label = f"In Progress ({submitted_count}/{eligible_count})"
            elif eligible_count > 0 and submitted_count >= eligible_count:
                status_text = "COMPLETED"
                status_label = "Completed"
            else:
                status_text = "SUBMITTED"
                status_label = "Submitted"

            fac_name = "Unassigned"
            if assignment and assignment.faculty:
                fac_name = assignment.faculty.name
            elif t.faculty:
                fac = getattr(t.faculty, "faculty_profile", None)
                fac_name = fac.name if fac else t.faculty.email

            submissions.append({
                "test_id": t.id,
                "subject_id": t.subject.id,
                "subject_code": t.subject.subject_code,
                "subject_name": t.subject.subject_name,
                "semester": t.subject.semester.sem_number if t.subject.semester else "N/A",
                "ia_type": t.ia_type,
                "ia_name": t.ia_name,
                "component_type": t.component_type,
                "batch_id": t.batch_id,
                "batch_name": t.batch.name if t.batch else None,
                "max_marks": t.max_marks,
                "faculty_name": fac_name,
                "submitted_count": submitted_count,
                "eligible_count": eligible_count,
                "missing_marks": max(0, eligible_count - submitted_count),
                "status": status_text,
                "status_label": status_label,
                "workflow_status": t.status,
                "is_published": t.is_published,
                "published_at": t.published_at.isoformat() if t.published_at else None,
                "instructions": t.instructions or "",
                "hod_remarks": t.hod_remarks or "",
                "assessment_date": t.assessment_date.isoformat() if t.assessment_date else None,
                "submission_deadline": t.submission_deadline.isoformat() if t.submission_deadline else None,
                "is_locked": t.is_locked,
                "is_own_test": (t.faculty == request.user),
                "created_at": t.created_at.strftime("%Y-%m-%d"),
            })

        # 2. Subject-wise Results & Pass Percentages
        subject_results = []
        filtered_subjects = subjects_qs
        if sem_id:
            filtered_subjects = filtered_subjects.filter(semester_id=sem_id)
        if sub_id:
            filtered_subjects = filtered_subjects.filter(id=sub_id)
        if ay_id:
            assigned_sub_ids = SubjectAssignment.objects.filter(academic_year_id=ay_id).values_list("subject_id", flat=True)
            filtered_subjects = filtered_subjects.filter(id__in=assigned_sub_ids)

        for sub in filtered_subjects:
            marks = IAMark.objects.filter(ia_test__subject=sub).select_related("ia_test")
            total_marks_count = marks.count()
            if total_marks_count > 0:
                pass_count = 0
                total_pct_sum = 0
                max_obtained = 0
                min_obtained = 9999
                for m in marks:
                    max_m = m.ia_test.max_marks
                    pct = (float(m.obtained_marks) / max_m * 100) if max_m > 0 else 0
                    total_pct_sum += pct
                    if pct >= 40.0:
                        pass_count += 1
                    if float(m.obtained_marks) > max_obtained:
                        max_obtained = float(m.obtained_marks)
                    if float(m.obtained_marks) < min_obtained:
                        min_obtained = float(m.obtained_marks)

                avg_pct = round(total_pct_sum / total_marks_count, 1)
                pass_pct = round(pass_count / total_marks_count * 100, 1)
            else:
                avg_pct = 0.0
                pass_pct = 0.0
                max_obtained = 0.0
                min_obtained = 0.0

            assignment = SubjectAssignment.objects.filter(subject=sub).first()
            subject_results.append({
                "subject_id": sub.id,
                "subject_code": sub.subject_code,
                "subject_name": sub.subject_name,
                "semester": sub.semester.sem_number if sub.semester else "N/A",
                "faculty_name": assignment.faculty.name if assignment and assignment.faculty else "Unassigned",
                "tests_count": tests_qs.filter(subject=sub).count(),
                "marks_count": total_marks_count,
                "average_percentage": avg_pct,
                "pass_percentage": pass_pct,
                "highest_score": max_obtained,
                "lowest_score": min_obtained if min_obtained != 9999 else 0.0,
            })

        # 3. Students Needing Academic Support (<40%)
        needing_support = []
        all_dept_marks = IAMark.objects.filter(ia_test__subject__in=filtered_subjects).select_related("student", "ia_test", "ia_test__subject")
        for m in all_dept_marks:
            max_m = m.ia_test.max_marks
            pct = (float(m.obtained_marks) / max_m * 100) if max_m > 0 else 0
            if pct < 40.0:
                needing_support.append({
                    "mark_id": m.id,
                    "student_id": m.student.id,
                    "usn": m.student.usn,
                    "student_name": m.student.name,
                    "semester": m.student.semester.sem_number if m.student.semester else "N/A",
                    "subject_code": m.ia_test.subject.subject_code,
                    "subject_name": m.ia_test.subject.subject_name,
                    "ia_name": m.ia_test.ia_name,
                    "obtained_marks": float(m.obtained_marks),
                    "max_marks": max_m,
                    "percentage": round(pct, 1),
                })
        needing_support.sort(key=lambda x: x["percentage"])

        # 4. Missing or Suspicious Marks
        suspicious_marks = []
        for m in all_dept_marks:
            if float(m.obtained_marks) == 0:
                suspicious_marks.append({
                    "mark_id": m.id,
                    "student_usn": m.student.usn,
                    "student_name": m.student.name,
                    "subject_code": m.ia_test.subject.subject_code,
                    "ia_name": m.ia_test.ia_name,
                    "obtained_marks": 0.0,
                    "max_marks": m.ia_test.max_marks,
                    "reason": "Scored zero / absent without mark",
                })

        total_sub_marks = len(all_dept_marks)
        total_passed = sum(1 for m in all_dept_marks if (float(m.obtained_marks) / (m.ia_test.max_marks or 1)) >= 0.40)
        overall_pass_pct = round(total_passed / total_sub_marks * 100, 1) if total_sub_marks > 0 else 0.0

        dept_info = {
            "id": dept.id if dept else None,
            "name": dept.name if dept else ("All Departments" if user_role in ["PRINCIPAL", "SYSTEM"] else "General Department"),
            "code": getattr(dept, "code", dept.name if dept else "ALL"),
            "user_email": request.user.email or getattr(request.user, "user_id", "") or str(request.user),
            "user_role": user_role,
        }

        return Response({
            "department_info": dept_info,
            "overview": {
                "total_tests": tests_qs.count(),
                "overall_pass_pct": overall_pass_pct,
                "needing_support_count": len(needing_support),
                "suspicious_count": len(suspicious_marks),
                "completed_submissions": sum(1 for s in submissions if s["status"] in ["COMPLETED", "SUBMITTED"]),
                "pending_submissions": sum(1 for s in submissions if s["status"] in ["PENDING", "NOT_STARTED", "IN_PROGRESS"]),
            },
            "submissions": submissions,
            "subject_results": subject_results,
            "needing_support": needing_support,
            "suspicious_marks": suspicious_marks,
        })


# -------------------------------
# 7️⃣ HOD Test Students Marks Drilldown View
# -------------------------------
class HODTestStudentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        test_id = request.query_params.get("test_id")
        if not test_id:
            return Response({"error": "test_id is required"}, status=status.HTTP_400_BAD_REQUEST)

        test = get_object_or_404(IATestSetup, id=test_id)
        marks = IAMark.objects.filter(ia_test=test).select_related("student", "student__semester")
        marks_by_student = {m.student_id: m for m in marks}

        assignment = SubjectAssignment.objects.filter(subject=test.subject).first()
        target_dept = (assignment.department or test.subject.department) if assignment else test.subject.department
        target_sem = (assignment.semester or test.subject.semester) if assignment else test.subject.semester

        students_qs = Student.objects.filter(status__iexact="active")
        if target_dept and target_sem:
            students_qs = students_qs.filter(department=target_dept, semester=target_sem)
        elif target_dept:
            students_qs = students_qs.filter(department=target_dept)

        student_ids = set(students_qs.values_list("id", flat=True)) | set(marks_by_student.keys())
        all_students = Student.objects.filter(id__in=student_ids).select_related("semester", "department").order_by("usn")

        results = []
        for s in all_students:
            m = marks_by_student.get(s.id)
            obtained = float(m.obtained_marks) if m else None
            max_m = test.max_marks
            pct = round((obtained / max_m * 100), 1) if (obtained is not None and max_m > 0) else None
            status_str = "Passed" if (pct is not None and pct >= 40.0) else ("Failed" if pct is not None else "Not Entered")
            results.append({
                "student_id": s.id,
                "usn": s.usn,
                "name": s.name,
                "semester": s.semester.sem_number if s.semester else "N/A",
                "obtained_marks": obtained,
                "max_marks": max_m,
                "percentage": pct,
                "status": status_str,
            })

        return Response({
            "test": {
                "id": test.id,
                "subject_code": test.subject.subject_code,
                "subject_name": test.subject.subject_name,
                "ia_name": test.ia_name,
                "ia_type": test.ia_type,
                "max_marks": test.max_marks,
                "is_locked": test.is_locked,
                "locked_at": test.locked_at,
                "locked_by": test.locked_by.get_full_name() if test.locked_by else None,
                "lock_reason": test.lock_reason,
            },
            "students": results
        })


# -------------------------------
# 8️⃣ Controlled Academic Marks Correction Workflow
# -------------------------------
class MarksCorrectionRequestCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        ia_test_id = request.data.get("ia_test_id") or request.data.get("ia_test")
        student_id = request.data.get("student_id") or request.data.get("student")
        requested_marks = request.data.get("requested_marks")
        reason = (request.data.get("reason") or "").strip()

        if not ia_test_id or not student_id or requested_marks is None or not reason:
            return Response(
                {"error": "ia_test_id, student_id, requested_marks, and a documented reason (minimum 5 chars) are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(reason) < 5:
            return Response(
                {"error": "A detailed documented reason is required (minimum 5 characters)."},
                status=status.HTTP_400_BAD_REQUEST
            )

        ia_test = get_object_or_404(IATestSetup, id=ia_test_id)
        student = get_object_or_404(Student, id=student_id)

        try:
            requested_marks = float(requested_marks)
        except (ValueError, TypeError):
            return Response({"error": "requested_marks must be a valid number."}, status=status.HTTP_400_BAD_REQUEST)

        if requested_marks < 0 or requested_marks > float(ia_test.max_marks):
            return Response(
                {"error": f"requested_marks must be between 0 and {ia_test.max_marks}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Scoping check: If Professor, verify assignment
        if role == "PROFESSOR":
            fac = _resolve_faculty_for_user(user)
            if not fac or not SubjectAssignment.objects.filter(subject=ia_test.subject, faculty=fac).exists():
                return Response(
                    {"error": "You are not assigned to teach this subject."},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Get or create initial IAMark record with internal flag
        mark = IAMark.objects.filter(ia_test=ia_test, student=student).first()
        if not mark:
            mark = IAMark(ia_test=ia_test, student=student, obtained_marks=0)
            mark._authorized_correction = True
            mark.save()

        # Check existing pending request
        pending_req = MarksCorrectionRequest.objects.filter(
            ia_test=ia_test,
            student=student,
            status='PENDING'
        ).first()
        if pending_req:
            return Response(
                {"error": f"A correction request for student {student.usn} ({ia_test.ia_name}) is already pending review."},
                status=status.HTTP_400_BAD_REQUEST
            )

        correction = MarksCorrectionRequest.objects.create(
            ia_test=ia_test,
            mark=mark,
            student=student,
            original_marks=mark.obtained_marks,
            requested_marks=requested_marks,
            reason=reason,
            requested_by=user,
            status='PENDING'
        )

        MarksSecurityAuditLog.objects.create(
            event_type='CORRECTION_REQUESTED',
            actor=user,
            role=role,
            subject=ia_test.subject,
            student=student,
            ia_test=ia_test,
            before_value=str(mark.obtained_marks),
            after_value=str(requested_marks),
            reason=reason,
            details=f"Correction requested by {user.get_full_name() or user.email} for {student.usn} in {ia_test.ia_name}: {mark.obtained_marks} -> {requested_marks}. Reason: {reason}",
            ip_address=request.META.get('REMOTE_ADDR')
        )

        serializer = MarksCorrectionRequestSerializer(correction)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class MarksCorrectionRequestListView(generics.ListAPIView):
    serializer_class = MarksCorrectionRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        qs = MarksCorrectionRequest.objects.select_related(
            'ia_test', 'ia_test__subject', 'student', 'requested_by', 'reviewed_by'
        ).all()

        if role == "PROFESSOR":
            qs = qs.filter(requested_by=user)
        elif role == "HOD":
            dept = _resolve_department_for_user(user)
            if dept:
                qs = qs.filter(ia_test__subject__department=dept)

        test_id = self.request.query_params.get("ia_test_id")
        if test_id:
            qs = qs.filter(ia_test_id=test_id)

        subject_id = self.request.query_params.get("subject_id")
        if subject_id:
            qs = qs.filter(ia_test__subject_id=subject_id)

        req_status = self.request.query_params.get("status")
        if req_status:
            qs = qs.filter(status=req_status.upper())

        return qs.order_by('-requested_at')


class MarksCorrectionRequestReviewView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        if role not in ["PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            return Response(
                {"error": "Unauthorized. Only the Principal or System Administrator can review and approve mark corrections for locked semesters."},
                status=status.HTTP_403_FORBIDDEN
            )

        correction = get_object_or_404(MarksCorrectionRequest, pk=pk)
        if correction.status != 'PENDING':
            return Response(
                {"error": f"This correction request has already been {correction.status.lower()}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        action = (request.data.get("action") or "").upper()
        remarks = request.data.get("remarks", "").strip()

        if action not in ["APPROVE", "REJECT"]:
            return Response({"error": "action must be either 'APPROVE' or 'REJECT'."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            if action == "APPROVE":
                correction.status = 'APPROVED'
                correction.reviewed_by = user
                correction.reviewed_at = timezone.now()
                correction.review_remarks = remarks
                correction.save()

                # Update the mark with authorized bypass flag
                mark = correction.mark
                before_val = str(mark.obtained_marks)
                mark._authorized_correction = True
                mark.obtained_marks = correction.requested_marks
                mark.save()

                # Update aggregate
                BulkIAMarkUpdateView().update_aggregates(correction.ia_test)

                # Log to immutable audit trail
                MarksSecurityAuditLog.objects.create(
                    event_type='CORRECTION_APPROVED',
                    actor=user,
                    role=role,
                    subject=correction.ia_test.subject,
                    student=correction.student,
                    ia_test=correction.ia_test,
                    before_value=before_val,
                    after_value=str(correction.requested_marks),
                    reason=correction.reason,
                    details=f"Authorized mark correction approved by {user.get_full_name() or user.email} for student {correction.student.usn} in {correction.ia_test.ia_name}: {before_val} -> {correction.requested_marks}. Remarks: {remarks}",
                    ip_address=request.META.get('REMOTE_ADDR')
                )

                return Response({
                    "message": f"Correction request approved successfully. Mark updated from {before_val} to {correction.requested_marks}.",
                    "status": "APPROVED",
                    "obtained_marks": float(correction.requested_marks),
                }, status=status.HTTP_200_OK)

            else:
                correction.status = 'REJECTED'
                correction.reviewed_by = user
                correction.reviewed_at = timezone.now()
                correction.review_remarks = remarks
                correction.save()

                MarksSecurityAuditLog.objects.create(
                    event_type='CORRECTION_REJECTED',
                    actor=user,
                    role=role,
                    subject=correction.ia_test.subject,
                    student=correction.student,
                    ia_test=correction.ia_test,
                    before_value=str(correction.original_marks),
                    after_value=str(correction.original_marks),
                    reason=remarks,
                    details=f"Mark correction request for student {correction.student.usn} rejected by {user.get_full_name() or user.email}. Remarks: {remarks}",
                    ip_address=request.META.get('REMOTE_ADDR')
                )

                return Response({
                    "message": "Correction request rejected.",
                    "status": "REJECTED"
                }, status=status.HTTP_200_OK)


class MarksSecurityAuditLogListView(generics.ListAPIView):
    serializer_class = MarksSecurityAuditLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            raise PermissionDenied("Only HOD, Principal, or System Administrator can view marks security audit logs.")

        qs = MarksSecurityAuditLog.objects.select_related('actor', 'subject', 'student', 'ia_test').all()

        if role == "HOD":
            dept = _resolve_department_for_user(user)
            if dept:
                qs = qs.filter(subject__department=dept)

        event_type = self.request.query_params.get("event_type")
        if event_type:
            qs = qs.filter(event_type=event_type)

        subject_id = self.request.query_params.get("subject_id")
        if subject_id:
            qs = qs.filter(subject_id=subject_id)

        return qs.order_by('-timestamp')


class IATestLockStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, test_id):
        ia_test = get_object_or_404(IATestSetup, id=test_id)
        is_sem_finalized = False
        if ia_test.subject.department and ia_test.subject.semester:
            is_sem_finalized = SemesterFinalization.objects.filter(
                department=ia_test.subject.department,
                semester=ia_test.subject.semester,
                is_finalized=True
            ).exists()

        is_locked = ia_test.is_locked or is_sem_finalized
        return Response({
            "id": ia_test.id,
            "ia_name": ia_test.ia_name,
            "ia_type": ia_type if (ia_type := getattr(ia_test, 'ia_type', None)) else None,
            "subject_code": ia_test.subject.subject_code,
            "is_locked": is_locked,
            "locked_at": ia_test.locked_at,
            "locked_by": ia_test.locked_by.get_full_name() if ia_test.locked_by else None,
            "lock_reason": ia_test.lock_reason or ("Semester Completed – Marks Locked" if is_sem_finalized else None)
        })


# -------------------------------
# 9️⃣ HOD IA Test Review Action (Verify or Return)
# -------------------------------
class IATestReviewView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, test_id):
        ia_test = get_object_or_404(IATestSetup, id=test_id)
        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            return Response({"error": "Only HOD, Principal, or Administrator can review IA test submissions."}, status=status.HTTP_403_FORBIDDEN)

        # Prohibit self-approval: HOD cannot approve their own IA assessment
        if (ia_test.faculty == user) or (hasattr(user, 'faculty_profile') and getattr(user.faculty_profile, 'id', None) == getattr(ia_test.faculty, 'id', None)):
            if role not in ["PRINCIPAL", "SYSTEM"] and not user.is_superuser:
                return Response({
                    "error": "Self-approval is strictly prohibited. As the instructor who created this assessment, you cannot approve your own submission. It must be reviewed by the Principal or Administrator."
                }, status=status.HTTP_403_FORBIDDEN)

        action = (request.data.get("action") or "").upper()
        remarks = request.data.get("remarks", "").strip()

        if action not in ["VERIFY", "APPROVE", "RETURN"]:
            return Response({"error": "action must be 'VERIFY' (or 'APPROVE') or 'RETURN'."}, status=status.HTTP_400_BAD_REQUEST)

        if action in ["VERIFY", "APPROVE"]:
            ia_test.status = "APPROVED"
            ia_test.verified_at = timezone.now()
            ia_test.approved_by = user
            ia_test.hod_remarks = remarks
            ia_test.save(update_fields=['status', 'verified_at', 'approved_by', 'hod_remarks', 'updated_at'])

            MarksSecurityAuditLog.objects.create(
                event_type='IA_TEST_APPROVED',
                actor=user,
                role=role,
                subject=ia_test.subject,
                ia_test=ia_test,
                details=f"IA Assessment '{ia_test.ia_name}' ({ia_test.subject.subject_code}) approved by HOD {user.get_full_name() or user.email}. Remarks: {remarks}",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            # Send notification to the instructor
            from announcements.models import Notification
            if ia_test.faculty:
                try:
                    Notification.objects.create(
                        recipient=ia_test.faculty,
                        title=f"IA Assessment Approved: {ia_test.subject.subject_code}",
                        message=f"Assessment '{ia_test.ia_name}' for {ia_test.subject.subject_name} was approved by HOD {user.get_full_name() or user.email}. Remarks: {remarks or 'Approved'}",
                        notification_type="IA"
                    )
                except Exception:
                    pass

            return Response({
                "message": f"Assessment '{ia_test.ia_name}' approved successfully.",
                "status": "APPROVED",
                "test_id": ia_test.id
            }, status=status.HTTP_200_OK)

        else: # RETURN for correction
            if not remarks:
                return Response({"error": "Remarks are mandatory when returning an assessment for correction."}, status=status.HTTP_400_BAD_REQUEST)

            ia_test.status = "RETURNED"
            ia_test.returned_at = timezone.now()
            ia_test.hod_remarks = remarks
            ia_test.save(update_fields=['status', 'returned_at', 'hod_remarks', 'updated_at'])

            MarksSecurityAuditLog.objects.create(
                event_type='IA_TEST_RETURNED',
                actor=user,
                role=role,
                subject=ia_test.subject,
                ia_test=ia_test,
                reason=remarks,
                details=f"IA Assessment '{ia_test.ia_name}' ({ia_test.subject.subject_code}) returned for correction by HOD {user.get_full_name() or user.email}. Remarks: {remarks}",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            # Send notification to the instructor
            from announcements.models import Notification
            if ia_test.faculty:
                try:
                    Notification.objects.create(
                        recipient=ia_test.faculty,
                        title=f"IA Assessment Returned: {ia_test.subject.subject_code}",
                        message=f"Assessment '{ia_test.ia_name}' for {ia_test.subject.subject_name} was returned by HOD for correction. Remarks: {remarks}",
                        notification_type="IA"
                    )
                except Exception:
                    pass

            return Response({
                "message": f"Assessment '{ia_test.ia_name}' returned to faculty for correction.",
                "status": "RETURNED",
                "test_id": ia_test.id,
                "remarks": remarks
            }, status=status.HTTP_200_OK)


# -------------------------------
# 9️⃣.1 Controlled IA Marks Publication View
# -------------------------------
class IATestPublishView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, test_id):
        ia_test = get_object_or_404(IATestSetup, id=test_id)
        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            return Response(
                {"error": "Only HOD, Principal, or Administrator can publish IA marks to students."},
                status=status.HTTP_403_FORBIDDEN
            )

        action = (request.data.get("action") or "PUBLISH").upper()

        if action == "UNPUBLISH":
            ia_test.is_published = False
            if ia_test.status == "PUBLISHED":
                ia_test.status = "APPROVED"
            ia_test.published_at = None
            ia_test.published_by = None
            ia_test.save(update_fields=['is_published', 'status', 'published_at', 'published_by', 'updated_at'])

            from .calculation import recalculate_subject_aggregates
            recalculate_subject_aggregates(ia_test.subject)

            return Response({
                "message": f"Assessment '{ia_test.ia_name}' unpublished. Marks are now hidden from student portals.",
                "is_published": False,
                "status": ia_test.status
            }, status=status.HTTP_200_OK)

        # Publish
        if ia_test.status not in ["APPROVED", "VERIFIED", "LOCKED", "PUBLISHED"]:
            return Response(
                {"error": f"Cannot publish assessment in '{ia_test.status}' status. Assessment must be Approved before publishing."},
                status=status.HTTP_400_BAD_REQUEST
            )

        now = timezone.now()
        ia_test.is_published = True
        if not ia_test.is_locked:
            ia_test.status = "PUBLISHED"
        ia_test.published_at = now
        ia_test.published_by = user
        ia_test.save(update_fields=['is_published', 'status', 'published_at', 'published_by', 'updated_at'])

        from .calculation import recalculate_subject_aggregates
        recalculate_subject_aggregates(ia_test.subject)

        MarksSecurityAuditLog.objects.create(
            event_type='IA_TEST_PUBLISHED',
            actor=user,
            role=role,
            subject=ia_test.subject,
            ia_test=ia_test,
            details=f"IA marks for '{ia_test.ia_name}' ({ia_test.subject.subject_code}) published to student portals by {user.get_full_name() or user.email}.",
            ip_address=request.META.get('REMOTE_ADDR')
        )

        from announcements.models import Notification
        marks = IAMark.objects.filter(ia_test=ia_test).select_related('student__user')
        notified_count = 0
        for m in marks:
            if m.student and getattr(m.student, 'user', None):
                try:
                    Notification.objects.create(
                        recipient=m.student.user,
                        title=f"IA Marks Published: {ia_test.subject.subject_code}",
                        message=f"Marks for '{ia_test.ia_name}' ({ia_test.subject.subject_name}) have been published. Check 'My IA Marks' in your portal.",
                        notification_type="IA"
                    )
                    notified_count += 1
                except Exception:
                    pass

        return Response({
            "message": f"Assessment '{ia_test.ia_name}' published successfully. {notified_count} students notified.",
            "is_published": True,
            "published_at": now.isoformat(),
            "status": ia_test.status,
            "notified_students_count": notified_count
        }, status=status.HTTP_200_OK)


class IACalculationSchemeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        subject_id = request.query_params.get("subject_id")
        from .calculation import get_active_scheme_for_subject
        from .serializers import IACalculationSchemeSerializer
        if subject_id and str(subject_id).isdigit():
            subject = Subject.objects.filter(id=int(subject_id)).first()
            if subject:
                scheme = get_active_scheme_for_subject(subject)
                serializer = IACalculationSchemeSerializer(scheme)
                return Response(serializer.data)

        schemes = IACalculationScheme.objects.filter(is_active=True)
        serializer = IACalculationSchemeSerializer(schemes, many=True)
        return Response(serializer.data)



# -------------------------------
# 🔟 HOD Pre-Lock Summary View (Validation & Readiness)
# -------------------------------
class HODPreLockSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            return Response({"error": "Only HOD, Principal, or Administrator can access pre-lock summary."}, status=status.HTTP_403_FORBIDDEN)

        dept = None
        if role == "HOD":
            dept = _resolve_department_for_user(user)
        dept_id = request.query_params.get("department_id")
        if dept_id and (role in ["PRINCIPAL", "SYSTEM"] or user.is_superuser or not dept):
            from academics.models import Department
            dept = Department.objects.filter(id=dept_id).first()

        semester_id = request.query_params.get("semester_id")

        subjects_qs = Subject.objects.all()
        if dept:
            subjects_qs = subjects_qs.filter(Q(department=dept) | Q(subjectassignment__department=dept)).distinct()
        if semester_id:
            subjects_qs = subjects_qs.filter(semester_id=semester_id)

        tests_qs = IATestSetup.objects.filter(subject__in=subjects_qs).select_related('subject', 'faculty', 'batch')

        total_tests = tests_qs.count()
        verified_tests = tests_qs.filter(status="VERIFIED").count()
        submitted_tests = tests_qs.filter(status="SUBMITTED").count()
        draft_tests = tests_qs.filter(status="DRAFT").count()
        returned_tests = tests_qs.filter(status="RETURNED").count()
        locked_tests = tests_qs.filter(is_locked=True).count()

        subjects_summary = []
        total_missing_marks = 0
        blocking_reasons = []

        for sub in subjects_qs:
            assignment = SubjectAssignment.objects.filter(subject=sub).first()
            target_dept = (assignment.department or sub.department) if assignment else sub.department
            target_sem = (assignment.semester or sub.semester) if assignment else sub.semester

            eligible_students_count = Student.objects.filter(
                department=target_dept,
                semester=target_sem,
                status__iexact="active"
            ).count() if target_dept and target_sem else 0

            sub_tests = tests_qs.filter(subject=sub)
            theory_tests = [t for t in sub_tests if t.component_type == "THEORY"]
            lab_tests = [t for t in sub_tests if t.component_type == "LAB"]

            # Missing marks for theory tests
            sub_missing_marks = 0
            for t in theory_tests:
                entered_count = IAMark.objects.filter(ia_test=t).count()
                missing = max(0, eligible_students_count - entered_count)
                sub_missing_marks += missing

            # Missing marks for lab tests
            for t in lab_tests:
                if t.batch:
                    batch_student_count = Student.objects.filter(lab_batch_assignments__batch=t.batch).count()
                else:
                    batch_student_count = eligible_students_count
                entered_count = IAMark.objects.filter(ia_test=t).count()
                missing = max(0, batch_student_count - entered_count)
                sub_missing_marks += missing

            total_missing_marks += sub_missing_marks

            fac_name = "Unassigned"
            if assignment and assignment.faculty:
                fac_name = assignment.faculty.name
            elif sub_tests.exists() and sub_tests.first().faculty:
                fac_name = getattr(sub_tests.first().faculty, 'email', str(sub_tests.first().faculty))

            is_subject_ready = (
                sub_tests.exists() and
                sub_missing_marks == 0 and
                all(t.status in ["VERIFIED", "SUBMITTED", "LOCKED"] for t in sub_tests)
            )

            subjects_summary.append({
                "subject_id": sub.id,
                "subject_code": sub.subject_code,
                "subject_name": sub.subject_name,
                "faculty_name": fac_name,
                "semester": sub.semester.sem_number if sub.semester else "N/A",
                "theory_tests_count": len(theory_tests),
                "lab_tests_count": len(lab_tests),
                "total_tests": len(sub_tests),
                "missing_marks_count": sub_missing_marks,
                "is_ready": is_subject_ready,
                "tests": [
                    {
                        "id": t.id,
                        "ia_name": t.ia_name,
                        "ia_type": t.ia_type,
                        "component_type": t.component_type,
                        "batch_name": t.batch.name if t.batch else None,
                        "max_marks": t.max_marks,
                        "status": t.status,
                        "is_locked": t.is_locked,
                    }
                    for t in sub_tests
                ]
            })

        # Check pending marks correction requests in dept/sem
        corrections_qs = MarksCorrectionRequest.objects.filter(
            ia_test__subject__in=subjects_qs,
            status='PENDING'
        )
        unresolved_corrections_count = corrections_qs.count()

        # Check blocking reasons
        if draft_tests > 0:
            blocking_reasons.append(f"{draft_tests} assessments are still in Draft status.")
        if returned_tests > 0:
            blocking_reasons.append(f"{returned_tests} assessments are Returned for Correction and pending faculty resubmission.")
        if total_missing_marks > 0:
            blocking_reasons.append(f"{total_missing_marks} student mark entries are missing across assessments.")
        if unresolved_corrections_count > 0:
            blocking_reasons.append(f"{unresolved_corrections_count} marks correction requests are pending review.")

        already_locked = (total_tests > 0 and locked_tests == total_tests)
        can_lock = (total_tests > 0 and len(blocking_reasons) == 0 and not already_locked)

        return Response({
            "department": {
                "id": dept.id if dept else None,
                "name": dept.name if dept else "All Departments",
            },
            "semester_id": semester_id,
            "counts": {
                "total_subjects": len(subjects_summary),
                "total_tests": total_tests,
                "verified_tests": verified_tests,
                "submitted_tests": submitted_tests,
                "draft_tests": draft_tests,
                "returned_tests": returned_tests,
                "locked_tests": locked_tests,
                "missing_marks_count": total_missing_marks,
                "unresolved_corrections_count": unresolved_corrections_count,
            },
            "is_locked": already_locked,
            "can_lock": can_lock,
            "blocking_reasons": blocking_reasons,
            "subjects": subjects_summary
        }, status=status.HTTP_200_OK)


# -------------------------------
# 1️⃣1️⃣ HOD Lock Semester IA Action
# -------------------------------
class HODLockSemesterIAView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            return Response({"error": "Only authorized HOD, Principal, or Administrator can lock semester IA."}, status=status.HTTP_403_FORBIDDEN)

        dept_id = request.data.get("department_id")
        semester_id = request.data.get("semester_id")
        lock_reason = request.data.get("lock_reason", "Semester-end IA Locked by HOD")
        allow_exception = bool(request.data.get("allow_exception", False))

        dept = None
        if role == "HOD":
            dept = _resolve_department_for_user(user)
            if dept and dept_id and int(dept_id) != dept.id:
                return Response({"error": "You can only lock IA for your own department."}, status=status.HTTP_403_FORBIDDEN)
        elif dept_id:
            from academics.models import Department
            dept = Department.objects.filter(id=dept_id).first()

        from academics.models import Semester
        sem = Semester.objects.filter(id=semester_id).first() if semester_id else None

        subjects_qs = Subject.objects.all()
        if dept:
            subjects_qs = subjects_qs.filter(Q(department=dept) | Q(subjectassignment__department=dept)).distinct()
        if sem:
            subjects_qs = subjects_qs.filter(semester=sem)

        tests_qs = IATestSetup.objects.filter(subject__in=subjects_qs)
        if not tests_qs.exists():
            return Response({"error": "No IA assessments found to lock for the specified department and semester."}, status=status.HTTP_400_BAD_REQUEST)

        # Pre-lock completion verification
        if not allow_exception:
            draft_count = tests_qs.filter(status="DRAFT").count()
            returned_count = tests_qs.filter(status="RETURNED").count()
            pending_corrections = MarksCorrectionRequest.objects.filter(ia_test__subject__in=subjects_qs, status='PENDING').count()

            blocking_errors = []
            if draft_count > 0:
                blocking_errors.append(f"{draft_count} assessments are still in Draft status.")
            if returned_count > 0:
                blocking_errors.append(f"{returned_count} assessments are Returned for Correction.")
            if pending_corrections > 0:
                blocking_errors.append(f"{pending_corrections} mark correction requests are pending review.")

            if blocking_errors:
                return Response({
                    "error": "Cannot lock semester IA. Required assessment records are incomplete.",
                    "blocking_reasons": blocking_errors
                }, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        with transaction.atomic():
            updated_count = 0
            for t in tests_qs:
                t.is_locked = True
                t.locked_at = now
                t.locked_by = user
                t.lock_reason = lock_reason
                t.status = "LOCKED"
                t.save(update_fields=['is_locked', 'locked_at', 'locked_by', 'lock_reason', 'status', 'updated_at'])
                updated_count += 1

            # Log to immutable audit log
            MarksSecurityAuditLog.objects.create(
                event_type='SEMESTER_FINALIZED',
                actor=user,
                role=role,
                details=f"Semester IA locked by HOD {user.get_full_name() or user.email} for Department: {dept.name if dept else 'All'}, Semester: {sem.sem_number if sem else 'All'}. Total assessments locked: {updated_count}. Reason: {lock_reason}" + (" [Institutional Exception Applied]" if allow_exception else ""),
                reason=lock_reason,
                ip_address=request.META.get('REMOTE_ADDR')
            )

        return Response({
            "message": f"Successfully locked {updated_count} IA assessments for Semester {sem.sem_number if sem else ''}. Marks are now permanently read-only.",
            "locked_count": updated_count,
            "locked_at": now.isoformat(),
            "locked_by": user.get_full_name() or user.email,
        }, status=status.HTTP_200_OK)



