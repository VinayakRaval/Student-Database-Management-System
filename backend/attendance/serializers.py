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

from django.db import transaction

# --- 2. Session Create Serializer (For Faculty "Mark Attendance" - Writes) ---
class AttendanceSessionCreateSerializer(serializers.ModelSerializer):
    timetable_slot = serializers.IntegerField(write_only=True, required=False)
    records = AttendanceRecordSerializer(many=True)

    class Meta:
        model = AttendanceSession
        fields = ['faculty', 'subject', 'timetable_slot', 'date', 'records']

    def validate(self, data):
        slot_id = data.get('timetable_slot')
        subject = data.get('subject')
        faculty = data.get('faculty')

        slot = None
        if slot_id:
            from timetable.models import TimeTableSlot
            slot = TimeTableSlot.objects.select_related(
                'assignment__subject', 'assignment__faculty',
                'assignment__department', 'assignment__semester'
            ).filter(id=slot_id).first()

        if slot and subject:
            slot_subject = slot.assignment.subject
            if slot_subject.id != subject.id:
                raise serializers.ValidationError("Subject does not match the timetable slot's assigned subject.")

        if slot and faculty:
            if slot.assignment.faculty_id != faculty.id:
                raise serializers.ValidationError("Faculty does not match the timetable slot's assigned faculty.")

        records = data.get('records', [])
        if not records:
            raise serializers.ValidationError("Attendance records list cannot be empty.")

        if slot:
            target_dept = slot.assignment.department or slot.assignment.subject.department
            target_sem = slot.assignment.semester or slot.assignment.subject.semester
            for rec in records:
                student = rec.get('student')
                if student:
                    if student.department_id != target_dept.id or student.semester_id != target_sem.id:
                        raise serializers.ValidationError(
                            f"Student {getattr(student, 'usn', student.id)} does not belong to the required department/semester for this class."
                        )

        return data

    @transaction.atomic
    def create(self, validated_data):
        validated_data.pop('timetable_slot', None)
        records_data = validated_data.pop('records')
        
        session, created = AttendanceSession.objects.get_or_create(
            subject=validated_data['subject'],
            faculty=validated_data['faculty'],
            date=validated_data['date'],
            defaults={'session_count': validated_data.get('session_count', 1)}
        )
        if not created:
            session.records.all().delete()

        attendance_records = [
            AttendanceRecord(session=session, **record_data)
            for record_data in records_data
        ]
        AttendanceRecord.objects.bulk_create(attendance_records)
        return session

# --- 3. Session Read Serializer (For Reports/History - Reads) ---
class AttendanceSessionSerializer(serializers.ModelSerializer):
    records = AttendanceRecordSerializer(many=True, read_only=True)
    subject_name = serializers.CharField(source='subject.subject_name', read_only=True)
    faculty_name = serializers.CharField(source='faculty.name', read_only=True)

    class Meta:
        model = AttendanceSession
        fields = ['id', 'faculty_name', 'subject_name', 'date', 'session_count', 'records']