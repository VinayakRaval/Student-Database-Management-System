from rest_framework import serializers
from .models import TimeTable, TimeTableSlot
from subjects.models import SubjectAssignment

# --- SLOT SERIALIZER ---
class TimeTableSlotSerializer(serializers.ModelSerializer):
    assignment_info = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = TimeTableSlot
        fields = ["id", "day", "start_time", "end_time", "assignment", "assignment_info"]

    def get_assignment_info(self, obj):
        a = obj.assignment
        return {
            "id": a.id,
            "subject_code": getattr(a.subject, "subject_code", None),
            "subject_name": getattr(a.subject, "subject_name", None),
            "faculty_id": getattr(a.faculty, "id", None),
            # FIX: Use .name directly
            "faculty_name": getattr(a.faculty, "name", "Unknown"), 
            "semester": getattr(a.subject.semester, "sem_number", None),
            "academic_year": getattr(a.academic_year, "year_name", None),
        }

# --- TIMETABLE SERIALIZER ---
class TimeTableSerializer(serializers.ModelSerializer):
    slots = TimeTableSlotSerializer(many=True)
    
    # Read-Only Display Fields
    department_name = serializers.CharField(source="department.name", read_only=True)
    semester_no = serializers.IntegerField(source="semester.sem_number", read_only=True)
    academic_year_label = serializers.CharField(source="academic_year.year_name", read_only=True)

    class Meta:
        model = TimeTable
        # FIX: Explicitly included 'semester_no' to prevent 500 Error
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

    def validate(self, data):
        slots = data.get("slots", [])
        # Handle instance for Update vs Create
        if self.instance:
            academic_year = data.get("academic_year", self.instance.academic_year)
            dept = data.get("department", self.instance.department)
            sem = data.get("semester", self.instance.semester)
        else:
            academic_year = data.get("academic_year")
            dept = data.get("department")
            sem = data.get("semester")

        for slot in slots:
            assign_id = slot.get("assignment")
            if not assign_id:
                raise serializers.ValidationError("Each slot must include an assignment id.")

            try:
                sa = SubjectAssignment.objects.get(pk=assign_id.id if hasattr(assign_id, "id") else assign_id)
            except SubjectAssignment.DoesNotExist:
                raise serializers.ValidationError(f"SubjectAssignment {assign_id} does not exist.")

            if sa.subject.department != dept:
                raise serializers.ValidationError("Assignment department mismatch.")
            if sa.subject.semester != sem:
                raise serializers.ValidationError("Assignment semester mismatch.")
            if sa.academic_year != academic_year:
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
    branch_name = serializers.CharField(source="assignment.subject.department.name", read_only=True)
    semester = serializers.IntegerField(source="assignment.subject.semester.sem_number", read_only=True)
    
    class Meta:
        model = TimeTableSlot
        fields = [
            "id", "day", "start_time", "end_time", 
            "subject_name", "subject_code", 
            "branch_name", "semester"
        ]