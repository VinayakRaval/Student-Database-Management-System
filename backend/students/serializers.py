from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from userlogin.models import CustomUser
from .models import Student
from academics.models import Department, Semester, AcademicYear
from django.db import transaction
import random, string

def generate_random_password(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

class StudentSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    department_id = serializers.IntegerField(write_only=True, required=False)
    semester_id = serializers.IntegerField(write_only=True, required=False)
    academic_year_id = serializers.IntegerField(write_only=True, required=False)
    department_name = serializers.CharField(source='department.name', read_only=True)
    semester_name = serializers.CharField(source='semester.sem_number', read_only=True)
    academic_year_name = serializers.CharField(source='academic_year.year_name', read_only=True)

    documents = serializers.SerializerMethodField(read_only=True)


    class Meta:
        model = Student
        fields = '__all__'
        read_only_fields = ['usn', 'admission_id', 'registration_status']
        extra_kwargs = {
            'temporary_password': {'write_only': True}
        }

    def to_internal_value(self, data):
        # Build shallow dict to avoid QueryDict.copy() deepcopy/pickle failure on uploaded files
        if hasattr(data, 'getlist'):
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

        # Auto-generate CET number if omitted or blank
        if not data.get('cet_no'):
            import random
            data['cet_no'] = f"CET{random.randint(100000, 999999)}"

        # Default fallbacks for required encrypted fields
        if not data.get('religion'):
            data['religion'] = 'General'
        if not data.get('city_type'):
            data['city_type'] = 'urban'
        if not data.get('parent_occupation'):
            data['parent_occupation'] = 'Self-employed'
        if not data.get('address') and data.get('permanent_address'):
            data['address'] = data.get('permanent_address')
        elif not data.get('permanent_address') and data.get('address'):
            data['permanent_address'] = data.get('address')

        int_fields = [
            "sslc_obtain_marks", "sslc_total_marks",
            "puc_obtain_marks", "puc_total_marks",
            "diploma_obtain_marks", "diploma_total_marks",
            "department_id", "semester_id", "academic_year_id"
        ]
        for f in int_fields:
            if f in data:
                val = data[f]
                if val == "" or val == "null" or val == "None" or val is None:
                    data[f] = None
                elif isinstance(val, str):
                    try:
                        data[f] = int(val.strip())
                    except ValueError:
                        pass
        return super().to_internal_value(data)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data.pop('temporary_password', None)
        return data

    def validate(self, attrs):
        int_fields = [
            "sslc_obtain_marks", "sslc_total_marks",
            "puc_obtain_marks", "puc_total_marks",
            "diploma_obtain_marks", "diploma_total_marks",
        ]

        for f in int_fields:
            if attrs.get(f) == "":
                attrs[f] = None

        pairs = [
            ("sslc_obtain_marks", "sslc_total_marks", "SSLC"),
            ("puc_obtain_marks", "puc_total_marks", "PUC"),
            ("diploma_obtain_marks", "diploma_total_marks", "Diploma"),
        ]
        for obt, tot, label in pairs:
            obt_val = attrs.get(obt)
            tot_val = attrs.get(tot)
            if obt_val is not None and tot_val is not None:
                if obt_val > tot_val:
                    raise serializers.ValidationError({obt: f"{label} obtained marks cannot exceed total marks."})

        return attrs


    def get_documents(self, obj):
        return {
            "photo": obj.photo.url if obj.photo else None,
            "signature": obj.signature.url if obj.signature else None,
            "sslc_marksheet": obj.sslc_marksheet.url if obj.sslc_marksheet else None,
            "puc_marksheet": obj.puc_marksheet.url if obj.puc_marksheet else None,
            "diploma_marksheet": obj.diploma_marksheet.url if obj.diploma_marksheet else None,
            "study_certificate": obj.study_certificate.url if obj.study_certificate else None,
            "caste_certificate": obj.caste_certificate.url if obj.caste_certificate else None,
            "kannada_medium_certificate": obj.kannada_medium_certificate.url if obj.kannada_medium_certificate else None,
            "hyderabad_karnataka_certificate": obj.hyderabad_karnataka_certificate.url if obj.hyderabad_karnataka_certificate else None,
            "kea_acknowledgement": obj.kea_acknowledgement.url if obj.kea_acknowledgement else None,
        }

    @transaction.atomic
    def create(self, validated_data):
        dept_id = validated_data.pop('department_id', None)
        sem_id = validated_data.pop('semester_id', None)
        year_id = validated_data.pop('academic_year_id', None)

        department = Department.objects.filter(id=dept_id).first() if dept_id else None
        semester = Semester.objects.filter(id=sem_id).first() if sem_id else None
        academic_year = AcademicYear.objects.filter(id=year_id).first() if year_id else None

        email = validated_data.get('email')
        phone = validated_data.get('mobile_no')
        cet_no = validated_data.get('cet_no')

        if not cet_no:
            cet_no = f"CET{random.randint(100000, 999999)}"
            validated_data['cet_no'] = cet_no

        if not validated_data.get('address') and validated_data.get('permanent_address'):
            validated_data['address'] = validated_data.get('permanent_address')
        elif not validated_data.get('permanent_address') and validated_data.get('address'):
            validated_data['permanent_address'] = validated_data.get('address')

        if not validated_data.get('parent_occupation'):
            validated_data['parent_occupation'] = 'Self-employed'
        if not validated_data.get('religion'):
            validated_data['religion'] = 'General'
        if not validated_data.get('city_type'):
            validated_data['city_type'] = 'urban'

        if CustomUser.objects.filter(email=email).exists():
            raise serializers.ValidationError({"email": "A user with this email already exists."})
        if CustomUser.objects.filter(phone=phone).exists():
            raise serializers.ValidationError({"phone": "A user with this phone number already exists."})
        if cet_no and Student.objects.filter(cet_no=cet_no).exists():
            raise serializers.ValidationError({"cet_no": "A student with this CET number is already registered."})

        user = CustomUser.objects.create_user(
            email=email,
            phone=phone,
            password=None,  # Unusable password until secure activation
            role='STUDENT',
            department=department,
            force_password_change=True,
            is_active=False   # Disabled until approved / activated via token
        )

        validated_data['user'] = user
        validated_data['department'] = department
        validated_data['semester'] = semester
        validated_data['academic_year'] = academic_year
        if not validated_data.get('status'):
            validated_data['status'] = 'active'
        if not validated_data.get('registration_status'):
            validated_data['registration_status'] = 'pending'

        student = Student.objects.create(**validated_data)
        student.temporary_password = None  # Plaintext password eliminated
        student.save(update_fields=["temporary_password"])

        if student.admission_id:
            user.user_id = student.admission_id
            user.save(update_fields=['user_id'])

        return student

    def update(self, instance, validated_data):
        model_map = {
            'department_id': (Department, 'department'),
            'semester_id': (Semester, 'semester'),
            'academic_year_id': (AcademicYear, 'academic_year')
        }
        for field, (model_cls, attr_name) in model_map.items():
            if field in validated_data:
                related_id = validated_data.pop(field)
                if related_id:
                    rel_obj = model_cls.objects.filter(id=related_id).first()
                    setattr(instance, attr_name, rel_obj)
                else:
                    setattr(instance, attr_name, None)


        if instance.user:
            email = validated_data.get('email', instance.user.email)
            phone = validated_data.get('mobile_no', instance.user.phone)
            # Update user fields
            instance.user.email = email
            instance.user.phone = phone
            instance.user.save()

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()
        return instance
