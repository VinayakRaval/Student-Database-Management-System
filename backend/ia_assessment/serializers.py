from rest_framework import serializers
from .models import (
    IATestSetup, IAMark, IAAggregate, IACalculationScheme,
    MarksCorrectionRequest, MarksSecurityAuditLog
)


class IATestSetupSerializer(serializers.ModelSerializer):
    batch_name = serializers.CharField(source='batch.name', read_only=True, default=None)
    faculty_name = serializers.CharField(source='faculty.get_full_name', read_only=True, default='')
    submitted_by_name = serializers.CharField(source='submitted_by.get_full_name', read_only=True, default='')
    approved_by_name = serializers.CharField(source='approved_by.get_full_name', read_only=True, default='')
    published_by_name = serializers.CharField(source='published_by.get_full_name', read_only=True, default='')

    class Meta:
        model = IATestSetup
        fields = "__all__"
        read_only_fields = ("faculty",)
        validators = []  # Handled in view via get_or_create / find_or_update



class IAMarkSerializer(serializers.ModelSerializer):
    max_marks = serializers.SerializerMethodField()
    ia_name = serializers.CharField(source='ia_test.ia_name', read_only=True)
    ia_type = serializers.CharField(source='ia_test.ia_type', read_only=True)
    component_type = serializers.CharField(source='ia_test.component_type', read_only=True)
    batch_name = serializers.CharField(source='ia_test.batch.name', read_only=True, default=None)
    subject_name = serializers.CharField(source='ia_test.subject.subject_name', read_only=True)
    subject_code = serializers.CharField(source='ia_test.subject.subject_code', read_only=True)
    is_locked = serializers.BooleanField(source='ia_test.is_locked', read_only=True)
    lock_reason = serializers.CharField(source='ia_test.lock_reason', read_only=True, default='')
    test_status = serializers.CharField(source='ia_test.status', read_only=True, default='DRAFT')
    is_published = serializers.BooleanField(source='ia_test.is_published', read_only=True, default=False)
    hod_remarks = serializers.CharField(source='ia_test.hod_remarks', read_only=True, default='')
    assessment_date = serializers.DateField(source='ia_test.assessment_date', read_only=True, default=None)
    submission_deadline = serializers.DateField(source='ia_test.submission_deadline', read_only=True, default=None)
    student_name = serializers.CharField(source='student.name', read_only=True, default='')
    student_usn = serializers.CharField(source='student.usn', read_only=True, default='')

    class Meta:
        model = IAMark
        fields = [
            'id', 'student', 'student_name', 'student_usn', 'ia_test', 'obtained_marks',
            'is_absent', 'is_exempted', 'remarks', 'status',
            'max_marks', 'ia_name', 'ia_type', 'component_type', 'batch_name',
            'subject_name', 'subject_code', 'is_locked', 'lock_reason',
            'test_status', 'is_published', 'hod_remarks', 'assessment_date', 'submission_deadline'
        ]

    def get_max_marks(self, obj):
        return obj.ia_test.max_marks



class IAAggregateSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source="student.name", read_only=True)
    usn = serializers.CharField(source="student.usn", read_only=True)
    subject_name = serializers.CharField(source="subject.subject_name", read_only=True)

    class Meta:
        model = IAAggregate
        fields = "__all__"


class MarksCorrectionRequestSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source="student.name", read_only=True)
    usn = serializers.CharField(source="student.usn", read_only=True)
    ia_name = serializers.CharField(source="ia_test.ia_name", read_only=True)
    ia_type = serializers.CharField(source="ia_test.ia_type", read_only=True)
    subject_code = serializers.CharField(source="ia_test.subject.subject_code", read_only=True)
    subject_name = serializers.CharField(source="ia_test.subject.subject_name", read_only=True)
    requested_by_name = serializers.CharField(source="requested_by.get_full_name", read_only=True)
    reviewed_by_name = serializers.CharField(source="reviewed_by.get_full_name", read_only=True)

    class Meta:
        model = MarksCorrectionRequest
        fields = "__all__"
        read_only_fields = ("original_marks", "requested_by", "requested_at", "status", "reviewed_by", "reviewed_at")


class MarksSecurityAuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source="actor.get_full_name", read_only=True)
    actor_email = serializers.CharField(source="actor.email", read_only=True)
    student_usn = serializers.CharField(source="student.usn", read_only=True)
    subject_code = serializers.CharField(source="subject.subject_code", read_only=True)
    ia_name = serializers.CharField(source="ia_test.ia_name", read_only=True)

    class Meta:
        model = MarksSecurityAuditLog
        fields = "__all__"


class IACalculationSchemeSerializer(serializers.ModelSerializer):
    class Meta:
        model = IACalculationScheme
        fields = "__all__"

