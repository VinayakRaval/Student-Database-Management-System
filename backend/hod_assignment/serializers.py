from rest_framework import serializers
from .models import HODAssignment

class HODAssignmentSerializer(serializers.ModelSerializer):
    faculty_name = serializers.CharField(source='faculty.name', read_only=True)
    department_name = serializers.CharField(source='department.name', read_only=True)

    class Meta:
        model = HODAssignment
        fields = ['id', 'faculty', 'faculty_name', 'department', 'department_name', 'assigned_date', 'end_date']
 