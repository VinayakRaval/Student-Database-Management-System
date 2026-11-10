import os
from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.utils import timezone
from .models import Grievance, GrievanceCategory, GrievanceActivity, GrievanceAttachment
from students.models import Student
from faculty.models import Faculty
from academics.models import Department

User = get_user_model()


def validate_file_attachment(file_obj):
    if not file_obj:
        return
    max_size = 10 * 1024 * 1024  # 10 MB
    if file_obj.size > max_size:
        raise serializers.ValidationError(
            f"File size exceeds the 10MB limit (uploaded: {file_obj.size / (1024*1024):.1f}MB)."
        )
    ext = os.path.splitext(file_obj.name)[1].lower()
    allowed = ['.pdf', '.png', '.jpg', '.jpeg', '.docx', '.doc']
    if ext not in allowed:
        raise serializers.ValidationError(
            f"File format '{ext}' is not supported. Allowed formats: {', '.join(allowed)}."
        )


class GrievanceCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = GrievanceCategory
        fields = [
            "id",
            "code",
            "name",
            "description",
            "default_target_role",
            "sla_days",
            "is_confidential_by_default",
            "is_active",
            "created_at",
            "updated_at",
        ]


class GrievanceAttachmentSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    uploaded_by_name = serializers.SerializerMethodField()

    class Meta:
        model = GrievanceAttachment
        fields = [
            "id",
            "grievance",
            "file",
            "file_url",
            "file_name",
            "file_size",
            "uploaded_by",
            "uploaded_by_name",
            "created_at",
        ]

    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get("request")
            return request.build_absolute_uri(obj.file.url) if request else obj.file.url
        return None

    def get_uploaded_by_name(self, obj):
        if not obj.uploaded_by:
            return "Unknown"
        return getattr(obj.uploaded_by, "name", None) or getattr(obj.uploaded_by, "email", "User")


class GrievanceActivitySerializer(serializers.ModelSerializer):
    actor_name = serializers.SerializerMethodField()
    actor_role = serializers.SerializerMethodField()
    attachment_url = serializers.SerializerMethodField()

    class Meta:
        model = GrievanceActivity
        fields = [
            "id",
            "grievance",
            "actor",
            "actor_name",
            "actor_role",
            "action",
            "from_status",
            "to_status",
            "notes",
            "attachment",
            "attachment_url",
            "created_at",
        ]

    def get_actor_name(self, obj):
        if not obj.actor:
            return "System"
        return (
            getattr(obj.actor, "name", None)
            or getattr(obj.actor, "email", None)
            or str(obj.actor)
        )

    def get_actor_role(self, obj):
        return getattr(obj.actor, "role", "") if obj.actor else ""

    def get_attachment_url(self, obj):
        if obj.attachment:
            request = self.context.get("request")
            return request.build_absolute_uri(obj.attachment.url) if request else obj.attachment.url
        return None


class GrievanceSerializer(serializers.ModelSerializer):
    complainant_name = serializers.SerializerMethodField()
    complainant_role = serializers.SerializerMethodField()
    complainant_email = serializers.SerializerMethodField()
    student_usn = serializers.CharField(source="student.usn", read_only=True, default=None)
    department_name = serializers.CharField(source="department.name", read_only=True, default=None)
    category_title = serializers.CharField(source="category.name", read_only=True, default=None)
    assigned_officer_name = serializers.SerializerMethodField()
    escalated_to_name = serializers.SerializerMethodField()
    resolved_by_name = serializers.SerializerMethodField()
    reopened_by_name = serializers.SerializerMethodField()
    attachment_url = serializers.SerializerMethodField()
    is_overdue = serializers.SerializerMethodField()
    days_open = serializers.SerializerMethodField()
    activities = GrievanceActivitySerializer(many=True, read_only=True)
    user_permissions = serializers.SerializerMethodField()

    class Meta:
        model = Grievance
        fields = [
            "id",
            "topic",
            "description",
            "category",
            "category_name",
            "category_title",
            "priority",
            "status",
            "department",
            "department_name",
            "submitted_by",
            "complainant_name",
            "complainant_role",
            "complainant_email",
            "student",
            "student_usn",
            "target_role",
            "target_user",
            "assigned_officer_name",
            "attachment",
            "attachment_url",
            "is_confidential",
            # Workflow timestamps & fields
            "response",
            "resolution_remarks",
            "rejection_reason",
            "resolved_at",
            "resolved_by",
            "resolved_by_name",
            "closed_at",
            "info_requested_notes",
            "info_provided_notes",
            # Escalation
            "is_escalated",
            "escalated_to",
            "escalated_to_name",
            "escalated_at",
            "escalation_reason",
            # Reopening
            "reopen_requested",
            "reopen_request_reason",
            "reopen_requested_at",
            "is_reopened",
            "reopened_at",
            "reopened_by",
            "reopened_by_name",
            # Metrics
            "is_overdue",
            "days_open",
            "created_at",
            "updated_at",
            "activities",
            "user_permissions",
        ]
        read_only_fields = [
            "id",
            "submitted_by",
            "student",
            "department",
            "status",
            "response",
            "resolution_remarks",
            "rejection_reason",
            "resolved_at",
            "resolved_by",
            "closed_at",
            "info_requested_notes",
            "info_provided_notes",
            "is_escalated",
            "escalated_to",
            "escalated_at",
            "escalation_reason",
            "reopen_requested",
            "reopen_request_reason",
            "reopen_requested_at",
            "is_reopened",
            "reopened_at",
            "reopened_by",
            "created_at",
            "updated_at",
        ]

    def get_complainant_name(self, obj):
        if obj.student:
            return obj.student.name or getattr(obj.student.user, "email", "Student")
        if obj.submitted_by:
            # Check if faculty
            faculty = Faculty.objects.filter(user=obj.submitted_by).first()
            if faculty:
                return faculty.name
            return getattr(obj.submitted_by, "name", None) or obj.submitted_by.email or "Complainant"
        return "Anonymous"

    def get_complainant_role(self, obj):
        if obj.student:
            return "STUDENT"
        return getattr(obj.submitted_by, "role", "STUDENT") if obj.submitted_by else ""

    def get_complainant_email(self, obj):
        if obj.submitted_by:
            return obj.submitted_by.email
        if obj.student and obj.student.user:
            return obj.student.user.email
        return None

    def get_assigned_officer_name(self, obj):
        if not obj.target_user:
            return obj.target_role or "Unassigned"
        faculty = Faculty.objects.filter(user=obj.target_user).first()
        if faculty:
            return f"{faculty.name} ({obj.target_user.role})"
        return f"{getattr(obj.target_user, 'email', 'Officer')} ({obj.target_user.role})"

    def get_escalated_to_name(self, obj):
        if not obj.escalated_to:
            return None
        return getattr(obj.escalated_to, "name", None) or getattr(obj.escalated_to, "email", "Authority")

    def get_resolved_by_name(self, obj):
        if not obj.resolved_by:
            return None
        return getattr(obj.resolved_by, "name", None) or getattr(obj.resolved_by, "email", "Officer")

    def get_reopened_by_name(self, obj):
        if not obj.reopened_by:
            return None
        return getattr(obj.reopened_by, "name", None) or getattr(obj.reopened_by, "email", "Officer")

    def get_attachment_url(self, obj):
        if obj.attachment:
            request = self.context.get("request")
            return request.build_absolute_uri(obj.attachment.url) if request else obj.attachment.url
        return None

    def get_days_open(self, obj):
        end = obj.resolved_at or obj.closed_at or timezone.now()
        delta = end - obj.created_at
        return max(0, delta.days)

    def get_is_overdue(self, obj):
        if obj.status in ["RESOLVED", "CLOSED", "REJECTED"]:
            return False
        sla_days = getattr(obj.category, "sla_days", 7) if obj.category else 7
        if obj.priority == "URGENT":
            sla_days = 1
        elif obj.priority == "HIGH":
            sla_days = 3
        elif obj.priority == "LOW":
            sla_days = 10
        delta = timezone.now() - obj.created_at
        return delta.days > sla_days

    def get_user_permissions(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return {}

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        is_complainant = (obj.submitted_by_id == user.id) or (
            obj.student and obj.student.user_id == user.id
        )
        is_assigned = obj.target_user_id == user.id
        is_principal = role == "PRINCIPAL" or user.is_superuser
        is_hod = role == "HOD" and (
            (obj.department_id and user.department_id == obj.department_id) or is_assigned
        )
        is_officer = role in ["ADMISSION", "ACCOUNTS", "LIBRARY", "PROFESSOR"] and is_assigned

        # Status states
        is_open = obj.status in ["SUBMITTED", "UNDER_REVIEW", "IN_PROGRESS", "AWAITING_INFO", "ESCALATED", "REOPENED", "Pending"]
        is_resolved_or_closed = obj.status in ["RESOLVED", "CLOSED"]

        can_respond = is_open and (is_assigned or is_hod or is_principal)
        can_assign = is_open and (is_hod or is_principal)
        can_escalate = is_open and (is_assigned or is_hod or role in ["ADMISSION", "ACCOUNTS", "LIBRARY"])
        can_resolve = is_open and (is_assigned or is_hod or is_principal)
        can_reject = is_open and (is_assigned or is_hod or is_principal)
        can_close = obj.status == "RESOLVED" and (is_complainant or is_principal or is_assigned)
        can_request_info = is_open and obj.status != "AWAITING_INFO" and (is_assigned or is_hod or is_principal)
        can_provide_info = obj.status == "AWAITING_INFO" and is_complainant
        can_request_reopen = is_resolved_or_closed and is_complainant and not obj.reopen_requested
        can_reopen = (obj.reopen_requested or is_resolved_or_closed) and (is_principal or is_hod or is_assigned)

        return {
            "can_respond": can_respond,
            "can_assign": can_assign,
            "can_escalate": can_escalate,
            "can_resolve": can_resolve,
            "can_reject": can_reject,
            "can_close": can_close,
            "can_request_info": can_request_info,
            "can_provide_info": can_provide_info,
            "can_request_reopen": can_request_reopen,
            "can_reopen": can_reopen,
        }


class GrievanceCreateSerializer(serializers.ModelSerializer):
    category_id = serializers.IntegerField(required=False, write_only=True)

    class Meta:
        model = Grievance
        fields = [
            "id",
            "topic",
            "description",
            "category_id",
            "category_name",
            "priority",
            "target_role",
            "target_user",
            "attachment",
            "is_confidential",
        ]

    def validate_attachment(self, value):
        if value:
            validate_file_attachment(value)
        return value

    def validate(self, attrs):
        topic = attrs.get("topic", "").strip()
        description = attrs.get("description", "").strip()
        if not topic:
            raise serializers.ValidationError({"topic": "Title/Topic is required."})
        if not description:
            raise serializers.ValidationError({"description": "Description is required."})
        return attrs


class StatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=[
        "UNDER_REVIEW", "IN_PROGRESS", "AWAITING_INFO", "RESOLVED", "CLOSED", "REJECTED", "ESCALATED", "REOPENED"
    ])
    notes = serializers.CharField(required=False, allow_blank=True, default="")
    attachment = serializers.FileField(required=False, allow_null=True)

    def validate_attachment(self, value):
        if value:
            validate_file_attachment(value)
        return value


class AssignOfficerSerializer(serializers.Serializer):
    target_user_id = serializers.IntegerField(required=True)
    target_role = serializers.CharField(required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True, default="")


class RequestInfoSerializer(serializers.Serializer):
    notes = serializers.CharField(required=True)


class ProvideInfoSerializer(serializers.Serializer):
    notes = serializers.CharField(required=True)
    attachment = serializers.FileField(required=False, allow_null=True)

    def validate_attachment(self, value):
        if value:
            validate_file_attachment(value)
        return value


class EscalateSerializer(serializers.Serializer):
    escalated_to_id = serializers.IntegerField(required=False, allow_null=True)
    destination_role = serializers.CharField(required=False, default="PRINCIPAL")
    reason = serializers.CharField(required=True)


class ResolveSerializer(serializers.Serializer):
    resolution_remarks = serializers.CharField(required=True)
    attachment = serializers.FileField(required=False, allow_null=True)

    def validate_attachment(self, value):
        if value:
            validate_file_attachment(value)
        return value


class RejectSerializer(serializers.Serializer):
    rejection_reason = serializers.CharField(required=True)


class ReopenRequestSerializer(serializers.Serializer):
    reason = serializers.CharField(required=True)


class ReopenReviewSerializer(serializers.Serializer):
    decision = serializers.ChoiceField(choices=["APPROVE", "REJECT"])
    notes = serializers.CharField(required=False, allow_blank=True, default="")
