from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
# REMOVED: authentication_classes imports to use global settings (JWT)
from django.db.models import Q

from .models import Subject, SubjectAssignment
from .serializers import SubjectSerializer, SubjectAssignmentSerializer
from academics.models import Department, AcademicYear
from faculty.models import Faculty


class AddSubjectView(generics.CreateAPIView):
    # REMOVED: authentication_classes = [...] 
    # Use global settings (JWT) automatically
    permission_classes = [IsAuthenticated]
    serializer_class = SubjectSerializer
    queryset = Subject.objects.all()

    def create(self, request, *args, **kwargs):
        data = request.data
        required = ["schema", "department", "semester", "subject_name", "subject_code"]
        if not all(data.get(k) for k in required):
            return Response({"error": "Missing required fields"}, status=status.HTTP_400_BAD_REQUEST)

        # Duplicate check
        if Subject.objects.filter(
            schema_id=data["schema"],
            department_id=data["department"],
            semester_id=data["semester"],
            subject_code=data["subject_code"]
        ).exists():
            return Response({"error": "Subject already exists"}, status=status.HTTP_400_BAD_REQUEST)

        return super().create(request, *args, **kwargs)


class GetSubjectsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        schema_id = request.query_params.get("schema", None)
        semester = request.query_params.get("semester", None)
        department_id = request.query_params.get("department_id", None)

        subjects = Subject.objects.all()

        if department_id:
            subjects = subjects.filter(department_id=department_id)
        if schema_id:
            subjects = subjects.filter(schema_id=schema_id)
        if semester:
            subjects = subjects.filter(semester_id=semester)

        if not subjects.exists():
            return Response({"message": "No subjects found"}, status=status.HTTP_404_NOT_FOUND)

        result = [{"id": s.id, "code": s.subject_code, "name": s.subject_name} for s in subjects]
        return Response(result, status=status.HTTP_200_OK)


class AssignSubjectsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data
        department_id = data.get('department_id')
        assignments = data.get('assignments')

        if not department_id or not assignments:
            return Response({"error": "Missing required parameters"}, status=status.HTTP_400_BAD_REQUEST)

        for assignment in assignments:
            subject_code = assignment.get('subject_code')
            faculty_id = assignment.get('faculty_id')
            semester_id = assignment.get('semester')
            academic_year_id = assignment.get('academic_year')

            if not all([subject_code, faculty_id, semester_id, academic_year_id]):
                return Response({"error": "Missing required fields in assignment"}, status=status.HTTP_400_BAD_REQUEST)

            try:
                subject = Subject.objects.get(subject_code=subject_code)
                faculty = Faculty.objects.get(id=faculty_id)
            except Subject.DoesNotExist:
                return Response({"error": f"Subject with code {subject_code} not found"}, status=status.HTTP_400_BAD_REQUEST)
            except Faculty.DoesNotExist:
                return Response({"error": f"Faculty with id {faculty_id} not found"}, status=status.HTTP_400_BAD_REQUEST)

            obj, created = SubjectAssignment.objects.update_or_create(
                subject=subject,
                faculty=faculty,
                academic_year_id=academic_year_id,
                department_id=department_id,
                semester_id=semester_id,
                defaults={
                    "subject": subject,
                    "faculty": faculty,
                    "academic_year_id": academic_year_id,
                    "department_id": department_id,
                    "semester_id": semester_id
                }
            )

        return Response({"message": "Subjects assigned successfully!"}, status=status.HTTP_200_OK)


class GetAssignedProfessorsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        semester = request.query_params.get('semester')
        department_id = request.query_params.get('department_id')
        academic_year = request.query_params.get('academic_year')

        assignments = SubjectAssignment.objects.all().select_related('faculty', 'subject')

        if semester:
          assignments = assignments.filter(subject__semester_id=semester)
        if department_id:
          assignments = assignments.filter(department_id=department_id)
        if academic_year:
          assignments = assignments.filter(academic_year=academic_year)
  
        if not assignments.exists():
          return Response({"message": "No assigned professors found."}, status=status.HTTP_404_NOT_FOUND)

        result = []
        for a in assignments:
            result.append({
                "subject_code": a.subject.subject_code,
                "faculty_id": a.faculty.id,
                "professor_name": a.faculty.name
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
                "faculty_id": a.faculty.id,
                "professor_name": a.faculty.name,
                "subject_code": a.subject.subject_code,
                "subject_name": a.subject.subject_name,
                "semester": a.subject.semester_id,
                "academic_year": a.academic_year_id
            })

        return Response(result, status=status.HTTP_200_OK)


class GetAssignedSubjectsForProfessorView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        faculty_id = request.query_params.get('faculty_id')
        if not faculty_id:
            return Response({"error": "Professor is required"}, status=status.HTTP_400_BAD_REQUEST)

        assignments = SubjectAssignment.objects.filter(faculty_id=faculty_id).select_related('subject', 'academic_year')

        if not assignments.exists():
            return Response({"message": "No subjects assigned to this professor."}, status=status.HTTP_404_NOT_FOUND)

        result = []
        for a in assignments:
            result.append({
                "assignment_id": a.id,
                "faculty_id": a.faculty_id,
                "subject_code": a.subject.subject_code,
                "subject_name": a.subject.subject_name,
                "semester": a.subject.semester_id,
                "academic_year": a.academic_year_id
            })

        return Response(result, status=status.HTTP_200_OK)