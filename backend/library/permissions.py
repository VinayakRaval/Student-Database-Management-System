from rest_framework import permissions

class IsAuthenticated(permissions.IsAuthenticated):
    pass

class IsLibraryOfficer(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        role = getattr(user, 'role', '') or ''
        return role.upper() == 'LIBRARY' or user.is_staff or user.is_superuser or user.groups.filter(name='LibraryOfficer').exists()


class IsPrincipal(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        role = getattr(user, 'role', '') or ''
        return role.upper() == 'PRINCIPAL' or user.is_staff or user.is_superuser or user.groups.filter(name='Principal').exists()

