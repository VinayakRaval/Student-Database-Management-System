from rest_framework import serializers
from .models import CustomUser

class UserSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source="department.name", read_only=True)
    full_name = serializers.SerializerMethodField()
    name = serializers.SerializerMethodField()

    class Meta:
        model = CustomUser
        fields = [
            "id", "email", "phone", "user_id", "full_name", "name",
            "role", "department", "department_name",
            "force_password_change", "is_staff", "is_active", "date_joined"
        ]
        read_only_fields = ["id", "is_staff", "is_active", "date_joined"]

    def get_full_name(self, obj):
        return obj.get_full_name()

    def get_name(self, obj):
        return obj.get_full_name()