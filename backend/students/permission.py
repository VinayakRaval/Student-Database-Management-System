# students/permissions.py or a shared app
from rest_framework.permissions import BasePermission

class IsHOD(BasePermission):
    def has_permission(self, request, view):
        return (
            hasattr(request.user, 'faculty_profile') and
            request.user.faculty_profile.role == 'HOD'
        )
