from rest_framework import serializers
from .models import Department, Semester,  AcademicYear, Schema


ALLOWED_DEPARTMENTS = [
    "Computer Science and Engineering",
    "Electronics and Communication Engineering",
    "Civil Engineering",
    "Mechanical Engineering",
]

class DepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Department
        fields = ["id", "name"]

    def validate_name(self, value):
        val_clean = value.strip()
        if val_clean not in ALLOWED_DEPARTMENTS:
            raise serializers.ValidationError(
                f"Department must be one of: {', '.join(ALLOWED_DEPARTMENTS)}"
            )
        return val_clean


class SemesterSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()

    class Meta:
        model = Semester
        fields = ["id", "sem_number", "name"]

    def get_name(self, obj):
        return f"Semester {obj.sem_number}"


class AcademicYearSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="year_name", read_only=True)

    class Meta:
        model = AcademicYear
        fields = ["id", "year_name", "name"]


class SchemaSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source="department.name", read_only=True)

    class Meta:
        model = Schema
        fields = ["id", "name", "department", "department_name"]
