from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from userlogin.models import CustomUser
from .models import Student
from academics.models import Department, Semester, AcademicYear
import random, string

def generate_random_password(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

class StudentSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    department_id = serializers.IntegerField(write_only=True, required=False)
    semester_id = serializers.IntegerField(write_only=True, required=False)
    academic_year_id = serializers.IntegerField(write_only=True, required=False)

    documents = serializers.SerializerMethodField(read_only=True)


    class Meta:
        model = Student
        fields = '__all__'
        read_only_fields = ['usn','admission_id', 'registration_status']

    def validate(self, attrs):
        int_fields = [
        "sslc_obtain_marks", "sslc_total_marks",
        "puc_obtain_marks", "puc_total_marks",
        "diploma_obtain_marks", "diploma_total_marks",
    ]

        for f in int_fields:
         if attrs.get(f) == "":
            attrs[f] = None

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

    def create(self, validated_data):
        dept_id = validated_data.pop('department_id', None)
        sem_id = validated_data.pop('semester_id', None)
        year_id = validated_data.pop('academic_year_id', None)

        department = Department.objects.get(id=dept_id) if dept_id else None
        semester = Semester.objects.get(id=sem_id) if sem_id else None
        academic_year = AcademicYear.objects.get(id=year_id) if year_id else None

        email = validated_data.get('email')
        phone = validated_data.get('mobile_no')

        if CustomUser.objects.filter(email=email).exists():
            raise serializers.ValidationError({"email": "Email already exists"})
        if CustomUser.objects.filter(phone=phone).exists():
            raise serializers.ValidationError({"phone": "Phone already exists"})

        default_password = generate_random_password()

        user = CustomUser.objects.create_user(
            email=email,
            phone=phone,
            password=make_password(default_password),
            role='STUDENT',
            department=department,
            force_password_change=True,
            is_active=False   # Disable login until approval
        )

        validated_data['user'] = user
        validated_data['department'] = department
        validated_data['semester'] = semester
        validated_data['academic_year'] = academic_year

        student = Student.objects.create(**validated_data)
        student.temporary_password = default_password
        student.save(update_fields=["temporary_password"])
        return student

    def update(self, instance, validated_data):
        for field in ['department_id', 'semester_id', 'academic_year_id']:
            if field in validated_data:
                model_map = {
                    'department_id': Department,
                    'semester_id': Semester,
                    'academic_year_id': AcademicYear
                }
                related_id = validated_data.pop(field)
                if related_id is not None and related_id != "":
                 model = model_map[field]
            setattr(instance, field.replace('_id', ''), model.objects.get(id=related_id))


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
