from rest_framework import permissions

class IsRole(permissions.BasePermission):
    """
    Allows access only to users with specific roles.
    Usage: set allowed_roles before checking permission.
    """
    allowed_roles = []

    def has_permission(self, request, view):
        # Make sure user is authenticated
        if not request.user or not request.user.is_authenticated:
            return False
        # Check if user role is in allowed_roles
        return request.user.role in getattr(view, "allowed_roles", self.allowed_roles)


class IsAccounts(IsRole):
    allowed_roles = ["ACCOUNTS"]


class IsPrincipal(IsRole):
    allowed_roles = ["PRINCIPAL"]


class IsAdminOrReadOnly(permissions.BasePermission):
    """
    Allows safe methods to anyone, otherwise admin only.
    """
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return bool(request.user and request.user.is_staff)
