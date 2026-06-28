from rest_framework import serializers
from .models import Subject, SubjectAssignment
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
            "department_name",
            "semester",
            "semester_name"   # <-- now shows sem_number
        ]
