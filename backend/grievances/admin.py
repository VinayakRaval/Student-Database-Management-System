from django.contrib import admin
from .models import Grievance


@admin.register(Grievance)
class GrievanceAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "topic",
        "student_name",
        "target_role",
        "assigned_user",
        "status",
        "created_at",
    )

    list_filter = ("target_role", "status", "created_at")

    search_fields = (
        "topic",
        "student__user__email",
        "student__user__phone",
        "student__user__user_id",
        "target_user__email",
        "target_user__phone",
    )

    readonly_fields = ("created_at", "updated_at")

    # -------------------------------
    # Custom display helpers
    # -------------------------------

    def student_name(self, obj):
        """Display student's email or fallback value"""
        return getattr(obj.student.user, "email", "Unknown")
    student_name.short_description = "Student"

    def assigned_user(self, obj):
        """Show assigned user or role"""
        return obj.target_user.email if obj.target_user else f"Role: {obj.target_role}"
    assigned_user.short_description = "Assigned To"
