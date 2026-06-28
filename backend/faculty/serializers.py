from rest_framework import serializers
from .models import Faculty
import re

PHONE_REGEX = re.compile(r"^\+?\d{7,15}$")

class FacultySerializer(serializers.ModelSerializer):
    class Meta:
        model = Faculty
        fields = "__all__"
        read_only_fields = ("registration_date", "approved_date", "user")

    def validate_phone(self, value):
        if not PHONE_REGEX.match(value):
            raise serializers.ValidationError("Invalid phone number.")
        return value
