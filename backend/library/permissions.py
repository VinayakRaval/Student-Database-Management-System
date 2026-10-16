from rest_framework import permissions

class IsAuthenticated(permissions.IsAuthenticated):
    pass

class IsLibraryOfficer(permissions.BasePermission):
    """
    Grants access only to users with role 'LIBRARY', staff members, or superusers.
    """
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        role = getattr(user, 'role', '') or ''
        return (
            role.upper() == 'LIBRARY' or
            user.is_staff or
            user.is_superuser or
            user.groups.filter(name='LibraryOfficer').exists()
        )


class IsLibraryOfficerOrReadOnly(permissions.BasePermission):
    """
    Allows all authenticated users to read (GET/HEAD/OPTIONS),
    but restricts create/update/delete to Library Officers and Staff.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.method in permissions.SAFE_METHODS:
            return True
        role = getattr(request.user, 'role', '') or ''
        return (
            role.upper() == 'LIBRARY' or
            request.user.is_staff or
            request.user.is_superuser or
            request.user.groups.filter(name='LibraryOfficer').exists()
        )


class IsPrincipal(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        role = getattr(user, 'role', '') or ''
        return (
            role.upper() == 'PRINCIPAL' or
            user.is_staff or
            user.is_superuser or
            user.groups.filter(name='Principal').exists()
        )


class IsBorrowerOrLibraryOfficer(permissions.BasePermission):
    """
    Borrowers can view their own records; Library Officers can view and manage all.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        role = getattr(user, 'role', '') or ''
        if role.upper() == 'LIBRARY' or user.is_staff or user.is_superuser:
            return True
        # Check borrower on issue or fine
        borrower = getattr(obj, 'borrower', None)
        if borrower is None and hasattr(obj, 'issue'):
            borrower = getattr(obj.issue, 'borrower', None)
        return borrower == user


class IsRequesterOrLibraryOfficer(permissions.BasePermission):
    """
    Requesters can view and cancel their own pending requests.
    Library Officers can view and manage all requests.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        role = getattr(user, 'role', '') or ''
        if role.upper() in ['LIBRARY', 'PRINCIPAL', 'SYSTEM'] or user.is_staff or user.is_superuser:
            return True
        return obj.requester == user


class IsHOD(permissions.BasePermission):
    """
    Grants access to HODs, staff, and superusers.
    """
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        role = getattr(user, 'role', '') or ''
        return (
            role.upper() == 'HOD' or
            user.is_staff or
            user.is_superuser or
            user.groups.filter(name='HOD').exists()
        )



