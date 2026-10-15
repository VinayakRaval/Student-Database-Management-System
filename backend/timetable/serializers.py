from rest_framework import serializers
from .models import TimeTable, TimeTableSlot
from subjects.models import SubjectAssignment

# --- SLOT SERIALIZER ---
class TimeTableSlotSerializer(serializers.ModelSerializer):
    assignment_info = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = TimeTableSlot
        fields = ["id", "day", "start_time", "end_time", "assignment", "assignment_info"]

    def validate(self, data):
        start = data.get("start_time")
        end = data.get("end_time")
        if start and end and start >= end:
            raise serializers.ValidationError("Start time must be before end time.")
        return data

    def get_assignment_info(self, obj):
        a = obj.assignment
        if not a:
            return None
        subject = getattr(a, "subject", None)
        faculty = getattr(a, "faculty", None)
        semester = getattr(a, "semester", None) or getattr(subject, "semester", None)
        academic_year = getattr(a, "academic_year", None)

        return {
            "id": a.id,
            "subject_code": getattr(subject, "subject_code", None),
            "subject_name": getattr(subject, "subject_name", None),
            "faculty_id": getattr(faculty, "id", None),
            "faculty_name": getattr(faculty, "name", "Unknown"), 
            "semester": getattr(semester, "sem_number", None),
            "academic_year": getattr(academic_year, "year_name", None),
        }

# --- TIMETABLE SERIALIZER ---
class TimeTableSerializer(serializers.ModelSerializer):
    slots = TimeTableSlotSerializer(many=True, required=False)
    
    # Read-Only Display Fields
    department_name = serializers.CharField(source="department.name", read_only=True)
    semester_no = serializers.IntegerField(source="semester.sem_number", read_only=True)
    academic_year_label = serializers.CharField(source="academic_year.year_name", read_only=True)

    class Meta:
        model = TimeTable
        fields = [
            "id", 
            "department", 
            "department_name", 
            "semester", 
            "semester_no", 
            "academic_year", 
            "academic_year_label", 
            "version", 
            "created_by", 
            "created_at",
            "status", 
            "is_active", 
            "approved_by", 
            "approved_at", 
            "remarks", 
            "slots",
        ]
        read_only_fields = ("version", "created_by", "created_at", "approved_by", "approved_at", "is_active")
        extra_kwargs = {
            "department": {"required": False},
            "semester": {"required": False},
            "academic_year": {"required": False},
        }

    def validate(self, data):
        slots = data.get("slots", None)
        # Handle instance for Update vs Create
        if self.instance:
            dept = data.get("department", self.instance.department)
            sem = data.get("semester", self.instance.semester)
            academic_year = data.get("academic_year", self.instance.academic_year)
        else:
            dept = data.get("department")
            sem = data.get("semester")
            academic_year = data.get("academic_year")
            if not dept or not sem or not academic_year:
                raise serializers.ValidationError("department, semester, and academic_year are required.")

        if slots is not None:
            dept_id = getattr(dept, "id", dept)
            sem_id = getattr(sem, "id", sem)
            ay_id = getattr(academic_year, "id", academic_year)

            for slot in slots:
                assign_id = slot.get("assignment")
                if not assign_id:
                    raise serializers.ValidationError("Each slot must include an assignment id.")

                try:
                    sa = SubjectAssignment.objects.select_related(
                        "subject", "subject__department", "subject__semester", "department", "semester", "academic_year"
                    ).get(pk=assign_id.id if hasattr(assign_id, "id") else assign_id)
                except SubjectAssignment.DoesNotExist:
                    raise serializers.ValidationError(f"SubjectAssignment {assign_id} does not exist.")

                sa_dept_id = getattr(sa.department, "id", sa.department_id) or getattr(getattr(sa.subject, "department", None), "id", None)
                sa_sem_id = getattr(sa.semester, "id", sa.semester_id) or getattr(getattr(sa.subject, "semester", None), "id", None)
                sa_ay_id = getattr(sa.academic_year, "id", sa.academic_year_id)

                if dept_id and sa_dept_id and sa_dept_id != dept_id:
                    raise serializers.ValidationError("Assignment department mismatch.")
                if sem_id and sa_sem_id and sa_sem_id != sem_id:
                    raise serializers.ValidationError("Assignment semester mismatch.")
                if ay_id and sa_ay_id and sa_ay_id != ay_id:
                    raise serializers.ValidationError("Assignment academic year mismatch.")

        return data

    def create(self, validated_data):
        slots_data = validated_data.pop("slots", [])
        same = TimeTable.objects.filter(
            department=validated_data["department"],
            semester=validated_data["semester"],
            academic_year=validated_data["academic_year"]
        ).order_by("-version").first()
        validated_data["version"] = same.version + 1 if same else 1

        tt = TimeTable.objects.create(**validated_data)
        for slot_data in slots_data:
            TimeTableSlot.objects.create(timetable=tt, **slot_data)
        return tt

    def update(self, instance, validated_data):
        instance.remarks = validated_data.get('remarks', instance.remarks)
        if 'department' in validated_data:
            instance.department = validated_data['department']
        if 'semester' in validated_data:
            instance.semester = validated_data['semester']
        if 'academic_year' in validated_data:
            instance.academic_year = validated_data['academic_year']

        if instance.status in ["Approved", "Rejected"]:
            instance.status = "Pending"
            instance.is_active = False

        instance.save()

        slots_data = validated_data.get('slots')
        if slots_data is not None:
            # Delete old slots and replace with new ones
            instance.slots.all().delete()
            for slot_data in slots_data:
                TimeTableSlot.objects.create(timetable=instance, **slot_data)

        return instance

# --- NEW: FACULTY SCHEDULE SERIALIZER (For "My Timetable" List) ---
class FacultyScheduleSerializer(serializers.ModelSerializer):
    subject_name = serializers.CharField(source="assignment.subject.subject_name", read_only=True)
    subject_code = serializers.CharField(source="assignment.subject.subject_code", read_only=True)
    branch_name = serializers.SerializerMethodField(read_only=True)
    faculty_name = serializers.SerializerMethodField(read_only=True)
    semester = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = TimeTableSlot
        fields = [
            "id", "day", "start_time", "end_time", 
            "subject_name", "subject_code", 
            "branch_name", "faculty_name", "semester"
        ]

    def get_branch_name(self, obj):
        if obj.assignment and obj.assignment.subject and obj.assignment.subject.department:
            return obj.assignment.subject.department.name
        if obj.timetable and obj.timetable.department:
            return obj.timetable.department.name
        return ""

    def get_faculty_name(self, obj):
        if obj.assignment and obj.assignment.faculty:
            return obj.assignment.faculty.name
        return "Not Assigned"

    def get_semester(self, obj):
        a = obj.assignment
        if a:
            sem = getattr(a.semester, "sem_number", None) or getattr(getattr(a.subject, "semester", None), "sem_number", None)
            if sem:
                return sem
        if obj.timetable and obj.timetable.semester:
            return obj.timetable.semester.sem_number
        return None