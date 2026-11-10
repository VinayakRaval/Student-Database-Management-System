from django.contrib import admin
from .models import Grievance, GrievanceCategory, GrievanceActivity, GrievanceAttachment


@admin.register(GrievanceCategory)
class GrievanceCategoryAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "default_target_role", "sla_days", "is_confidential_by_default", "is_active")
    list_filter = ("default_target_role", "is_active", "is_confidential_by_default")
    search_fields = ("code", "name", "description")


class GrievanceActivityInline(admin.TabularInline):
    model = GrievanceActivity
    extra = 0
    readonly_fields = ("actor", "action", "from_status", "to_status", "notes", "attachment", "created_at")
    can_delete = False


class GrievanceAttachmentInline(admin.TabularInline):
    model = GrievanceAttachment
    extra = 0
    readonly_fields = ("file_name", "file_size", "uploaded_by", "created_at")


@admin.register(Grievance)
class GrievanceAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "topic",
        "category_name",
        "priority",
        "status",
        "complainant_display",
        "department",
        "assigned_user",
        "is_confidential",
        "created_at",
    )

    list_filter = ("status", "priority", "category_name", "target_role", "is_confidential", "created_at")

    search_fields = (
        "topic",
        "description",
        "student__user__email",
        "submitted_by__email",
        "target_user__email",
    )

    readonly_fields = (
        "created_at",
        "updated_at",
        "resolved_at",
        "closed_at",
        "escalated_at",
        "reopened_at",
        "reopen_requested_at",
    )

    inlines = [GrievanceActivityInline, GrievanceAttachmentInline]

    def complainant_display(self, obj):
        if obj.student:
            return f"Student: {obj.student.name} ({obj.student.usn})"
        if obj.submitted_by:
            return f"{obj.submitted_by.role}: {obj.submitted_by.email}"
        return "Unknown"
    complainant_display.short_description = "Complainant"

    def assigned_user(self, obj):
        return obj.target_user.email if obj.target_user else obj.target_role
    assigned_user.short_description = "Assigned To"


@admin.register(GrievanceActivity)
class GrievanceActivityAdmin(admin.ModelAdmin):
    list_display = ("grievance", "actor", "action", "from_status", "to_status", "created_at")
    list_filter = ("action", "created_at")
    search_fields = ("grievance__topic", "actor__email", "notes")
