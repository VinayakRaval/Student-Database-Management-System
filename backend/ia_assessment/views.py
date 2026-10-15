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

        test_obj, created = IATestSetup.objects.get_or_create(
            subject=subject,
            faculty=request.user,
            ia_type=ia_type,
            ia_name=ia_name,
            defaults={'max_marks': max_marks}
        )
        if not created and test_obj.max_marks != max_marks:
            test_obj.max_marks = max_marks
            test_obj.save(update_fields=['max_marks', 'updated_at'])

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
        ia_test = get_object_or_404(IATestSetup, id=test_id)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
            # Must either have created the test or be assigned to teach this subject
            if ia_test.faculty != request.user and not SubjectAssignment.objects.filter(subject=ia_test.subject, faculty=fac).exists():
                return Response({"error": "You are not authorized to update marks for this test."}, status=status.HTTP_403_FORBIDDEN)

        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and ia_test.subject.department_id != dept.id:
                return Response({"error": "This subject does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)

        elif user_role not in ["PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
            return Response({"error": "You do not have permission to update IA marks."}, status=status.HTTP_403_FORBIDDEN)

        marks_data = request.data.get("marks", [])
        if not marks_data:
            return Response({"error": "No marks data provided."}, status=status.HTTP_400_BAD_REQUEST)

        target_dept = ia_test.subject.department
        target_sem = ia_test.subject.semester

        with transaction.atomic():
            for entry in marks_data:
                student_id = entry.get("student_id")
                student = Student.objects.filter(id=student_id).first()
                if not student:
                    return Response({"error": f"Student with ID {student_id} not found."}, status=status.HTTP_400_BAD_REQUEST)

                # Validate student eligibility
                if student.department_id != target_dept.id or student.semester_id != target_sem.id:
                    return Response(
                        {"error": f"Student {getattr(student, 'usn', student.id)} is not eligible for this subject's IA assessment."},
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

    def update_aggregates(self, ia_test):
        subject = ia_test.subject
        # Scope aggregates only to eligible students for this subject
        eligible_students = Student.objects.filter(
            department=subject.department,
            semester=subject.semester,
            status__iexact="active"
        )
        for student in eligible_students:
            all_marks = IAMark.objects.filter(
                student=student,
                ia_test__subject=subject
            ).aggregate(total=Sum("obtained_marks"), avg=Avg("obtained_marks"))
            if all_marks["total"] is not None:
                IAAggregate.objects.update_or_create(
                    student=student,
                    subject=subject,
                    defaults={
                        "total_marks": all_marks["total"] or 0,
                        "average_marks": round(all_marks["avg"] or 0, 2),
                    }
                )


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
                ia_test__subject_id=subject_id,
                ia_test__faculty=self.request.user
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
