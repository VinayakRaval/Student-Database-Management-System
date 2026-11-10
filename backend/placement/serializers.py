from rest_framework import serializers
from .models import (
    Company,
    PlacementDrive,
    PlacementRound,
    PlacementApplication,
    PlacementOffer,
    RoundCandidateResult,
    StudentPlacementProfile,
    PlacementOfficerAssignment,
)
from faculty.models import Faculty
from academics.models import Department


class PlacementOfficerAssignmentSerializer(serializers.ModelSerializer):
    faculty_name = serializers.CharField(source='faculty.name', read_only=True)
    faculty_id_code = serializers.CharField(source='faculty.faculty_id', read_only=True)
    designation = serializers.CharField(source='faculty.designation', read_only=True)
    department_name = serializers.CharField(source='department.name', read_only=True)
    assigned_by_name = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = PlacementOfficerAssignment
        fields = [
            'id',
            'faculty',
            'faculty_name',
            'faculty_id_code',
            'designation',
            'department',
            'department_name',
            'assigned_by',
            'assigned_by_name',
            'official_email',
            'status',
            'assigned_date',
            'revoked_date',
            'photo_url',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['assigned_date', 'created_at', 'updated_at']

    def get_assigned_by_name(self, obj):
        if obj.assigned_by:
            return getattr(obj.assigned_by, 'name', None) or obj.assigned_by.email
        return "Principal"

    def get_photo_url(self, obj):
        if obj.faculty and obj.faculty.photo:
            try:
                return obj.faculty.photo.url
            except Exception:
                return None
        return None


class CompanySerializer(serializers.ModelSerializer):
    drives_count = serializers.SerializerMethodField()

    class Meta:
        model = Company
        fields = '__all__'

    def get_drives_count(self, obj):
        return obj.drives.count()


class PlacementDriveSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    eligible_departments_details = serializers.SerializerMethodField()
    applications_count = serializers.SerializerMethodField()

    class Meta:
        model = PlacementDrive
        fields = '__all__'

    def get_eligible_departments_details(self, obj):
        return [{'id': d.id, 'name': d.name} for d in obj.eligible_departments.all()]

    def get_applications_count(self, obj):
        return obj.applications.count()


class PlacementApplicationSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_usn = serializers.CharField(source='student.usn', read_only=True)
    student_email = serializers.CharField(source='student.email', read_only=True)
    company_name = serializers.CharField(source='drive.company.name', read_only=True)
    job_role = serializers.CharField(source='drive.job_role', read_only=True)
    package_lpa = serializers.DecimalField(source='drive.package_lpa', max_digits=6, decimal_places=2, read_only=True)

    class Meta:
        model = PlacementApplication
        fields = '__all__'


class PlacementOfferSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_usn = serializers.CharField(source='student.usn', read_only=True)
    company_name = serializers.CharField(source='company.name', read_only=True)
    job_role = serializers.CharField(source='drive.job_role', read_only=True)

    class Meta:
        model = PlacementOffer
        fields = '__all__'


class StudentPlacementProfileSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_usn = serializers.CharField(source='student.usn', read_only=True)

    class Meta:
        model = StudentPlacementProfile
        fields = '__all__'
