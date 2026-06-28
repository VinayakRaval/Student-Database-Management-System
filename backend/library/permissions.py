from rest_framework import permissions

class IsAuthenticated(permissions.IsAuthenticated):
    pass

class IsLibraryOfficer(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        return getattr(user, 'is_library_officer', False) or user.groups.filter(name='LibraryOfficer').exists()


class IsPrincipal(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return getattr(user, 'is_principal', False) or user.groups.filter(name='Principal').exists()
