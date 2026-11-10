from rest_framework import serializers
from .models import CorrectionRequest, CorrectionRequestHistory, CATEGORY_CHOICES, STATUS_CHOICES
from students.serializers import StudentSerializer

class CorrectionRequestHistorySerializer(serializers.ModelSerializer):
    actor_name = serializers.SerializerMethodField()
    actor_email = serializers.SerializerMethodField()

    class Meta:
        model = CorrectionRequestHistory
        fields = ['id', 'action', 'from_status', 'to_status', 'comments', 'timestamp', 'actor_name', 'actor_email']

    def get_actor_name(self, obj):
        if obj.actor:
            return getattr(obj.actor, 'name', None) or obj.actor.user_id or obj.actor.email
        return "System"

    def get_actor_email(self, obj):
        return obj.actor.email if obj.actor else ""


class CorrectionRequestListSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_usn = serializers.CharField(source='student.usn', read_only=True)
    student_department_name = serializers.CharField(source='student.department.name', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = CorrectionRequest
        fields = [
            'id',
            'request_id',
            'student',
            'student_name',
            'student_usn',
            'student_department_name',
            'category',
            'category_display',
            'target_record_ref',
            'current_value',
            'requested_value',
            'description',
            'reason',
            'status',
            'status_display',
            'assigned_role',
            'created_at',
            'updated_at',
            'resolved_at',
        ]


class CorrectionRequestDetailSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_usn = serializers.CharField(source='student.usn', read_only=True)
    student_department_name = serializers.CharField(source='student.department.name', read_only=True)
    student_semester = serializers.CharField(source='student.semester.sem_number', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    assigned_department_name = serializers.CharField(source='assigned_department.name', read_only=True)
    history = CorrectionRequestHistorySerializer(many=True, read_only=True)

    class Meta:
        model = CorrectionRequest
        fields = [
            'id',
            'request_id',
            'student',
            'student_name',
            'student_usn',
            'student_department_name',
            'student_semester',
            'category',
            'category_display',
            'target_record_ref',
            'current_value',
            'requested_value',
            'description',
            'reason',
            'evidence_file',
            'status',
            'status_display',
            'assigned_department',
            'assigned_department_name',
            'assigned_role',
            'reviewer_comments',
            'rejection_reason',
            'resolution_notes',
            'created_at',
            'updated_at',
            'resolved_at',
            'history',
        ]


class CorrectionRequestCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = CorrectionRequest
        fields = [
            'category',
            'target_record_ref',
            'current_value',
            'requested_value',
            'description',
            'reason',
            'evidence_file',
        ]

    def validate_category(self, value):
        valid = [k for k, _ in CATEGORY_CHOICES]
        if value not in valid:
            raise serializers.ValidationError(f"Invalid category '{value}'.")
        return value

    def validate_description(self, value):
        if not value or len(value.strip()) < 5:
            raise serializers.ValidationError("Please provide a detailed mistake description (min 5 characters).")
        return value.strip()

    def validate_reason(self, value):
        if not value or len(value.strip()) < 5:
            raise serializers.ValidationError("Please provide a reason for the requested correction (min 5 characters).")
        return value.strip()

    def validate_evidence_file(self, value):
        if value:
            # 5MB limit
            if value.size > 5 * 1024 * 1024:
                raise serializers.ValidationError("Evidence file cannot exceed 5MB.")
            ext = value.name.split('.')[-1].lower()
            if ext not in ['pdf', 'png', 'jpg', 'jpeg', 'webp']:
                raise serializers.ValidationError("Evidence file must be a PDF or image (PNG, JPG, WEBP).")
        return value
