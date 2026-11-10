from rest_framework import serializers
from .models import Subject, SubjectAssignment, StudentWork
from faculty.models import Faculty
from academics.models import AcademicYear,Department

class SubjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subject
        fields = "__all__"


class SubjectAssignmentSerializer(serializers.ModelSerializer):
    faculty_name = serializers.CharField(source="faculty.name", read_only=True)
    subject_name = serializers.CharField(source="subject.subject_name", read_only=True)
    academic_year_name = serializers.CharField(source="academic_year.year_name", read_only=True)
    semester_name = serializers.CharField(source="semester.sem_number", read_only=True)
    department_name = serializers.CharField(source="department.name", read_only=True)  # optional

    class Meta:
        model = SubjectAssignment
        fields = [
            "id",
            "subject",
            "subject_name",
            "faculty",
            "faculty_name",
            "academic_year",
            "academic_year_name",
            "department",
            "semester",
            "semester_name"
        ]

    def validate(self, attrs):
        subject = attrs.get('subject') or (self.instance.subject if self.instance else None)
        department = attrs.get('department') or (self.instance.department if self.instance else None)
        semester = attrs.get('semester') or (self.instance.semester if self.instance else getattr(subject, 'semester', None))
        academic_year = attrs.get('academic_year') or (self.instance.academic_year if self.instance else None)
        faculty = attrs.get('faculty') or (self.instance.faculty if self.instance else None)

        if subject and department and academic_year:
            sem = semester or getattr(subject, 'semester', None)
            qs = SubjectAssignment.objects.filter(
                subject=subject,
                department=department,
                semester=sem,
                academic_year=academic_year,
            )
            if self.instance:
                qs = qs.exclude(pk=self.instance.pk)
            existing = qs.first()
            if existing and existing.faculty_id != (faculty.id if hasattr(faculty, 'id') else faculty):
                raise serializers.ValidationError(
                    "This subject is already assigned to another faculty member for the selected department, semester, and academic year. Each subject can be assigned to only one faculty member per academic offering. Please select a different subject or update the existing assignment."
                )
        return attrs


class StudentWorkSerializer(serializers.ModelSerializer):
    subject_name = serializers.CharField(source="subject.subject_name", read_only=True)
    subject_code = serializers.CharField(source="subject.subject_code", read_only=True)
    department_name = serializers.CharField(source="subject.department.name", read_only=True)
    semester_name = serializers.CharField(source="subject.semester.sem_number", read_only=True)
    faculty_name = serializers.CharField(source="faculty.name", read_only=True)
    work_image_url = serializers.SerializerMethodField()

    class Meta:
        model = StudentWork
        fields = [
            "id",
            "subject",
            "subject_name",
            "subject_code",
            "department_name",
            "semester_name",
            "faculty",
            "faculty_name",
            "created_by_user",
            "title",
            "description",
            "work_image",
            "work_image_url",
            "due_date",
            "max_marks",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "faculty", "created_by_user", "created_at", "updated_at"]

    def get_work_image_url(self, obj):
        if obj.work_image:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.work_image.url)
            return obj.work_image.url
        return None

