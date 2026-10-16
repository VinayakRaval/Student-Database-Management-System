import logging
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied, ValidationError
from django.utils import timezone

from .models import Faculty
from .serializers import FacultySerializer
from userlogin.models import AccountInvitation, CustomUser
from userlogin.email_service import send_password_setup_invitation

logger = logging.getLogger(__name__)


class IsStaffOrHODOrPrincipal(permissions.BasePermission):
    """
    Ensures only authorized personnel (Principal, HOD, Admin, System, Admission) can create, update, or delete faculty.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.method in permissions.SAFE_METHODS:
            return True
        role = (getattr(request.user, "role", "") or "").upper()
        return request.user.is_staff or role in ["PRINCIPAL", "HOD", "SYSTEM", "ADMISSION", "ADMIN"]


class FacultyViewSet(viewsets.ModelViewSet):
    queryset = Faculty.objects.all()
    serializer_class = FacultySerializer
    permission_classes = [permissions.IsAuthenticated, IsStaffOrHODOrPrincipal]

    def get_queryset(self):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        dept_param = self.request.query_params.get("department_id") or self.request.query_params.get("department")
        include_all = (self.request.query_params.get("include_all", "") or self.request.query_params.get("all", "")).lower() in ["true", "1"]

        if dept_param and str(dept_param).lower() != "all":
            return Faculty.objects.filter(department_id=dept_param).select_related("department", "user")

        if user_role == "HOD" and not include_all:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if dept:
                return Faculty.objects.filter(department=dept).select_related("department", "user")

        return Faculty.objects.all().select_related("department", "user")

    @action(detail=False, methods=['get'], url_path='next-id')
    def next_id(self, request):
        """
        Returns the next available unique Registration ID for new faculty.
        """
        import re
        ids = list(Faculty.objects.values_list('faculty_id', flat=True))
        prof_nums = [int(m.group()) for f_id in ids if 'prof' in (f_id or '').lower() for m in re.finditer(r'\d+', f_id)]
        next_num = (max(prof_nums) + 1) if prof_nums else 1
        next_id = f"prof{next_num:03d}"
        while Faculty.objects.filter(faculty_id__iexact=next_id).exists():
            next_num += 1
            next_id = f"prof{next_num:03d}"
        return Response({"next_id": next_id})

    def perform_create(self, serializer):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()

        dept = None
        if user_role == "HOD":
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if not dept:
                dept_id = self.request.data.get("department")
                if dept_id:
                    from academics.models import Department
                    dept = Department.objects.filter(id=dept_id).first()
            if not dept:
                raise ValidationError({"department": "HOD is not assigned to a department."})
        elif not (user.is_staff or user_role in ["PRINCIPAL", "SYSTEM", "ADMISSION", "ADMIN"]):
            raise PermissionDenied("Only Principal, HOD, Admission Officer, or System Administrators can register faculty members.")

        # Save with status="approved" and approved_date so login account is automatically created
        # and password setup invitation is automatically dispatched to the registered email immediately upon submit!
        save_kwargs = {
            "status": "approved",
            "approved_date": timezone.now(),
        }
        if dept:
            save_kwargs["department"] = dept

        serializer.save(**save_kwargs)

    def perform_update(self, serializer):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()

        if user_role == "HOD":
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            instance = serializer.instance
            if not dept or instance.department != dept:
                raise PermissionDenied("HOD can only update faculty in their own department.")

        serializer.save()

    def perform_destroy(self, instance):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if not (user.is_staff or user_role in ["PRINCIPAL", "SYSTEM"]):
            raise PermissionDenied("Only Principal or System Administrators can remove faculty records.")
        instance.delete()

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def approve(self, request, pk=None):
        """
        Approves a faculty member and triggers account invitation dispatch.
        """
        faculty = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()

        is_admin = user.is_staff or user_role in ["PRINCIPAL", "SYSTEM"]
        is_hod = user_role == "HOD"

        if not (is_admin or is_hod):
            return Response({"error": "Unauthorized to approve faculty."}, status=status.HTTP_403_FORBIDDEN)

        if is_hod and not is_admin:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if not dept or faculty.department != dept:
                return Response({"error": "HOD can only approve faculty in their own department."}, status=status.HTTP_403_FORBIDDEN)

        faculty.status = "approved"
        faculty.approved_date = timezone.now()
        faculty.save()  # Triggers post_save signal which creates user and dispatches invitation

        return Response({
            "message": f"Faculty {faculty.name} approved successfully. Password setup invitation dispatched.",
            "status": faculty.status,
            "email": faculty.email
        }, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def resend_invitation(self, request, pk=None):
        """
        Resends password setup invitation email to faculty member.
        """
        faculty = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()

        is_admin = user.is_staff or user_role in ["PRINCIPAL", "SYSTEM"]
        is_hod = user_role == "HOD"

        if not (is_admin or is_hod):
            return Response({"error": "Unauthorized to resend invitations."}, status=status.HTTP_403_FORBIDDEN)

        if is_hod and not is_admin:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if not dept or faculty.department != dept:
                return Response({"error": "HOD can only manage faculty within their department."}, status=status.HTTP_403_FORBIDDEN)

        target_user = faculty.user
        if not target_user:
            return Response({"error": "Faculty has no linked login account. Please approve the record first."}, status=status.HTTP_400_BAD_REQUEST)

        invitation, raw_token = AccountInvitation.create_invitation(
            user=target_user,
            created_by=user,
            invitation_type=AccountInvitation.TYPE_INITIAL_SETUP,
            expiry_hours=24
        )

        send_password_setup_invitation(
            user=target_user,
            raw_token=raw_token,
            recipient_name=faculty.name,
            id_value=faculty.faculty_id,
            role=target_user.role,
            invitation_type=AccountInvitation.TYPE_INITIAL_SETUP,
            expiry_hours=24
        )

        return Response({
            "message": f"Password setup invitation sent successfully to {target_user.email}.",
            "expires_at": invitation.expires_at.isoformat()
        }, status=status.HTTP_200_OK)
