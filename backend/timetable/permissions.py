from rest_framework import permissions

class IsHOD(permissions.BasePermission):
    def has_permission(self, request, view):
        return getattr(request.user, "role", "").upper() in ["HOD", "HEAD OF DEPARTMENT"]

class IsPrincipal(permissions.BasePermission):
    def has_permission(self, request, view):
        return getattr(request.user, "role", "").upper() == "PRINCIPAL"
