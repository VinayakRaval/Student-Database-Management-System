from rest_framework import serializers
from .models import Announcement, Notification
from academics.models import Department, Semester


class AnnouncementSerializer(serializers.ModelSerializer):
    category = serializers.CharField(max_length=100, required=False, default="GENERAL")
    target_audience = serializers.CharField(required=False, default="BOTH")
    author_name = serializers.SerializerMethodField()
    author_role = serializers.SerializerMethodField()
    sender_label = serializers.SerializerMethodField()
    department_name = serializers.CharField(source="department.name", read_only=True)
    semester_name = serializers.CharField(source="target_semester.sem_number", read_only=True)
    academic_year_name = serializers.CharField(source="academic_year.year_name", read_only=True)
    image_url = serializers.SerializerMethodField()
    attachment_url = serializers.SerializerMethodField()
    status_label = serializers.SerializerMethodField()

    class Meta:
        model = Announcement
        fields = [
            "id",
            "title",
            "content",
            "category",
            "priority",
            "image",
            "attachment",
            "image_url",
            "attachment_url",
            "created_by",
            "author_name",
            "author_role",
            "sender_label",
            "department",
            "department_name",
            "target_roles",
            "target_audience",
            "target_semester",
            "semester_name",
            "academic_year",
            "academic_year_name",
            "publish_date",
            "expiry_date",
            "is_published",
            "is_archived",
            "notify_users",
            "status_label",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["created_by", "created_at", "updated_at"]

    def validate_target_audience(self, value):
        val = (value or "").strip().upper()
        if val in ("ALL", "BOTH"):
            return "BOTH"
        if val in ("STUDENTS", "FACULTY"):
            return val
        return "BOTH"

    def get_status_label(self, obj):
        from django.utils import timezone
        now = timezone.now()
        if not obj.is_published:
            return "DRAFT"
        if obj.expiry_date and obj.expiry_date < now:
            return "EXPIRED"
        if obj.publish_date and obj.publish_date > now:
            return "SCHEDULED"
        return "PUBLISHED"

    def get_author_name(self, obj):
        user = obj.created_by
        if not user:
            return "Administration"
        # Try finding linked faculty, student, or email
        fac = getattr(user, "faculty_profile", None)
        if fac and getattr(fac, "name", None):
            return fac.name
        stu = getattr(user, "student", None)
        if stu and getattr(stu, "name", None):
            return stu.name
        return getattr(user, "email", "Admin")

    def get_author_role(self, obj):
        user = obj.created_by
        if not user:
            return "Administration"
        role = (getattr(user, "role", "") or "").upper()
        if role in ["PRINCIPAL", "SYSTEM"]:
            return "Principal"
        elif role == "HOD":
            return "HOD"
        elif role in ["PROFESSOR", "FACULTY"]:
            return "Faculty"
        return role.title() if role else "Administration"

    def get_sender_label(self, obj):
        role_label = self.get_author_role(obj)
        dept = obj.department
        if not dept and role_label == "HOD" and obj.created_by:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(obj.created_by)
        if dept and getattr(dept, "name", None):
            return f"From: {role_label} – {dept.name}"
        return f"From: {role_label}"

    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None

    def get_attachment_url(self, obj):
        if obj.attachment:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.attachment.url)
            return obj.attachment.url
        return None


class NotificationSerializer(serializers.ModelSerializer):
    announcement_title = serializers.CharField(source="announcement.title", read_only=True)
    announcement_category = serializers.CharField(source="announcement.category", read_only=True)
    announcement_priority = serializers.CharField(source="announcement.priority", read_only=True)
    sender_label = serializers.SerializerMethodField()
    author_role = serializers.SerializerMethodField()
    department_name = serializers.CharField(source="announcement.department.name", read_only=True)

    class Meta:
        model = Notification
        fields = [
            "id",
            "recipient",
            "announcement",
            "announcement_title",
            "announcement_category",
            "announcement_priority",
            "sender_label",
            "author_role",
            "department_name",
            "title",
            "message",
            "notification_type",
            "is_read",
            "read_at",
            "created_at",
        ]
        read_only_fields = ["recipient", "created_at"]

    def get_author_role(self, obj):
        if obj.announcement and obj.announcement.created_by:
            role = (getattr(obj.announcement.created_by, "role", "") or "").upper()
            if role in ["PRINCIPAL", "SYSTEM"]:
                return "Principal"
            elif role == "HOD":
                return "HOD"
            elif role in ["PROFESSOR", "FACULTY"]:
                return "Faculty"
            return role.title()
        return "System"

    def get_sender_label(self, obj):
        if obj.announcement:
            role = self.get_author_role(obj)
            dept = obj.announcement.department
            if not dept and role == "HOD" and obj.announcement.created_by:
                from timetable.views import _resolve_department_for_user
                dept = _resolve_department_for_user(obj.announcement.created_by)
            if dept and getattr(dept, "name", None):
                return f"From: {role} – {dept.name}"
            return f"From: {role}"
        return "From: College Administration"
