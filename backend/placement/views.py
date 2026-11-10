import secrets
import string
from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, PermissionDenied

from .models import (
    Company,
    PlacementDrive,
    PlacementRound,
    PlacementApplication,
    PlacementOffer,
    RoundCandidateResult,
    StudentPlacementProfile,
    PlacementOfficerAssignment,
)
from .serializers import (
    PlacementOfficerAssignmentSerializer,
    CompanySerializer,
    PlacementDriveSerializer,
    PlacementApplicationSerializer,
    PlacementOfferSerializer,
    StudentPlacementProfileSerializer,
)
from faculty.models import Faculty
from academics.models import Department
from userlogin.models import CustomUser


def _generate_temporary_password(length=12):
    """Generate a secure, random temporary password containing upper, lower, digits, and special characters."""
    chars = string.ascii_letters + string.digits + "!@#$%^&*"
    # Ensure at least one of each
    pwd = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice("!@#$%^&*"),
    ]
    pwd += [secrets.choice(chars) for _ in range(length - 4)]
    secrets.SystemRandom().shuffle(pwd)
    return "".join(pwd)


class IsPrincipalOrAdmin(permissions.BasePermission):
    """Restrict access strictly to Principal or System Admin."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        role = (getattr(request.user, "role", "") or "").upper()
        return bool(request.user.is_staff or request.user.is_superuser or role in ["PRINCIPAL", "SYSTEM"])


class DepartmentEligibleFacultyView(APIView):
    """Fetch faculty members belonging to a department with their current assignment status."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        dept_id = request.query_params.get("department_id")
        if not dept_id:
            return Response({"error": "department_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        faculty_qs = Faculty.objects.filter(department_id=dept_id).select_related("department", "user")

        active_assignments = {
            a.faculty_id: a.status
            for a in PlacementOfficerAssignment.objects.filter(department_id=dept_id, status__in=["ACTIVE", "INVITATION_PENDING"])
        }

        result = []
        for f in faculty_qs:
            photo_url = None
            if f.photo:
                try:
                    photo_url = f.photo.url
                except Exception:
                    pass

            is_assigned = f.id in active_assignments
            assignment_status = active_assignments.get(f.id, "NOT_ASSIGNED")

            result.append({
                "id": f.id,
                "faculty_id": f.faculty_id,
                "name": f.name,
                "designation": f.designation or "Professor",
                "department_id": f.department_id,
                "department_name": f.department.name if f.department else "",
                "email": f.email or (f.user.email if f.user else ""),
                "phone": f.phone or "",
                "photo_url": photo_url,
                "is_placement_officer": is_assigned,
                "assignment_status": assignment_status,
                "account_status": "Active" if (f.user and f.user.is_active) else "Registered",
            })

        return Response(result, status=status.HTTP_200_OK)


class PlacementOfficerListView(generics.ListAPIView):
    """List all Placement Officer assignments."""
    serializer_class = PlacementOfficerAssignmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = PlacementOfficerAssignment.objects.select_related("faculty", "department", "assigned_by").order_by("-created_at")
        dept_id = self.request.query_params.get("department_id")
        if dept_id:
            qs = qs.filter(department_id=dept_id)
        status_param = self.request.query_params.get("status")
        if status_param:
            qs = qs.filter(status=status_param.upper())
        return qs


class AssignPlacementOfficerView(APIView):
    """
    Principal workflow to assign a Placement Officer.
    Validates department, faculty member, and email.
    Generates a secure temporary password and associates Placement Officer permissions.
    """
    permission_classes = [IsPrincipalOrAdmin]

    @transaction.atomic
    def post(self, request):
        dept_id = request.data.get("department_id")
        faculty_id = request.data.get("faculty_id")
        email = (request.data.get("email") or "").strip().lower()

        if not dept_id:
            return Response({"error": "Please select a department."}, status=status.HTTP_400_BAD_REQUEST)
        if not faculty_id:
            return Response({"error": "Please select a faculty member."}, status=status.HTTP_400_BAD_REQUEST)
        if not email:
            return Response({"error": "Placement Officer official email address is required."}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Validate department
        try:
            department = Department.objects.get(id=dept_id)
        except Department.DoesNotExist:
            return Response({"error": "Selected department does not exist."}, status=status.HTTP_404_NOT_FOUND)

        # 2. Validate faculty member exists and belongs to department
        try:
            faculty = Faculty.objects.select_related("user").get(id=faculty_id)
        except Faculty.DoesNotExist:
            return Response({"error": "Selected faculty member does not exist."}, status=status.HTTP_404_NOT_FOUND)

        if faculty.department_id != department.id:
            return Response(
                {"error": f"Faculty '{faculty.name}' does not belong to {department.name}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 3. Check duplicate active or pending assignment
        if PlacementOfficerAssignment.objects.filter(faculty=faculty, status__in=["ACTIVE", "INVITATION_PENDING"]).exists():
            return Response(
                {"error": f"Faculty '{faculty.name}' already has an active or pending Placement Officer assignment."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 4. Check email conflict with other users
        user_with_email = CustomUser.objects.filter(email__iexact=email).first()
        if user_with_email and faculty.user and user_with_email.id != faculty.user.id:
            return Response(
                {"error": f"Email '{email}' is already associated with another college user account."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 5. Generate secure random temporary password
        temporary_password = _generate_temporary_password(12)

        # 6. Associate Placement Officer account / role
        target_user = faculty.user
        if not target_user and user_with_email:
            target_user = user_with_email
            faculty.user = target_user
            faculty.save(update_fields=["user"])

        if target_user:
            target_user.role = "PLACEMENT_OFFICER"
            target_user.set_password(temporary_password)
            target_user.force_password_change = True
            target_user.save()
        else:
            # Create user account for faculty
            target_user = CustomUser.objects.create_user(
                email=email,
                user_id=faculty.faculty_id,
                password=temporary_password,
                role="PLACEMENT_OFFICER",
                department=department,
            )
            target_user.force_password_change = True
            target_user.save()
            faculty.user = target_user
            faculty.save(update_fields=["user"])

        # 7. Create assignment record
        assignment = PlacementOfficerAssignment.objects.create(
            faculty=faculty,
            department=department,
            assigned_by=request.user,
            official_email=email,
            status="INVITATION_PENDING",
        )

        return Response({
            "message": f"Placement Officer role assigned to {faculty.name} successfully. Secure temporary credentials generated.",
            "assignment": PlacementOfficerAssignmentSerializer(assignment).data,
            "temporary_password": temporary_password,
            "email": email,
            "faculty_id": faculty.faculty_id,
        }, status=status.HTTP_201_CREATED)


class RevokePlacementOfficerView(APIView):
    """Revoke an active Placement Officer assignment."""
    permission_classes = [IsPrincipalOrAdmin]

    @transaction.atomic
    def post(self, request, pk):
        try:
            assignment = PlacementOfficerAssignment.objects.select_related("faculty__user").get(id=pk)
        except PlacementOfficerAssignment.DoesNotExist:
            return Response({"error": "Assignment record not found."}, status=status.HTTP_404_NOT_FOUND)

        assignment.status = "INACTIVE"
        assignment.revoked_date = timezone.localdate()
        assignment.save(update_fields=["status", "revoked_date"])

        # Revert user role back to PROFESSOR if linked
        if assignment.faculty and assignment.faculty.user:
            u = assignment.faculty.user
            if u.role == "PLACEMENT_OFFICER":
                u.role = "PROFESSOR"
                u.save(update_fields=["role"])

        return Response({
            "message": f"Placement Officer assignment for {assignment.faculty.name} has been revoked.",
            "assignment": PlacementOfficerAssignmentSerializer(assignment).data
        }, status=status.HTTP_200_OK)


# --- Companies Views ---
class CompanyListCreateView(generics.ListCreateAPIView):
    queryset = Company.objects.all().order_by("name")
    serializer_class = CompanySerializer
    permission_classes = [permissions.IsAuthenticated]


# --- Drives Views ---
class PlacementDriveListCreateView(generics.ListCreateAPIView):
    serializer_class = PlacementDriveSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = PlacementDrive.objects.select_related("company").prefetch_related("eligible_departments").order_by("-created_at")
        status_param = self.request.query_params.get("status")
        if status_param:
            qs = qs.filter(status=status_param.upper())
        return qs

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


# --- Applications Views ---
class PlacementApplicationListCreateView(generics.ListCreateAPIView):
    serializer_class = PlacementApplicationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = PlacementApplication.objects.select_related("student", "drive__company").order_by("-applied_at")
        drive_id = self.request.query_params.get("drive_id")
        if drive_id:
            qs = qs.filter(drive_id=drive_id)
        return qs

    def perform_create(self, serializer):
        # Associate with logged-in student if student
        user = self.request.user
        student = getattr(user, "student_profile", None)
        if not student and hasattr(user, "student"):
            student = user.student
        if not student:
            from students.models import Student
            student = Student.objects.filter(user=user).first()
        if student:
            serializer.save(student=student)
        else:
            serializer.save()


# --- Offers Views ---
class PlacementOfferListCreateView(generics.ListCreateAPIView):
    queryset = PlacementOffer.objects.select_related("student", "company", "drive").order_by("-offer_date")
    serializer_class = PlacementOfferSerializer
    permission_classes = [permissions.IsAuthenticated]


# --- Student Placement Profile ---
class StudentPlacementProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        from students.models import Student
        student = Student.objects.filter(user=user).first()
        if not student:
            return Response({"error": "Student profile not found."}, status=status.HTTP_404_NOT_FOUND)

        profile, _ = StudentPlacementProfile.objects.get_or_create(student=student)
        return Response(StudentPlacementProfileSerializer(profile).data)


# --- Placement Reports & Stats ---
class PlacementStatsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        companies_count = Company.objects.filter(is_active=True).count()
        drives_count = PlacementDrive.objects.count()
        applications_count = PlacementApplication.objects.count()
        offers_count = PlacementOffer.objects.count()

        from django.db.models import Avg, Max
        agg = PlacementOffer.objects.aggregate(
            avg_pkg=Avg('offered_package_lpa'),
            max_pkg=Max('offered_package_lpa')
        )
        avg_pkg = round(float(agg['avg_pkg']), 1) if agg['avg_pkg'] else 0.0
        max_pkg = round(float(agg['max_pkg']), 1) if agg['max_pkg'] else 0.0

        recent_drives = PlacementDrive.objects.select_related("company").order_by("-created_at")[:5]
        drives_data = []
        for d in recent_drives:
            drives_data.append({
                "id": d.id,
                "job_role": d.job_role,
                "company_name": d.company.name,
                "package_lpa": float(d.package_lpa),
                "status": d.status,
            })

        return Response({
            "companies_count": companies_count,
            "drives_count": drives_count,
            "applications_count": applications_count,
            "offers_count": offers_count,
            "avg_package_lpa": avg_pkg,
            "highest_package_lpa": max_pkg,
            "recent_drives": drives_data,
        })


class PlacementReportsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from django.db.models import Count, Avg, Max
        dept_stats = []
        for dept in Department.objects.all():
            off_cnt = PlacementOffer.objects.filter(student__department=dept).count()
            dept_stats.append({
                "department": dept.name,
                "offers": off_cnt,
            })

        total_offers = PlacementOffer.objects.count()
        placed_students = PlacementOffer.objects.values("student_id").distinct().count()

        return Response({
            "total_offers": total_offers,
            "placed_students": placed_students,
            "department_breakdown": dept_stats,
        })
