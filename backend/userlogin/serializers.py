from rest_framework import serializers
from .models import CustomUser

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = [
            "id", "email", "phone", "user_id",
            "role", "department",
            "force_password_change", "is_staff", "is_active", "date_joined"
        ]
        read_only_fields = ["id", "is_staff", "is_active", "date_joined"]