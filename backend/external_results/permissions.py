from rest_framework.permissions import BasePermission, SAFE_METHODS

class IsOwnerOrHOD(BasePermission):
    """
    Permissions:
    - Students can CREATE and READ their own results.
    - Students CANNOT update or delete.
    - HOD can READ all results.
    - HOD can UPDATE/DELETE any result.
    """

    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated

    def has_object_permission(self, request, view, obj):
        user = request.user

        # SAFE methods: GET / HEAD / OPTIONS
        # Student can open only own results
        # HOD can open any
        if request.method in SAFE_METHODS:
            return obj.student == user or user.role == "HOD"

        # UNSAFE methods (PATCH / PUT / DELETE)
        # Only HOD can update/delete
        return user.role == "HOD"
