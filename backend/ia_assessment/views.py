from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Sum

from .models import IATestSetup, IAMark, IAAggregate
from .serializers import IATestSetupSerializer, IAMarkSerializer, IAAggregateSerializer
from students.models import Student
from subjects.models import Subject
from subjects.models import SubjectAssignment


# -------------------------------
# 1️⃣ Create IA Test Setup
# -------------------------------
class IATestSetupCreateView(generics.CreateAPIView):
    serializer_class = IATestSetupSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(faculty=self.request.user)


# -------------------------------
# 2️⃣ Fetch Active Students for IA Entry
# -------------------------------
class FacultyActiveStudentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Require subject_id query param
        subject_id = request.query_params.get("subject_id", "").strip().replace("/", "")
        if not subject_id.isdigit():
            return Response({"error": "Invalid subject_id"}, status=400)

        subject = get_object_or_404(Subject, id=int(subject_id))

        # Optional: filter by faculty if you want
        assignments = SubjectAssignment.objects.filter(subject=subject)
        if not assignments.exists():
            return Response({"error": "No assignments for this subject"}, status=404)
        assignment = assignments.first()

        # Only select minimal fields for IA entry
        students = Student.objects.filter(
            department=assignment.department,
            semester=assignment.semester,
            academic_year=assignment.academic_year,
            status__iexact="active"
        ).values("id", "name", "usn")

        return Response(students)


# -------------------------------
# 3️⃣ Bulk Mark Entry / Update
# -------------------------------
class BulkIAMarkUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, test_id):
        ia_test = get_object_or_404(IATestSetup, id=test_id, faculty=request.user)
        marks_data = request.data.get("marks", [])

        for entry in marks_data:
            student_id = entry.get("student_id")
            obtained = entry.get("obtained_marks", 0)
            IAMark.objects.update_or_create(
                ia_test=ia_test,
                student_id=student_id,
                defaults={"obtained_marks": obtained}
            )

        self.update_aggregates(ia_test)
        return Response({"message": "Marks updated successfully"}, status=200)

    def update_aggregates(self, ia_test):
        subject = ia_test.subject
        students = Student.objects.filter(
            status__iexact="Active"
        )
        for student in students:
            all_marks = IAMark.objects.filter(
                student=student,
                ia_test__subject=subject
            ).aggregate(total=Sum("obtained_marks"), avg=Avg("obtained_marks"))
            IAAggregate.objects.update_or_create(
                student=student,
                subject=subject,
                defaults={
                    "total_marks": all_marks["total"] or 0,
                    "average_marks": all_marks["avg"] or 0,
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
        return IAMark.objects.filter(
            ia_test__faculty=self.request.user,
            ia_test__subject_id=subject_id
        )


# -------------------------------
# 5️⃣ Student View Own IA Marks
# -------------------------------
class StudentIAMarkListView(generics.ListAPIView):
    serializer_class = IAMarkSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        from students.models import Student
        student = get_object_or_404(Student, user=self.request.user)
        return IAMark.objects.filter(student=student)
