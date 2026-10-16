from rest_framework import serializers
from .models import IATestSetup, IAMark, IAAggregate


class IATestSetupSerializer(serializers.ModelSerializer):
    class Meta:
        model = IATestSetup
        fields = "__all__"
        read_only_fields = ("faculty",)
        validators = []  # Handled in view via get_or_create / find_or_update



class IAMarkSerializer(serializers.ModelSerializer):
    max_marks = serializers.SerializerMethodField()
    ia_name = serializers.CharField(source='ia_test.ia_name', read_only=True)
    ia_type = serializers.CharField(source='ia_test.ia_type', read_only=True)
    subject_name = serializers.CharField(source='ia_test.subject.subject_name', read_only=True)
    subject_code = serializers.CharField(source='ia_test.subject.subject_code', read_only=True)

    class Meta:
        model = IAMark
        fields = ['id', 'student', 'ia_test', 'obtained_marks', 'max_marks', 'ia_name', 'ia_type', 'subject_name', 'subject_code']

    def get_max_marks(self, obj):
        return obj.ia_test.max_marks


class IAAggregateSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source="student.name", read_only=True)
    usn = serializers.CharField(source="student.usn", read_only=True)
    subject_name = serializers.CharField(source="subject.subject_name", read_only=True)

    class Meta:
        model = IAAggregate
        fields = "__all__"
