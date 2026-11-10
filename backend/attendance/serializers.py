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
        slot_id = self.initial_data.get('timetable_slot') or validated_data.pop('timetable_slot', None)
        records_data = validated_data.pop('records')
        
        start_time = None
        end_time = None
        if slot_id:
            from timetable.models import TimeTableSlot
            slot = TimeTableSlot.objects.filter(id=slot_id).first()
            if slot:
                start_time = slot.start_time
                end_time = slot.end_time

        session_defaults = {
            'session_count': validated_data.get('session_count', 1),
        }
        if start_time and end_time:
            session_defaults['start_time'] = start_time
            session_defaults['end_time'] = end_time

        session, created = AttendanceSession.objects.get_or_create(
            subject=validated_data['subject'],
            faculty=validated_data['faculty'],
            date=validated_data['date'],
            defaults=session_defaults
        )
        if not created:
            if start_time and end_time:
                session.start_time = start_time
                session.end_time = end_time
                session.save(update_fields=['start_time', 'end_time'])
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
    is_extra_class = serializers.SerializerMethodField()
    timing = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceSession
        fields = [
            'id', 'faculty_name', 'subject_name', 'session_type', 'batch', 'date', 
            'session_count', 'start_time', 'end_time', 'timing', 'is_extra_class', 'records'
        ]

    def get_is_extra_class(self, obj):
        return obj.extra_class is not None

    def get_timing(self, obj):
        st = obj.start_time or (obj.extra_class.start_time if obj.extra_class else None)
        et = obj.end_time or (obj.extra_class.end_time if obj.extra_class else None)
        if st and et:
            return f"{st.strftime('%I:%M %p')} - {et.strftime('%I:%M %p')}"
        return ""


# ==========================================
# LAB BATCH SERIALIZERS
# ==========================================
from .models import LabBatch, LabBatchStudent, AttendanceAuditLog


class LabBatchStudentSerializer(serializers.ModelSerializer):
    student_id = serializers.IntegerField(source='student.id', read_only=True)
    usn = serializers.CharField(source='student.usn', read_only=True)
    name = serializers.CharField(source='student.name', read_only=True)
    department_name = serializers.CharField(source='student.department.name', read_only=True)
    semester = serializers.CharField(source='student.semester.sem_number', read_only=True)

    class Meta:
        model = LabBatchStudent
        fields = ['id', 'student_id', 'usn', 'name', 'department_name', 'semester', 'assigned_at']


class LabBatchSerializer(serializers.ModelSerializer):
    identifier = serializers.CharField(read_only=True)
    is_shared = serializers.SerializerMethodField(read_only=True)
    subject_id = serializers.SerializerMethodField()
    subject_name = serializers.SerializerMethodField()
    subject_code = serializers.SerializerMethodField()
    department_name = serializers.CharField(source='department.name', read_only=True)
    semester_name = serializers.CharField(source='semester.sem_number', read_only=True)
    semester_no = serializers.CharField(source='semester.sem_number', read_only=True)
    academic_year_name = serializers.CharField(source='academic_year.year_name', read_only=True)
    faculty_name = serializers.SerializerMethodField()
    student_count = serializers.SerializerMethodField()
    students = LabBatchStudentSerializer(source='batch_students', many=True, read_only=True)

    class Meta:
        model = LabBatch
        fields = [
            'id', 'identifier', 'name', 'is_shared', 'subject', 'subject_id', 'subject_code', 'subject_name',
            'department', 'department_name', 'semester', 'semester_name', 'semester_no',
            'academic_year', 'academic_year_name', 'faculty', 'faculty_name',
            'student_count', 'students', 'created_at', 'updated_at'
        ]

    def get_is_shared(self, obj):
        return obj.subject_id is None

    def _get_resolved_subject(self, obj):
        if hasattr(obj, '_cached_resolved_sub'):
            return obj._cached_resolved_sub
        if obj.subject:
            obj._cached_resolved_sub = obj.subject
            return obj.subject

        req = self.context.get('request')
        # If client explicitly queries for a specific subject_id, associate this shared batch with that queried subject
        if req and hasattr(req, 'query_params') and req.query_params.get('subject_id'):
            from subjects.models import Subject
            sub_id = req.query_params.get('subject_id')
            sub = Subject.objects.filter(id=sub_id).first()
            if sub:
                obj._cached_resolved_sub = sub
                return sub

        from attendance.views import resolve_lab_batch_subject
        from timetable.views import _resolve_faculty_for_user
        fac = None
        if req and getattr(req, 'user', None) and req.user.is_authenticated:
            fac = _resolve_faculty_for_user(req.user)
        sub = resolve_lab_batch_subject(obj, faculty=fac)
        obj._cached_resolved_sub = sub
        return sub

    def get_subject_id(self, obj):
        if obj.subject_id:
            return obj.subject_id
        req = self.context.get('request')
        if req and hasattr(req, 'query_params') and req.query_params.get('subject_id'):
            try:
                return int(req.query_params.get('subject_id'))
            except (ValueError, TypeError):
                pass
        return None

    def get_subject_name(self, obj):
        if obj.subject and obj.subject.subject_name:
            return obj.subject.subject_name
        req = self.context.get('request')
        if req and hasattr(req, 'query_params') and req.query_params.get('subject_id'):
            sub = self._get_resolved_subject(obj)
            return sub.subject_name if sub else ""
        return ""

    def get_subject_code(self, obj):
        if obj.subject and obj.subject.subject_code:
            return obj.subject.subject_code
        req = self.context.get('request')
        if req and hasattr(req, 'query_params') and req.query_params.get('subject_id'):
            sub = self._get_resolved_subject(obj)
            return sub.subject_code if sub else ""
        return ""

    def get_faculty_name(self, obj):
        if obj.faculty and obj.faculty.name:
            return obj.faculty.name
        sub = self._get_resolved_subject(obj)
        if sub:
            from subjects.models import SubjectAssignment
            sa = SubjectAssignment.objects.filter(subject=sub).first()
            if sa and sa.faculty:
                return sa.faculty.name
        return "Unassigned"

    def get_student_count(self, obj):
        return obj.batch_students.count()


class AttendanceAuditLogSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True)

    class Meta:
        model = AttendanceAuditLog
        fields = ['id', 'user', 'user_email', 'action', 'details', 'timestamp']


from .models import ExtraClassSession


class ExtraClassSessionSerializer(serializers.ModelSerializer):
    subject_code = serializers.CharField(source='subject.subject_code', read_only=True)
    subject_name = serializers.CharField(source='subject.subject_name', read_only=True)
    faculty_name = serializers.CharField(source='faculty.name', read_only=True)
    faculty_employee_id = serializers.CharField(source='faculty.faculty_id', read_only=True, default='')
    faculty_email = serializers.CharField(source='faculty.email', read_only=True, default='')
    professor_name = serializers.CharField(source='faculty.name', read_only=True)
    department_name = serializers.SerializerMethodField()
    semester_no = serializers.SerializerMethodField()
    batch_name = serializers.CharField(source='batch.name', read_only=True, default=None)
    created_by_email = serializers.CharField(source='created_by.email', read_only=True, default=None)
    reviewed_by_name = serializers.CharField(source='reviewed_by.get_full_name', read_only=True, default=None)
    effective_status = serializers.SerializerMethodField()
    conducted_attendance_session_id = serializers.SerializerMethodField()
    conducted_attendance_records_count = serializers.SerializerMethodField()
    academic_year = serializers.SerializerMethodField()

    class Meta:
        model = ExtraClassSession
        fields = [
            'id', 'subject', 'subject_code', 'subject_name',
            'faculty', 'faculty_name', 'faculty_employee_id', 'faculty_email', 'professor_name', 'department_name', 'semester_no',
            'session_type', 'batch', 'batch_name', 'date', 'start_time', 'end_time',
            'duration_minutes', 'room', 'reason', 'status', 'effective_status',
            'conducted_attendance_session_id', 'conducted_attendance_records_count', 'academic_year',
            'reviewed_by', 'reviewed_by_name', 'reviewed_at', 'remarks',
            'created_by', 'created_by_email', 'created_at', 'updated_at'
        ]
        read_only_fields = ['status', 'reviewed_by', 'reviewed_at', 'created_by', 'created_at', 'updated_at']

    def get_effective_status(self, obj):
        if obj.status == "CANCELLED":
            return "Cancelled"
        if obj.attendance_sessions.exists() or obj.status == "COMPLETED":
            return "Conducted"
        return "Scheduled"

    def get_conducted_attendance_session_id(self, obj):
        att = obj.attendance_sessions.first()
        return att.id if att else None

    def get_conducted_attendance_records_count(self, obj):
        att = obj.attendance_sessions.first()
        return att.records.count() if att else 0

    def get_academic_year(self, obj):
        assign = obj.subject.subjectassignment_set.first()
        if assign and assign.academic_year:
            return assign.academic_year.year_name
        return "2026-2027"

    def get_department_name(self, obj):
        if obj.subject and obj.subject.department:
            return obj.subject.department.name
        if obj.faculty and obj.faculty.department:
            return obj.faculty.department.name
        return ""

    def get_semester_no(self, obj):
        if obj.subject and obj.subject.semester:
            return getattr(obj.subject.semester, 'sem_number', str(obj.subject.semester))
        return ""


