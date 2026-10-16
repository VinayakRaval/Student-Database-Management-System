from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied, ValidationError
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Sum
from django.db import transaction

from .models import IATestSetup, IAMark, IAAggregate
from .serializers import IATestSetupSerializer, IAMarkSerializer, IAAggregateSerializer
from students.models import Student
from subjects.models import Subject, SubjectAssignment
from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user


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

        # Look up existing test setup by (subject, ia_type, ia_name) matching DB uniqueness constraint
        test_obj = IATestSetup.objects.filter(
            subject=subject,
            ia_type=ia_type,
            ia_name=ia_name
        ).first()

        if test_obj:
            if test_obj.max_marks != max_marks:
                test_obj.max_marks = max_marks
            test_obj.faculty = request.user
            test_obj.save(update_fields=['max_marks', 'faculty', 'updated_at'])
            created = False
        else:
            test_obj = IATestSetup.objects.create(
                subject=subject,
                faculty=request.user,
                ia_type=ia_type,
                ia_name=ia_name,
                max_marks=max_marks
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

        students_qs = Student.objects.filter(status__iexact="active")
        if target_dept:
            students_qs = students_qs.filter(department=target_dept)
        if target_sem:
            students_qs = students_qs.filter(semester=target_sem)
        if assignment and assignment.academic_year:
            students_qs = students_qs.filter(academic_year=assignment.academic_year)

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
                        defaults={"obtained_marks": obtained_val}
                    )

                self.update_aggregates(ia_test)

            return Response({"message": "Marks updated successfully"}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": f"Failed to save IA marks: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

    def update_aggregates(self, ia_test):
        try:
            subject = ia_test.subject
            # Compute aggregates dynamically for all students who have any marks recorded for this subject
            student_ids = IAMark.objects.filter(ia_test__subject=subject).values_list("student_id", flat=True).distinct()
            for s_id in student_ids:
                all_marks = IAMark.objects.filter(
                    student_id=s_id,
                    ia_test__subject=subject
                ).aggregate(total=Sum("obtained_marks"), avg=Avg("obtained_marks"))
                if all_marks["total"] is not None:
                    IAAggregate.objects.update_or_create(
                        student_id=s_id,
                        subject=subject,
                        defaults={
                            "total_marks": all_marks["total"] or 0,
                            "average_marks": round(all_marks["avg"] or 0, 2),
                        }
                    )
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
            return IAMark.objects.filter(
                ia_test__subject_id=subject_id
            )

        elif user_role == "HOD":
            dept = _resolve_department_for_user(self.request.user)
            return IAMark.objects.filter(
                ia_test__subject_id=subject_id,
                ia_test__subject__department=dept
            )

        return IAMark.objects.filter(ia_test__subject_id=subject_id)


# -------------------------------
# 5️⃣ Student View Own IA Marks
# -------------------------------
class StudentIAMarkListView(generics.ListAPIView):
    serializer_class = IAMarkSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        student = getattr(self.request.user, "student", None)
        if not student:
            student = get_object_or_404(Student, user=self.request.user)
        return IAMark.objects.filter(student=student)


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

        # 1. Submission Tracker
        submissions = []
        for t in tests_qs:
            submitted_count = IAMark.objects.filter(ia_test=t).count()
            assignment = SubjectAssignment.objects.filter(subject=t.subject).first()
            target_dept = (assignment.department or t.subject.department) if assignment else t.subject.department
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
                "max_marks": t.max_marks,
                "faculty_name": fac_name,
                "submitted_count": submitted_count,
                "eligible_count": eligible_count,
                "status": status_text,
                "status_label": status_label,
                "created_at": t.created_at.strftime("%Y-%m-%d"),
            })

        # 2. Subject-wise Results & Pass Percentages
        subject_results = []
        filtered_subjects = subjects_qs
        if sem_id:
            filtered_subjects = filtered_subjects.filter(semester_id=sem_id)
        if sub_id:
            filtered_subjects = filtered_subjects.filter(id=sub_id)

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
            },
            "students": results
        })

