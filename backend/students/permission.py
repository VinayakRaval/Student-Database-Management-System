# students/permissions.py or a shared app
from rest_framework.permissions import BasePermission

class IsHOD(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        role = getattr(request.user, 'role', '') or ''
        if role.upper() in ['HOD', 'HEAD OF DEPARTMENT']:
            return True
        if hasattr(request.user, 'faculty_profile') and getattr(request.user.faculty_profile, 'role', '').upper() in ['HOD', 'HEAD OF DEPARTMENT']:
            return True
        from hod_assignment.models import HODAssignment
        return HODAssignment.objects.filter(faculty__user=request.user, end_date__isnull=True).exists()

