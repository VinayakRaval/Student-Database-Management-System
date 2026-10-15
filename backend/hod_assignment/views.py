
from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.exceptions import ValidationError

from .models import HODAssignment
from .serializers import HODAssignmentSerializer
from faculty.models import Faculty
from userlogin.models import CustomUser


class CurrentHODView(generics.ListAPIView):
    serializer_class = HODAssignmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            HODAssignment.objects
            .filter(end_date__isnull=True)
            .select_related("faculty", "department")
            .order_by("department__name")
        )


class PreviousHODView(generics.ListAPIView):
    serializer_class = HODAssignmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            HODAssignment.objects
            .filter(end_date__isnull=False)
            .select_related("faculty", "department")
            .order_by("-assigned_date")
        )


class IsPrincipalOrAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        role = getattr(request.user, "role", "") or ""
        return bool(request.user.is_staff or request.user.is_superuser or role.upper() in ["PRINCIPAL", "SYSTEM"])


class AssignHODView(generics.CreateAPIView):
    queryset = HODAssignment.objects.all()
    serializer_class = HODAssignmentSerializer
    permission_classes = [IsPrincipalOrAdmin]

    @transaction.atomic
    def perform_create(self, serializer):
        department = serializer.validated_data["department"]
        faculty = serializer.validated_data["faculty"]

        if HODAssignment.objects.filter(
            faculty=faculty,
            end_date__isnull=True,
        ).exists():
            raise ValidationError({
                "faculty": "This faculty member is already a current HOD."
            })

        # End previous HOD assignments for this department.
        previous_hods = list(
            HODAssignment.objects.filter(
                department=department,
                end_date__isnull=True,
            ).select_related("faculty")
        )

        today = timezone.localdate()

        for previous in previous_hods:
            previous.end_date = today
            previous.save(update_fields=["end_date"])

            previous_faculty = previous.faculty
            previous_faculty.role = "PROFESSOR"
            previous_faculty.save(update_fields=["role"])

            # Sync previous user
            prev_user = previous_faculty.user
            if not prev_user:
                prev_user = CustomUser.objects.filter(user_id=previous_faculty.faculty_id).first()
            if not prev_user:
                for u in CustomUser.objects.all():
                    if u.email and previous_faculty.email and u.email.lower() == previous_faculty.email.lower():
                        prev_user = u
                        break
            if prev_user:
                prev_user.role = "PROFESSOR"
                prev_user.save(update_fields=["role"])
                if previous_faculty.user != prev_user:
                    previous_faculty.user = prev_user
                    previous_faculty.save(update_fields=["user"])

        # Create the new assignment.
        assignment = serializer.save()

        faculty.department = department
        faculty.role = "HOD"
        faculty.save(update_fields=["department", "role"])

        # Find linked user for new HOD
        linked_user = faculty.user
        if not linked_user:
            linked_user = CustomUser.objects.filter(user_id=faculty.faculty_id).first()
        if not linked_user:
            for u in CustomUser.objects.all():
                if u.email and faculty.email and u.email.lower() == faculty.email.lower():
                    linked_user = u
                    break

        if linked_user:
            linked_user.role = "HOD"
            linked_user.department = department
            linked_user.save(update_fields=["role", "department"])
            if faculty.user != linked_user:
                faculty.user = linked_user
                faculty.save(update_fields=["user"])

