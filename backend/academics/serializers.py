from rest_framework import serializers
from .models import Department, Semester,  AcademicYear, Schema


class DepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Department
        fields = ["id", "name"]


class SemesterSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()

    class Meta:
        model = Semester
        fields = ["id", "name"]

    def get_name(self, obj):
        return str(obj.sem_number)




    def get_department_name(self, obj):
        return obj.department.name if obj.department else None


class AcademicYearSerializer(serializers.ModelSerializer):
    class Meta:
        model = AcademicYear
        fields = ["id", "year_name"]


class SchemaSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source="department.name", read_only=True)

    class Meta:
        model = Schema
        fields = ["id", "name", "department", "department_name"]
