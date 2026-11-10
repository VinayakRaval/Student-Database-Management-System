from rest_framework import serializers
from .models import Faculty
from userlogin.models import CustomUser
import re

PHONE_REGEX = re.compile(r"^\+?\d{7,15}$")


class FacultySerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source="department.name", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)
    is_active = serializers.BooleanField(source="user.is_active", read_only=True)
    temp_password = serializers.SerializerMethodField()
    temporary_password = serializers.SerializerMethodField()
    password_setup_status = serializers.SerializerMethodField()
    password_setup_completed_at = serializers.DateTimeField(read_only=True)

    def get_password_setup_status(self, obj):
        if obj.password_setup_completed_at is not None:
            return "Password Reset Completed"
        if obj.user and not getattr(obj.user, "force_password_change", False) and not obj.temp_password:
            return "Password Reset Completed"
        return "Password Setup Pending"

    def get_temp_password(self, obj):
        # Once password setup is completed, NEVER return temporary password!
        if obj.password_setup_completed_at is not None:
            return None
        if obj.user and not getattr(obj.user, "force_password_change", False) and not obj.temp_password:
            return None
        request = self.context.get("request")
        if request and request.user and request.user.is_authenticated:
            role = (getattr(request.user, "role", "") or "").upper()
            if role in ["HOD", "PRINCIPAL", "SYSTEM", "ADMISSION"] or request.user.is_staff:
                if obj.temp_password:
                    return obj.temp_password
                if obj.user and getattr(obj.user, "force_password_change", False):
                    # Auto-generate temporary password for faculty awaiting password setup
                    try:
                        from userlogin.password_service import set_temporary_password_for_user
                        from userlogin.models import PasswordAuditLog
                        temp_pwd = set_temporary_password_for_user(
                            user=obj.user,
                            actor=request.user,
                            action=PasswordAuditLog.ACTION_INITIAL_CREATION,
                            request=request,
                        )
                        obj.temp_password = temp_pwd
                        Faculty.objects.filter(id=obj.id).update(temp_password=temp_pwd)
                        return temp_pwd
                    except Exception as e:
                        import logging
                        logging.getLogger(__name__).error(f"Error generating temp password for faculty {obj.faculty_id}: {e}")
                elif not obj.user and obj.temp_password:
                    return obj.temp_password
        return None

    def get_temporary_password(self, obj):
        return self.get_temp_password(obj)

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
            "designation",
            "employment_type",
            "is_guest_faculty",
            "date_of_joining",
            "photo",
            "status",
            "registration_date",
            "approved_date",
            "user",
            "user_email",
            "is_active",
            "temp_password",
            "temporary_password",
            "password_setup_status",
            "password_setup_completed_at",
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
        if data.get("date_of_joining") == "":
            data["date_of_joining"] = None
        if data.get("qualification") == "":
            data["qualification"] = None
        if data.get("address") == "":
            data["address"] = None
        if data.get("is_guest_faculty") in [True, "true", "True", "1", 1]:
            data["is_guest_faculty"] = True
            data["employment_type"] = "GUEST"
        elif data.get("employment_type") == "GUEST":
            data["is_guest_faculty"] = True
        return super().to_internal_value(data)

    def validate_phone(self, value):
        if not value:
            raise serializers.ValidationError("Phone number is required.")
        value = str(value).strip()
        if not PHONE_REGEX.match(value):
            raise serializers.ValidationError("Invalid phone number format.")

        # Check uniqueness against CustomUser accounts
        user_qs = CustomUser.objects.filter(phone=value)
        if self.instance and self.instance.user_id:
            user_qs = user_qs.exclude(id=self.instance.user_id)
        if user_qs.exists():
            raise serializers.ValidationError("A user or faculty with this phone number already exists.")

        # Check uniqueness against Faculty records (decrypting EncryptedCharField)
        existing_faculties = Faculty.objects.all()
        if self.instance:
            existing_faculties = existing_faculties.exclude(id=self.instance.id)
        for f in existing_faculties:
            if (f.phone or "").strip() == value:
                raise serializers.ValidationError("A faculty member with this phone number already exists.")

        return value

    def validate_email(self, value):
        if not value:
            raise serializers.ValidationError("Email address is required.")
        value = str(value).strip().lower()

        # Check uniqueness against CustomUser accounts
        user_qs = CustomUser.objects.filter(email__iexact=value)
        if self.instance and self.instance.user_id:
            user_qs = user_qs.exclude(id=self.instance.user_id)
        if user_qs.exists():
            raise serializers.ValidationError("A user with this email address already exists.")

        # Check uniqueness against Faculty records
        existing_faculties = Faculty.objects.all()
        if self.instance:
            existing_faculties = existing_faculties.exclude(id=self.instance.id)
        for f in existing_faculties:
            if (f.email or "").strip().lower() == value:
                raise serializers.ValidationError("A faculty member with this email address already exists.")

        return value

    def validate_faculty_id(self, value):
        if not value:
            raise serializers.ValidationError("Employee ID is required.")
        value = str(value).strip()

        # Check uniqueness against CustomUser accounts
        user_qs = CustomUser.objects.filter(user_id__iexact=value)
        if self.instance and self.instance.user_id:
            user_qs = user_qs.exclude(id=self.instance.user_id)
        if user_qs.exists():
            raise serializers.ValidationError("This Employee ID is already registered to an existing account.")

        # Check uniqueness against Faculty records
        fac_qs = Faculty.objects.filter(faculty_id__iexact=value)
        if self.instance:
            fac_qs = fac_qs.exclude(id=self.instance.id)
        if fac_qs.exists():
            raise serializers.ValidationError("A faculty member with this Employee ID already exists.")

        return value

    def validate_role(self, value):
        request = self.context.get('request')
        if request and request.user:
            caller_role = (getattr(request.user, 'role', '') or '').upper()
            if caller_role == 'HOD':
                allowed = ['PROFESSOR', 'GUEST_FACULTY', 'GUEST', 'FACULTY']
                if value and value.upper() not in allowed:
                    raise serializers.ValidationError("HOD can only assign Professor or Guest Faculty designations.")
        return value

    def validate(self, attrs):
        if not self.instance:
            mandatory_fields = ['faculty_id', 'name', 'gender', 'dob', 'address', 'phone', 'email', 'department', 'qualification']
            errors = {}
            for field in mandatory_fields:
                val = attrs.get(field)
                if val is None or (isinstance(val, str) and not val.strip()):
                    errors[field] = ["This field is mandatory."]
            if errors:
                raise serializers.ValidationError(errors)
        else:
            errors = {}
            for field in ['name', 'phone', 'email']:
                if field in attrs:
                    val = attrs.get(field)
                    if val is None or (isinstance(val, str) and not val.strip()):
                        errors[field] = ["This field is mandatory."]
            if errors:
                raise serializers.ValidationError(errors)
        return attrs
