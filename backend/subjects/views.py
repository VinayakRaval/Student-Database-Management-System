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
    permission_classes = [IsAuthenticated]
    serializer_class = SubjectSerializer
    queryset = Subject.objects.all()

    def create(self, request, *args, **kwargs):
        from timetable.views import _resolve_department_for_user
        data = request.data
        required = ["schema", "department", "semester", "subject_name", "subject_code"]
        if not all(data.get(k) for k in required):
            return Response({"error": "Missing required fields"}, status=status.HTTP_400_BAD_REQUEST)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and str(data["department"]) != str(dept.id):
                return Response(
                    {"error": f"You are the HOD of {dept.name}. You cannot create subjects for another department."},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Duplicate check
        if Subject.objects.filter(
            schema_id=data["schema"],
            department_id=data["department"],
            semester_id=data["semester"],
            subject_code=data["subject_code"]
        ).exists():
            return Response(
                {"error": f"Subject with code '{data['subject_code']}' already exists in this department and semester."},
                status=status.HTTP_400_BAD_REQUEST
            )

        return super().create(request, *args, **kwargs)


class GetSubjectsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from timetable.views import _resolve_department_for_user
        schema_id = request.query_params.get("schema", None)
        semester = request.query_params.get("semester", None)
        department_id = request.query_params.get("department_id", None)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD" and not department_id:
            dept = _resolve_department_for_user(request.user)
            if dept:
                department_id = dept.id

        subjects = Subject.objects.all().select_related('department')

        if department_id:
            subjects = subjects.filter(department_id=department_id)
        if schema_id:
            subjects = subjects.filter(schema_id=schema_id)
        if semester:
            subjects = subjects.filter(semester_id=semester)

        result = [{
            "id": s.id,
            "code": s.subject_code,
            "name": s.subject_name,
            "semester": s.semester_id,
            "department_id": s.department_id,
            "department_name": getattr(s.department, "name", "")
        } for s in subjects]
        return Response(result, status=status.HTTP_200_OK)


class AssignSubjectsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from timetable.views import _resolve_department_for_user
        data = request.data
        department_id = data.get('department_id')
        assignments = data.get('assignments')

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

        assignments = SubjectAssignment.objects.all().select_related('faculty', 'subject', 'subject__department', 'subject__semester')

        if subject_id:
            assignments = assignments.filter(subject_id=subject_id)
        if subject_code:
            assignments = assignments.filter(subject__subject_code=subject_code)
        if semester:
            assignments = assignments.filter(subject__semester_id=semester)
        if department_id:
            assignments = assignments.filter(department_id=department_id)
        if academic_year:
            assignments = assignments.filter(academic_year=academic_year)
  
        if not assignments.exists():
            return Response([], status=status.HTTP_200_OK)

        result = []
        for a in assignments:
            result.append({
                "subject_id": a.subject.id,
                "subject_name": a.subject.subject_name,
                "subject_code": a.subject.subject_code,
                "faculty_id": a.faculty.id,
                "professor_name": a.faculty.name,
                "department": getattr(a.department or a.subject.department, "name", ""),
                "semester": getattr(a.semester or a.subject.semester, "sem_number", ""),
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
                fac = _resolve_faculty_for_user(request.user)
                if fac:
                    target_faculty_id = fac.id
                elif dept:
                    # Return all assignments in HOD's department
                    assignments = SubjectAssignment.objects.filter(department=dept).select_related('subject', 'faculty', 'academic_year', 'semester')
                    result = [{
                        "id": a.subject.id,
                        "subject_id": a.subject.id,
                        "assignment_id": a.id,
                        "faculty_id": a.faculty_id,
                        "faculty_name": getattr(a.faculty, "name", ""),
                        "subject_code": a.subject.subject_code,
                        "subject_name": a.subject.subject_name,
                        "semester": getattr(a.semester, "sem_number", None) or getattr(getattr(a.subject, "semester", None), "sem_number", None),
                        "academic_year": getattr(a.academic_year, "year_name", None),
                        "department_name": getattr(getattr(a.subject, "department", None), "name", "")
                    } for a in assignments]
                    return Response(result, status=status.HTTP_200_OK)

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
                "semester": getattr(a.semester, "sem_number", None) or getattr(getattr(a.subject, "semester", None), "sem_number", None),
                "academic_year": getattr(a.academic_year, "year_name", None),
                "department_name": getattr(getattr(a.subject, "department", None), "name", "")
            })

        return Response(result, status=status.HTTP_200_OK)