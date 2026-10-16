from rest_framework import serializers
from .models import Faculty
import re

PHONE_REGEX = re.compile(r"^\+?\d{7,15}$")


class FacultySerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source="department.name", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)
    is_active = serializers.BooleanField(source="user.is_active", read_only=True)

    class Meta:
        model = Faculty
        fields = [
            "id",
            "faculty_id",
            "name",
            "gender",
            "dob",
            "address",
            "phone",
            "email",
            "department",
            "department_name",
            "qualification",
            "role",
            "photo",
            "status",
            "registration_date",
            "approved_date",
            "user",
            "user_email",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = (
            "registration_date",
            "approved_date",
            "user",
            "created_at",
            "updated_at",
        )

    def to_internal_value(self, data):
        # Build shallow dict to avoid QueryDict.copy() deepcopy/pickle failure on uploaded files
        if hasattr(data, "getlist"):
            shallow = {}
            for k in data.keys():
                vals = data.getlist(k)
                if len(vals) == 1:
                    shallow[k] = vals[0]
                elif len(vals) > 1:
                    shallow[k] = vals
                else:
                    shallow[k] = None
            data = shallow
        elif isinstance(data, dict):
            data = dict(data)

        if data.get("dob") == "":
            data["dob"] = None
        if data.get("qualification") == "":
            data["qualification"] = None
        if data.get("address") == "":
            data["address"] = None
        return super().to_internal_value(data)

    def validate_phone(self, value):
        if not PHONE_REGEX.match(value):
            raise serializers.ValidationError("Invalid phone number format.")
        return value

    def validate_role(self, value):
        request = self.context.get('request')
        if request and request.user:
            caller_role = (getattr(request.user, 'role', '') or '').upper()
            if caller_role == 'HOD':
                if value and value.upper() in ['PRINCIPAL', 'SYSTEM']:
                    raise serializers.ValidationError("HOD is not authorized to assign Principal or System Admin roles.")
        return value
