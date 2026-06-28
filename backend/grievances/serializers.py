from rest_framework import serializers
from .models import Grievance


class GrievanceSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source="student.user.email", read_only=True)
    target_name = serializers.CharField(source="target_user.email", read_only=True)

    class Meta:
        model = Grievance
        fields = [
            "id",
            "student",
            "student_name",
            "topic",
            "description",
            "target_role",
            "target_user",
            "target_name",
            "status",
            "response",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["student", "status", "response", "created_at", "updated_at"]
