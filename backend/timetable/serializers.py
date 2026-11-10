from faculty.models import Faculty
from rest_framework import serializers
from .models import TimeTable, TimeTableSlot, TimeTableSlotBatch
from subjects.models import SubjectAssignment

def time_overlap(a_start, a_end, b_start, b_end):
    # Convert string to string comparison or time objects
    s_a = str(a_start)[:5]
    e_a = str(a_end)[:5]
    s_b = str(b_start)[:5]
    e_b = str(b_end)[:5]
    return (s_a < e_b) and (e_a > s_b)


# --- BATCH SERIALIZER ---
class TimeTableSlotBatchSerializer(serializers.ModelSerializer):
    assignment_info = serializers.SerializerMethodField(read_only=True)
    effective_start_time = serializers.SerializerMethodField(read_only=True)
    effective_end_time = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = TimeTableSlotBatch
        fields = [
            "id", "batch_name", "assignment", "assignment_info",
            "lab_room", "start_time", "end_time", "allow_co_teaching",
            "effective_start_time", "effective_end_time"
        ]

    def validate(self, data):
        start = data.get("start_time")
        end = data.get("end_time")
        if start and end and start >= end:
            raise serializers.ValidationError("Batch start time must be before end time.")
        return data

    def get_assignment_info(self, obj):
        a = obj.assignment
        if not a:
            return None
        subject = getattr(a, "subject", None)
        faculty = getattr(a, "faculty", None)
        semester = getattr(a, "semester", None) or getattr(subject, "semester", None)
        academic_year = getattr(a, "academic_year", None)

        subject_dept = getattr(subject, "department", None)
        cohort_dept = getattr(a, "department", None)

        p_disp = getattr(subject, "practical_display", str(getattr(subject, "practical_hours", 0))) if subject else "0"
        return {
            "id": a.id,
            "subject_code": getattr(subject, "subject_code", None),
            "subject_name": getattr(subject, "subject_name", None),
            "subject_department": getattr(subject_dept, "name", None),
            "student_department": getattr(cohort_dept, "name", None),
            "faculty_id": getattr(faculty, "id", None),
            "faculty_name": getattr(faculty, "name", "Unknown"), 
            "faculty_employee_id": getattr(faculty, "faculty_id", ""),
            "faculty_role": getattr(faculty, "role", ""),
            "semester": getattr(semester, "sem_number", None),
            "academic_year": getattr(academic_year, "year_name", None),
            "credits": getattr(subject, "credits", 4),
            "theory_hours": getattr(subject, "theory_hours", 3),
            "tutorial_hours": getattr(subject, "tutorial_hours", 0),
            "practical_hours": getattr(subject, "practical_hours", 0),
            "practical_sessions": getattr(subject, "practical_sessions", 0),
            "practical_duration_per_session": getattr(subject, "practical_duration_per_session", 0),
            "practical_display": p_disp,
            "total_teaching_hours": getattr(subject, "total_teaching_hours", 3),
        }

    def get_effective_start_time(self, obj):
        if obj.start_time:
            return str(obj.start_time)
        return str(obj.slot.start_time) if obj.slot_id else None

    def get_effective_end_time(self, obj):
        if obj.end_time:
            return str(obj.end_time)
        return str(obj.slot.end_time) if obj.slot_id else None


# --- SLOT SERIALIZER ---
class TimeTableSlotSerializer(serializers.ModelSerializer):
    assignment_info = serializers.SerializerMethodField(read_only=True)
    batches = TimeTableSlotBatchSerializer(many=True, required=False)

    class Meta:
        model = TimeTableSlot
        fields = [
            "id", "day", "start_time", "end_time", "assignment", "assignment_info",
            "is_batch_wise", "batch_name", "lab_room", "allow_co_teaching", "batches"
        ]
        extra_kwargs = {
            "assignment": {"required": False, "allow_null": True},
        }

    def validate(self, data):
        start = data.get("start_time")
        end = data.get("end_time")
        if start and end and start >= end:
            raise serializers.ValidationError("Start time must be before end time.")

        batches = data.get("batches") or []
        if batches:
            seen_names = set()
            for b in batches:
                name = (b.get("batch_name") or "").strip().lower()
                if name:
                    if name in seen_names:
                        raise serializers.ValidationError({"batches": f"Duplicate batch name '{b.get('batch_name')}'. Each batch must have a unique name."})
                    seen_names.add(name)
        return data

    def get_assignment_info(self, obj):
        a = obj.assignment
        if not a:
            return None
        subject = getattr(a, "subject", None)
        faculty = getattr(a, "faculty", None)
        semester = getattr(a, "semester", None) or getattr(subject, "semester", None)
        academic_year = getattr(a, "academic_year", None)

        subject_dept = getattr(subject, "department", None)
        cohort_dept = getattr(a, "department", None)

        p_disp = getattr(subject, "practical_display", str(getattr(subject, "practical_hours", 0))) if subject else "0"
        return {
            "id": a.id,
            "subject_code": getattr(subject, "subject_code", None),
            "subject_name": getattr(subject, "subject_name", None),
            "subject_department": getattr(subject_dept, "name", None),
            "student_department": getattr(cohort_dept, "name", None),
            "faculty_id": getattr(faculty, "id", None),
            "faculty_name": getattr(faculty, "name", "Unknown"), 
            "faculty_employee_id": getattr(faculty, "faculty_id", ""),
            "faculty_role": getattr(faculty, "role", ""),
            "semester": getattr(semester, "sem_number", None),
            "academic_year": getattr(academic_year, "year_name", None),
            "credits": getattr(subject, "credits", 4),
            "theory_hours": getattr(subject, "theory_hours", 3),
            "tutorial_hours": getattr(subject, "tutorial_hours", 0),
            "practical_hours": getattr(subject, "practical_hours", 0),
            "practical_sessions": getattr(subject, "practical_sessions", 0),
            "practical_duration_per_session": getattr(subject, "practical_duration_per_session", 0),
            "practical_display": p_disp,
            "total_teaching_hours": getattr(subject, "total_teaching_hours", 3),
        }


# --- TIMETABLE SERIALIZER ---
class TimeTableSerializer(serializers.ModelSerializer):
    slots = TimeTableSlotSerializer(many=True, required=False)
    
    # Class Teacher Fields
    class_teacher = serializers.PrimaryKeyRelatedField(
        queryset=Faculty.objects.all(),
        required=False,
        allow_null=True
    )
    class_teacher_name = serializers.CharField(source="class_teacher.name", read_only=True)
    class_teacher_id = serializers.IntegerField(source="class_teacher.id", read_only=True)
    class_teacher_employee_id = serializers.CharField(source="class_teacher.faculty_id", read_only=True)
    class_teacher_details = serializers.SerializerMethodField(read_only=True)

    # Read-Only Display Fields
    department_name = serializers.CharField(source="department.name", read_only=True)
    semester_no = serializers.IntegerField(source="semester.sem_number", read_only=True)
    academic_year_label = serializers.CharField(source="academic_year.year_name", read_only=True)
    institution_name = serializers.CharField(read_only=True)
    semester_type = serializers.CharField(read_only=True)
    formatted_title = serializers.CharField(read_only=True)
    effective_date_formatted = serializers.SerializerMethodField(read_only=True)

    subject_details = serializers.SerializerMethodField(read_only=True)
    teaching_hours_summary = serializers.SerializerMethodField(read_only=True)

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
            "class_teacher",
            "class_teacher_name",
            "class_teacher_id",
            "class_teacher_employee_id",
            "class_teacher_details",
            "effective_date",
            "effective_date_formatted",
            "institution_name",
            "semester_type",
            "formatted_title",
            "version", 
            "created_by", 
            "created_at",
            "status", 
            "is_active", 
            "approved_by", 
            "approved_at", 
            "remarks", 
            "slots",
            "subject_details",
            "teaching_hours_summary",
        ]
        read_only_fields = ("version", "created_by", "created_at", "approved_by", "approved_at", "is_active", "institution_name", "semester_type", "formatted_title")
        extra_kwargs = {
            "department": {"required": False},
            "semester": {"required": False},
            "academic_year": {"required": False},
        }

    def get_class_teacher_details(self, obj):
        ct = obj.class_teacher
        if not ct:
            return None
        return {
            "id": ct.id,
            "faculty_id": ct.faculty_id,
            "name": ct.name,
            "email": str(ct.email) if ct.email else "",
            "phone": str(ct.phone) if ct.phone else "",
            "designation": ct.designation or "Professor",
            "department_id": ct.department_id,
            "department_name": ct.department.name if ct.department else "",
        }

    def get_effective_date_formatted(self, obj):
        if obj.effective_date:
            return obj.effective_date.strftime("%d/%m/%Y")
        return ""

    def get_subject_details(self, obj):
        distinct_subjects = {}

        # 1. First fetch all official subject assignments for this department, semester, and academic year
        from subjects.models import SubjectAssignment
        dept_assignments = SubjectAssignment.objects.filter(
            department=obj.department,
            semester=obj.semester,
            academic_year=obj.academic_year,
            is_active=True
        ).select_related('subject', 'faculty')

        for a in dept_assignments:
            sub = getattr(a, "subject", None)
            if not sub or not sub.subject_code:
                continue
            code = sub.subject_code.strip()
            if code not in distinct_subjects:
                distinct_subjects[code] = {
                    "subject": sub,
                    "faculties": set(),
                }
            fac_name = getattr(getattr(a, "faculty", None), "name", None)
            if fac_name:
                distinct_subjects[code]["faculties"].add(fac_name)

        # 2. Also check scheduled slots and batches to capture all scheduled subjects
        for slot in obj.slots.all():
            assignments = []
            if slot.assignment:
                assignments.append(slot.assignment)
            for batch in slot.batches.all():
                if batch.assignment:
                    assignments.append(batch.assignment)

            for a in assignments:
                sub = getattr(a, "subject", None)
                if not sub or not sub.subject_code:
                    continue
                code = sub.subject_code.strip()
                if code not in distinct_subjects:
                    distinct_subjects[code] = {
                        "subject": sub,
                        "faculties": set(),
                    }
                fac_name = getattr(getattr(a, "faculty", None), "name", None)
                if fac_name:
                    distinct_subjects[code]["faculties"].add(fac_name)

        sorted_codes = sorted(distinct_subjects.keys())
        result = []
        for idx, code in enumerate(sorted_codes, start=1):
            info = distinct_subjects[code]
            sub = info["subject"]
            fac_list = sorted(list(info["faculties"]))
            fac_str = ", ".join(fac_list) if fac_list else "Not Assigned"
            p_disp = getattr(sub, "practical_display", str(getattr(sub, "practical_hours", 0)))
            th = getattr(sub, "theory_hours", 0) or 0
            tut = getattr(sub, "tutorial_hours", 0) or 0
            prac = getattr(sub, "practical_hours", 0) or 0
            tot = getattr(sub, "total_teaching_hours", 0) or (th + tut + prac)
            cr = getattr(sub, "credits", 0) or 0

            result.append({
                "sl_no": idx,
                "subject_code": sub.subject_code,
                "subject_name": sub.subject_name,
                "theory_hours": th,
                "tutorial_hours": tut,
                "practical_hours": prac,
                "practical_display": p_disp,
                "total_hours": tot,
                "credits": cr,
                "faculty_name": fac_str,
            })
        return result

    def get_teaching_hours_summary(self, obj):
        details = self.get_subject_details(obj)
        tot_theory = sum(item["theory_hours"] for item in details)
        tot_tut = sum(item["tutorial_hours"] for item in details)
        tot_prac = sum(item["practical_hours"] for item in details)
        tot_teaching = sum(item["total_hours"] for item in details)
        tot_credits = sum(item["credits"] for item in details)
        return {
            "total_theory_hours": tot_theory,
            "total_tutorial_hours": tot_tut,
            "total_practical_hours": tot_prac,
            "total_teaching_hours": tot_teaching,
            "total_credits": tot_credits,
            "subject_count": len(details),
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

            # Collect sessions to check internal timetable faculty conflicts
            sessions = []

            for slot in slots:
                is_batch_wise = slot.get("is_batch_wise", False)
                batches = slot.get("batches", [])
                assign_id = slot.get("assignment")
                slot_day = slot.get("day")
                slot_start = slot.get("start_time")
                slot_end = slot.get("end_time")
                slot_co_teaching = slot.get("allow_co_teaching", False)

                if not assign_id and not batches:
                    raise serializers.ValidationError("Each slot must include an assignment id or batches.")

                # Validate slot assignment if present
                if assign_id:
                    self._validate_assignment_scope(assign_id, dept_id, sem_id, ay_id)
                    sa = self._get_sa(assign_id)
                    if sa and not batches:
                        sessions.append({
                            "day": slot_day,
                            "start": slot_start,
                            "end": slot_end,
                            "faculty_id": sa.faculty_id,
                            "faculty_name": sa.faculty.name if sa.faculty else "Faculty",
                            "allow_co_teaching": slot_co_teaching,
                            "label": sa.subject.subject_name if sa.subject else "Class",
                        })

                # Validate batches if present
                if batches:
                    for b in batches:
                        b_assign_id = b.get("assignment")
                        if not b_assign_id:
                            raise serializers.ValidationError(f"Batch '{b.get('batch_name', '')}' must have an assigned subject and faculty.")
                        self._validate_assignment_scope(b_assign_id, dept_id, sem_id, ay_id)
                        sa = self._get_sa(b_assign_id)
                        if sa:
                            b_start = b.get("start_time") or slot_start
                            b_end = b.get("end_time") or slot_end
                            b_co_teaching = b.get("allow_co_teaching", False) or slot_co_teaching
                            sessions.append({
                                "day": slot_day,
                                "start": b_start,
                                "end": b_end,
                                "faculty_id": sa.faculty_id,
                                "faculty_name": sa.faculty.name if sa.faculty else "Faculty",
                                "allow_co_teaching": b_co_teaching,
                                "label": f"Batch {b.get('batch_name', '')} ({sa.subject.subject_name if sa.subject else ''})",
                            })

            # Check internal faculty conflicts (overlapping time slots on the same day for same faculty)
            for i in range(len(sessions)):
                for j in range(i + 1, len(sessions)):
                    s1 = sessions[i]
                    s2 = sessions[j]
                    if s1["day"] == s2["day"] and s1["faculty_id"] and s1["faculty_id"] == s2["faculty_id"]:
                        if time_overlap(s1["start"], s1["end"], s2["start"], s2["end"]):
                            # Simultaneous overlap! Permitted only if co-teaching is explicitly allowed
                            if not (s1["allow_co_teaching"] and s2["allow_co_teaching"]):
                                raise serializers.ValidationError(
                                    f"Faculty conflict: {s1['faculty_name']} is assigned to overlapping simultaneous slots on {s1['day']} "
                                    f"({str(s1['start'])[:5]}-{str(s1['end'])[:5]} for {s1['label']} and "
                                    f"{str(s2['start'])[:5]}-{str(s2['end'])[:5]} for {s2['label']}). "
                                    f"Enable co-teaching to permit simultaneous multi-batch assignment."
                                )

        return data

    def _get_sa(self, assign_id):
        aid = assign_id.id if hasattr(assign_id, "id") else assign_id
        return SubjectAssignment.objects.select_related("faculty", "subject").filter(pk=aid).first()

    def _validate_assignment_scope(self, assign_id, dept_id, sem_id, ay_id):
        try:
            aid = assign_id.id if hasattr(assign_id, "id") else assign_id
            sa = SubjectAssignment.objects.select_related(
                "subject", "subject__department", "subject__semester", "department", "semester", "academic_year"
            ).get(pk=aid)
        except SubjectAssignment.DoesNotExist:
            raise serializers.ValidationError(f"SubjectAssignment {assign_id} does not exist.")

        sa_cohort_dept_id = getattr(sa.department, "id", sa.department_id)
        sa_subject_dept_id = getattr(getattr(sa.subject, "department", None), "id", None)
        sa_sem_id = getattr(sa.semester, "id", sa.semester_id) or getattr(getattr(sa.subject, "semester", None), "id", None)
        sa_ay_id = getattr(sa.academic_year, "id", sa.academic_year_id)

        if dept_id:
            if sa_cohort_dept_id and sa_cohort_dept_id != dept_id:
                raise serializers.ValidationError("Assignment department mismatch: student cohort department does not match timetable department.")
            elif not sa_cohort_dept_id and sa_subject_dept_id and sa_subject_dept_id != dept_id:
                raise serializers.ValidationError("Assignment department mismatch: subject department does not match timetable department.")

        if sem_id and sa_sem_id and sa_sem_id != sem_id:
            raise serializers.ValidationError("Assignment semester mismatch.")
        if ay_id and sa_ay_id and sa_ay_id != ay_id:
            raise serializers.ValidationError("Assignment academic year mismatch.")

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
            batches_data = slot_data.pop("batches", [])
            if batches_data:
                slot_data["is_batch_wise"] = True
                if not slot_data.get("assignment"):
                    slot_data["assignment"] = batches_data[0].get("assignment")
            slot = TimeTableSlot.objects.create(timetable=tt, **slot_data)
            for b_data in batches_data:
                TimeTableSlotBatch.objects.create(slot=slot, **b_data)

        # Assign class teacher to students of this semester & department
        if tt.class_teacher:
            self._assign_class_teacher_to_students(tt)

        return tt

    def _assign_class_teacher_to_students(self, tt):
        if not tt.class_teacher:
            return
        try:
            from students.models import Student, StudentAcademicHistory
            from timetable.models import SemesterClassTeacher

            # 1. Update Student records in this department & semester
            Student.objects.filter(
                department=tt.department,
                semester=tt.semester
            ).update(class_teacher=tt.class_teacher)

            # 2. Update StudentAcademicHistory records
            StudentAcademicHistory.objects.filter(
                department=tt.department,
                semester=tt.semester,
                academic_year=tt.academic_year
            ).update(class_teacher=tt.class_teacher)

            # 3. Create or update SemesterClassTeacher record
            SemesterClassTeacher.objects.update_or_create(
                department=tt.department,
                semester=tt.semester,
                academic_year=tt.academic_year,
                defaults={
                    "faculty": tt.class_teacher,
                    "timetable": tt,
                }
            )
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("Failed to auto-assign class teacher to students: %s", e)

    def update(self, instance, validated_data):
        instance.remarks = validated_data.get('remarks', instance.remarks)
        if 'department' in validated_data:
            instance.department = validated_data['department']
        if 'semester' in validated_data:
            instance.semester = validated_data['semester']
        if 'academic_year' in validated_data:
            instance.academic_year = validated_data['academic_year']
        if 'effective_date' in validated_data:
            instance.effective_date = validated_data['effective_date']
        if 'class_teacher' in validated_data:
            instance.class_teacher = validated_data['class_teacher']
            if instance.class_teacher:
                self._assign_class_teacher_to_students(instance)

        # Timetable Approval & Reapproval Workflow:
        # If any edits/changes are made to an approved timetable, automatically mark it as
        # "Pending Reapproval" (or PENDING_REAPPROVAL) and route it through the approval workflow again.
        if instance.status == "Approved":
            instance.status = "Pending Reapproval"
            instance.is_active = False
            instance.version = (instance.version or 1) + 1
            try:
                from timetable.models import TimeTableApprovalHistory
                request = self.context.get("request")
                user = request.user if request and request.user and request.user.is_authenticated else None
                TimeTableApprovalHistory.objects.create(
                    timetable=instance,
                    action="Edited - Pending Reapproval",
                    remarks=f"Timetable edited to version {instance.version}; awaiting reapproval.",
                    action_by=user
                )
            except Exception:
                pass
        elif instance.status == "Rejected":
            instance.status = "Pending"
            instance.is_active = False

        instance.save()

        slots_data = validated_data.get('slots')
        if slots_data is not None:
            # Delete old slots and replace with new ones (cascade removes old batches)
            instance.slots.all().delete()
            for slot_data in slots_data:
                batches_data = slot_data.pop("batches", [])
                if batches_data:
                    slot_data["is_batch_wise"] = True
                    if not slot_data.get("assignment"):
                        slot_data["assignment"] = batches_data[0].get("assignment")
                slot = TimeTableSlot.objects.create(timetable=instance, **slot_data)
                for b_data in batches_data:
                    TimeTableSlotBatch.objects.create(slot=slot, **b_data)

        return instance


# --- FACULTY SCHEDULE SERIALIZER (For "My Timetable" List) ---
class FacultyScheduleSerializer(serializers.ModelSerializer):
    subject_name = serializers.SerializerMethodField(read_only=True)
    subject_code = serializers.SerializerMethodField(read_only=True)
    branch_name = serializers.SerializerMethodField(read_only=True)
    faculty_name = serializers.SerializerMethodField(read_only=True)
    faculty_employee_id = serializers.SerializerMethodField(read_only=True)
    semester = serializers.SerializerMethodField(read_only=True)
    academic_year = serializers.SerializerMethodField(read_only=True)
    academic_year_name = serializers.SerializerMethodField(read_only=True)
    is_batch_wise = serializers.BooleanField(read_only=True)
    batch_name = serializers.SerializerMethodField(read_only=True)
    lab_room = serializers.SerializerMethodField(read_only=True)
    batches = serializers.SerializerMethodField(read_only=True)
    assignment_info = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = TimeTableSlot
        fields = [
            "id", "day", "start_time", "end_time", 
            "subject_name", "subject_code", 
            "branch_name", "faculty_name", "faculty_employee_id", "semester",
            "academic_year", "academic_year_name",
            "is_batch_wise", "batch_name", "lab_room", "batches", "assignment_info"
        ]

    def _get_faculty_batches(self, obj):
        faculty = self.context.get('faculty')
        all_batches = list(obj.batches.all())
        if not faculty:
            return all_batches
        faculty_batches = [b for b in all_batches if b.assignment and b.assignment.faculty_id == faculty.id]
        return faculty_batches if faculty_batches else all_batches

    def get_batches(self, obj):
        batches = self._get_faculty_batches(obj)
        return TimeTableSlotBatchSerializer(batches, many=True, context=self.context).data

    def get_subject_name(self, obj):
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].assignment and f_batches[0].assignment.subject:
                return f_batches[0].assignment.subject.subject_name
        if obj.assignment and obj.assignment.subject:
            return obj.assignment.subject.subject_name
        first_b = obj.batches.first()
        if first_b and first_b.assignment and first_b.assignment.subject:
            return first_b.assignment.subject.subject_name
        return ""

    def get_subject_code(self, obj):
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].assignment and f_batches[0].assignment.subject:
                return f_batches[0].assignment.subject.subject_code
        if obj.assignment and obj.assignment.subject:
            return obj.assignment.subject.subject_code
        first_b = obj.batches.first()
        if first_b and first_b.assignment and first_b.assignment.subject:
            return first_b.assignment.subject.subject_code
        return ""

    def get_faculty_employee_id(self, obj):
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].assignment and f_batches[0].assignment.faculty:
                return getattr(f_batches[0].assignment.faculty, "faculty_id", "")
        if obj.assignment and obj.assignment.faculty:
            return obj.assignment.faculty.faculty_id
        first_b = obj.batches.first()
        if first_b and first_b.assignment and first_b.assignment.faculty:
            return getattr(first_b.assignment.faculty, "faculty_id", "")
        return ""

    def get_batch_name(self, obj):
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches:
                names = [b.batch_name for b in f_batches if b.batch_name]
                return ", ".join(names) if names else "Batch Not Assigned"
        if obj.batch_name and obj.batch_name.strip():
            return obj.batch_name.strip()
        batches = list(obj.batches.all())
        if batches:
            names = [b.batch_name for b in batches if b.batch_name]
            return ", ".join(names) if names else "Batch Not Assigned"
        if obj.is_batch_wise:
            return "Batch Not Assigned"
        return ""

    def get_lab_room(self, obj):
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].lab_room:
                return f_batches[0].lab_room
        if obj.lab_room and obj.lab_room.strip():
            return obj.lab_room.strip()
        first_b = obj.batches.first()
        if first_b and first_b.lab_room:
            return first_b.lab_room
        return ""

    def get_branch_name(self, obj):
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].assignment and f_batches[0].assignment.subject and f_batches[0].assignment.subject.department:
                return f_batches[0].assignment.subject.department.name
        if obj.assignment and obj.assignment.subject and obj.assignment.subject.department:
            return obj.assignment.subject.department.name
        if obj.timetable and obj.timetable.department:
            return obj.timetable.department.name
        first_b = obj.batches.first()
        if first_b and first_b.assignment and first_b.assignment.subject and first_b.assignment.subject.department:
            return first_b.assignment.subject.department.name
        return ""

    def get_faculty_name(self, obj):
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].assignment and f_batches[0].assignment.faculty:
                return f_batches[0].assignment.faculty.name
        if obj.assignment and obj.assignment.faculty:
            return obj.assignment.faculty.name
        first_b = obj.batches.first()
        if first_b and first_b.assignment and first_b.assignment.faculty:
            return first_b.assignment.faculty.name
        return "Not Assigned"

    def get_semester(self, obj):
        if obj.timetable and obj.timetable.semester:
            return obj.timetable.semester.sem_number
        faculty = self.context.get('faculty')
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].assignment:
                sem = getattr(f_batches[0].assignment.semester, "sem_number", None) or getattr(getattr(f_batches[0].assignment.subject, "semester", None), "sem_number", None)
                if sem:
                    return sem
        a = obj.assignment
        if a:
            sem = getattr(a.semester, "sem_number", None) or getattr(getattr(a.subject, "semester", None), "sem_number", None)
            if sem:
                return sem
        first_b = obj.batches.first()
        if first_b and first_b.assignment:
            b_sem = getattr(first_b.assignment.semester, "sem_number", None) or getattr(getattr(first_b.assignment.subject, "semester", None), "sem_number", None)
            if b_sem:
                return b_sem
        return None

    def get_academic_year(self, obj):
        if obj.timetable and obj.timetable.academic_year:
            return obj.timetable.academic_year.year_name
        if obj.assignment and obj.assignment.academic_year:
            return obj.assignment.academic_year.year_name
        return None

    def get_academic_year_name(self, obj):
        return self.get_academic_year(obj)

    def get_assignment_info(self, obj):
        faculty = self.context.get('faculty')
        a = None
        if faculty and obj.is_batch_wise:
            f_batches = [b for b in obj.batches.all() if b.assignment and b.assignment.faculty_id == faculty.id]
            if f_batches and f_batches[0].assignment:
                a = f_batches[0].assignment
        if not a:
            a = obj.assignment
        if not a:
            first_b = obj.batches.first()
            if first_b and first_b.assignment:
                a = first_b.assignment
        if not a:
            return None
        subject = getattr(a, "subject", None)
        fac = getattr(a, "faculty", None)
        semester = getattr(a, "semester", None) or getattr(subject, "semester", None)
        academic_year = getattr(a, "academic_year", None)
        subject_dept = getattr(subject, "department", None)
        cohort_dept = getattr(a, "department", None)

        return {
            "id": a.id,
            "subject_code": getattr(subject, "subject_code", None),
            "subject_name": getattr(subject, "subject_name", None),
            "subject_department": getattr(subject_dept, "name", None),
            "student_department": getattr(cohort_dept, "name", None),
            "faculty_id": getattr(fac, "id", None),
            "faculty_name": getattr(fac, "name", "Unknown"), 
            "faculty_employee_id": getattr(fac, "faculty_id", ""),
            "faculty_role": getattr(fac, "role", ""),
            "semester": getattr(semester, "sem_number", None),
            "academic_year": getattr(academic_year, "year_name", None),
            "credits": getattr(subject, "credits", 4),
            "theory_hours": getattr(subject, "theory_hours", 3),
            "tutorial_hours": getattr(subject, "tutorial_hours", 0),
            "practical_hours": getattr(subject, "practical_hours", 0),
        }
