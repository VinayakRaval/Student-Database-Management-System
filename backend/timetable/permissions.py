from rest_framework import permissions

class IsHOD(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        role = getattr(request.user, "role", "") or ""
        if role.upper() in ["HOD", "HEAD OF DEPARTMENT", "SYSTEM"]:
            return True
        if hasattr(request.user, "faculty_profile") and getattr(request.user.faculty_profile, "role", "").upper() in ["HOD", "HEAD OF DEPARTMENT"]:
            return True
        from hod_assignment.models import HODAssignment
        return HODAssignment.objects.filter(faculty__user=request.user, end_date__isnull=True).exists()

class IsPrincipal(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        role = getattr(request.user, "role", "") or ""
        return role.upper() == "PRINCIPAL" or request.user.is_staff or request.user.is_superuser


class IsPrincipalOrHOD(permissions.BasePermission):
    def has_permission(self, request, view):
        return IsPrincipal().has_permission(request, view) or IsHOD().has_permission(request, view)

