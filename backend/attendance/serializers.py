from rest_framework import serializers
from .models import AttendanceSession, AttendanceRecord
from students.models import Student

# --- 1. Record Serializer (Used inside Session) ---
class AttendanceRecordSerializer(serializers.ModelSerializer):
    student_id = serializers.PrimaryKeyRelatedField(
        queryset=Student.objects.all(), source='student'
    )

    class Meta:
        model = AttendanceRecord
        fields = ['student_id', 'status']

# --- 2. Session Create Serializer (For Faculty "Mark Attendance" - Writes) ---
class AttendanceSessionCreateSerializer(serializers.ModelSerializer):
    records = AttendanceRecordSerializer(many=True)

    class Meta:
        model = AttendanceSession
        fields = ['faculty', 'subject', 'timetable_slot', 'date', 'records']

    def create(self, validated_data):
        # Extract records data
        records_data = validated_data.pop('records')
        
        # 1. Create the Session
        session = AttendanceSession.objects.create(**validated_data)

        # 2. Bulk Create Records
        attendance_records = [
            AttendanceRecord(session=session, **record_data)
            for record_data in records_data
        ]
        AttendanceRecord.objects.bulk_create(attendance_records)

        return session

# --- 3. Session Read Serializer (For Reports/History - Reads) ---
class AttendanceSessionSerializer(serializers.ModelSerializer):
    # This serializer is used when viewing attendance history
    # It doesn't need the bulk create logic
    records = AttendanceRecordSerializer(many=True, read_only=True)
    subject_name = serializers.CharField(source='subject.subject_name', read_only=True)
    faculty_name = serializers.CharField(source='faculty.name', read_only=True)

    class Meta:
        model = AttendanceSession
        fields = ['id', 'faculty_name', 'subject_name', 'timetable_slot', 'date', 'created_at', 'records']