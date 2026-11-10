from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from .models import Department, Semester, AcademicYear, Schema
from .serializers import (
    DepartmentSerializer, SemesterSerializer,
    AcademicYearSerializer, SchemaSerializer
)
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import generics, permissions


# ---------------- Department ---------------- #

class DepartmentListCreateView(generics.ListCreateAPIView):
    queryset = Department.objects.all().order_by('id')
    serializer_class = DepartmentSerializer
    pagination_class = None

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]

class DepartmentDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Department.objects.all()
    serializer_class = DepartmentSerializer
    permission_classes = [IsAuthenticated]


# ---------------- Semester ---------------- #

class SemesterListCreateView(generics.ListCreateAPIView):
    queryset = Semester.objects.all().order_by('sem_number')
    serializer_class = SemesterSerializer
    pagination_class = None

    def get_permissions(self):
        if self.request.method == "GET":
           return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

class SemesterDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Semester.objects.all()
    serializer_class = SemesterSerializer
    
    def get_permissions(self):
     if self.request.method == "GET":
        return [permissions.AllowAny()]
     return [permissions.IsAdminUser()]


# ---------------- Academic Year ---------------- #

class AcademicYearListCreateView(generics.ListCreateAPIView):
    queryset = AcademicYear.objects.all().order_by('id')
    serializer_class = AcademicYearSerializer
    pagination_class = None

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]

class AcademicYearDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = AcademicYear.objects.all()
    serializer_class = AcademicYearSerializer

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]


# ---------------- Schema ---------------- #

class SchemaListCreateView(generics.ListCreateAPIView):
    queryset = Schema.objects.all().order_by('id')
    serializer_class = SchemaSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ["department"]
    pagination_class = None

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]

class SchemaDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Schema.objects.all()
    serializer_class = SchemaSerializer
    permission_classes = [IsAuthenticated]


# ---------------- Semester Finalization & Marks Lock ---------------- #

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db import transaction
from .models import SemesterFinalization

class SemesterFinalizeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            return Response(
                {"error": "Unauthorized. Only HOD, Principal, or System Administrator can officially finalize a semester and lock marks."},
                status=status.HTTP_403_FORBIDDEN
            )

        dept_id = request.data.get("department_id") or request.data.get("department")
        sem_id = request.data.get("semester_id") or request.data.get("semester")
        ay_id = request.data.get("academic_year_id") or request.data.get("academic_year")
        remarks = request.data.get("remarks", "Semester officially completed and student marks permanently locked.")

        if not (dept_id and sem_id and ay_id):
            return Response({"error": "department_id, semester_id, and academic_year_id are required."},
                            status=status.HTTP_400_BAD_REQUEST)

        dept = get_object_or_404(Department, id=dept_id)
        sem = get_object_or_404(Semester, id=sem_id)
        ay = get_object_or_404(AcademicYear, id=ay_id)

        if role == "HOD":
            from timetable.views import _resolve_department_for_user
            user_dept = _resolve_department_for_user(user)
            if not user_dept or user_dept.id != dept.id:
                return Response({"error": "HOD can only finalize semesters within their own department."},
                                status=status.HTTP_403_FORBIDDEN)

        with transaction.atomic():
            finalization, _ = SemesterFinalization.objects.select_for_update().get_or_create(
                department=dept,
                semester=sem,
                academic_year=ay,
            )
            finalization.is_finalized = True
            finalization.finalized_at = timezone.now()
            finalization.finalized_by = user
            finalization.remarks = remarks
            finalization.save()

            # 1. Lock all IATestSetup for this department and semester
            from subjects.models import Subject
            from ia_assessment.models import IATestSetup, MarksSecurityAuditLog
            dept_subjects = Subject.objects.filter(department=dept, semester=sem)
            locked_tests_count = IATestSetup.objects.filter(subject__in=dept_subjects).update(
                is_locked=True,
                locked_at=timezone.now(),
                locked_by=user,
                lock_reason=f"Semester Completed – Finalized by {user.get_full_name() or user.email}"
            )

            # 2. Lock external exam results
            from external_results.models import ExternalResult
            locked_results_count = ExternalResult.objects.filter(
                student__student__department=dept,
                semester=sem
            ).update(
                is_locked=True,
                locked_at=timezone.now(),
                locked_by=user
            )

            # 3. Snapshot academic history to 'completed'
            from students.models import StudentAcademicHistory
            histories_count = StudentAcademicHistory.objects.filter(
                department=dept,
                semester=sem,
                academic_year=ay
            ).update(status_at_time='completed')

            # 4. Immutable Audit Log
            MarksSecurityAuditLog.objects.create(
                event_type='SEMESTER_FINALIZED',
                actor=user,
                role=role,
                details=f"Semester {sem.sem_number} for {dept.name} ({ay.year_name}) finalized and locked by {user.email}. {locked_tests_count} IA assessment tests and {locked_results_count} exam results permanently locked.",
                reason=remarks,
                ip_address=request.META.get('REMOTE_ADDR')
            )


        return Response({
            "message": f"Semester {sem.sem_number} for {dept.name} ({ay.year_name}) has been officially finalized. All student marks and examination results are permanently locked against modifications.",
            "is_finalized": True,
            "finalized_at": finalization.finalized_at,
            "finalized_by": user.get_full_name() or user.email,
            "locked_ia_tests_count": locked_tests_count,
            "locked_results_count": locked_results_count,
            "updated_histories_count": histories_count
        }, status=status.HTTP_200_OK)


class SemesterFinalizationStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        finalizations = SemesterFinalization.objects.filter(is_finalized=True).select_related(
            'department', 'semester', 'academic_year', 'finalized_by'
        )

        dept_id = request.query_params.get('department_id')
        sem_id = request.query_params.get('semester_id')
        ay_id = request.query_params.get('academic_year_id')

        if dept_id:
            finalizations = finalizations.filter(department_id=dept_id)
        if sem_id:
            finalizations = finalizations.filter(semester_id=sem_id)
        if ay_id:
            finalizations = finalizations.filter(academic_year_id=ay_id)

        data = []
        for f in finalizations:
            data.append({
                "id": f.id,
                "department_id": f.department_id,
                "department_name": f.department.name,
                "semester_id": f.semester_id,
                "semester_number": f.semester.sem_number,
                "academic_year_id": f.academic_year_id,
                "academic_year_name": f.academic_year.year_name,
                "is_finalized": f.is_finalized,
                "finalized_at": f.finalized_at,
                "finalized_by": f.finalized_by.get_full_name() if f.finalized_by else None,
                "remarks": f.remarks
            })
        return Response(data, status=status.HTTP_200_OK)