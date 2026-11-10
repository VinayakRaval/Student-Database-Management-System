from django.db import models
from django.conf import settings
from academics.models import Department, Semester, AcademicYear
from subjects.models import SubjectAssignment

class TimeTable(models.Model):
    STATUS_CHOICES = [
        ("Draft", "Draft"),
        ("Pending", "Pending Approval"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
        ("Pending Reapproval", "Pending Reapproval"),
    ]

    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE)
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.PROTECT)

    version = models.PositiveIntegerField(default=1)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="timetable_created")
    created_at = models.DateTimeField(auto_now_add=True)

    status = models.CharField(max_length=32, choices=STATUS_CHOICES, default="Draft")
    is_active = models.BooleanField(default=False)

    approved_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="timetable_approved")
    approved_at = models.DateTimeField(null=True, blank=True)
    remarks = models.TextField(null=True, blank=True)
    effective_date = models.DateField(null=True, blank=True, verbose_name="W.E.F. Date")
    class_teacher = models.ForeignKey("faculty.Faculty", on_delete=models.SET_NULL, null=True, blank=True, related_name="class_timetables")

    class Meta:
        db_table = 'timetable'
        ordering = ("-created_at",)

    @property
    def institution_name(self):
        return getattr(settings, "INSTITUTION_NAME", "Government Engineering College, Chamarajanagara-571313")

    @property
    def semester_ordinal(self):
        sem = getattr(self.semester, "sem_number", 1)
        if 10 <= sem % 100 <= 20:
            suffix = 'th'
        else:
            suffix = {1: 'st', 2: 'nd', 3: 'rd'}.get(sem % 10, 'th')
        return f"{sem}{suffix}"

    @property
    def semester_type(self):
        sem = getattr(self.semester, "sem_number", 1)
        return "ODD SEM" if sem % 2 != 0 else "EVEN SEM"

    @property
    def formatted_title(self):
        ay_name = getattr(self.academic_year, "year_name", "Academic Year")
        import re
        match = re.match(r"^(\d{4})-(\d{4})$", str(ay_name).strip())
        if match:
            ay_name = f"{match.group(1)}-{match.group(2)[2:]}"
        return f"{self.semester_ordinal} Sem Time Table Academic Year {ay_name} ({self.semester_type})"

    @property
    def effective_date_formatted(self):
        if self.effective_date:
            return self.effective_date.strftime("%d/%m/%Y")
        return None

    def save(self, *args, **kwargs):
        # detect new instance
        creating = self.pk is None

        # Assign version only on creation
        if creating:
            latest = TimeTable.objects.filter(
                department=self.department,
                semester=self.semester,
                academic_year=self.academic_year
            ).order_by("-version").first()

            if latest:
                self.version = latest.version + 1

        # FIRST save
        super().save(*args, **kwargs)

        # Only deactivate others AFTER this timetable becomes Approved & Active
        if self.status == "Approved" and self.is_active:
            TimeTable.objects.filter(
                department=self.department,
                semester=self.semester,
                academic_year=self.academic_year,
                is_active=True
            ).exclude(pk=self.pk).update(is_active=False)

    def __str__(self):
        return f"{self.department.name} - Sem{self.semester.sem_number} - {self.academic_year.year_name} (v{self.version})"


class TimeTableSlot(models.Model):
    DAYS = [
        ("MON", "Monday"),
        ("TUE", "Tuesday"),
        ("WED", "Wednesday"),
        ("THU", "Thursday"),
        ("FRI", "Friday"),
        ("SAT", "Saturday"),
    ]

    timetable = models.ForeignKey(TimeTable, on_delete=models.CASCADE, related_name="slots")
    day = models.CharField(max_length=3, choices=DAYS)
    start_time = models.TimeField()
    end_time = models.TimeField()
    assignment = models.ForeignKey(SubjectAssignment, on_delete=models.CASCADE, related_name="timetable_slots", null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    # Optional batch-wise lab scheduling fields
    is_batch_wise = models.BooleanField(default=False)
    batch_name = models.CharField(max_length=50, blank=True, null=True)
    lab_room = models.CharField(max_length=100, blank=True, default="")
    allow_co_teaching = models.BooleanField(default=False)

    class Meta:
        db_table = 'timetable_slot'
        ordering = ("day", "start_time")

    def clean(self):
        if self.start_time >= self.end_time:
            raise ValueError("start_time must be before end_time")

    def __str__(self):
        subject_name = getattr(getattr(self.assignment, "subject", None), "subject_name", "Unknown Subject") if self.assignment else "Batch Lab"
        b_str = f" [Batch {self.batch_name}]" if self.batch_name else (" [Batch-wise]" if self.is_batch_wise else "")
        return f"{self.timetable} | {self.day} {self.start_time}-{self.end_time} | {subject_name}{b_str}"


class TimeTableSlotBatch(models.Model):
    slot = models.ForeignKey(TimeTableSlot, on_delete=models.CASCADE, related_name="batches")
    batch_name = models.CharField(max_length=50)  # e.g., "B1", "B2", "B3"
    assignment = models.ForeignKey(SubjectAssignment, on_delete=models.CASCADE, related_name="batch_timetable_slots")
    lab_room = models.CharField(max_length=100, blank=True, default="")
    start_time = models.TimeField(null=True, blank=True)
    end_time = models.TimeField(null=True, blank=True)
    allow_co_teaching = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'timetable_slot_batch'
        ordering = ['batch_name']

    def clean(self):
        s = self.start_time or (self.slot.start_time if self.slot_id else None)
        e = self.end_time or (self.slot.end_time if self.slot_id else None)
        if s and e and s >= e:
            raise ValueError("start_time must be before end_time")

    def __str__(self):
        subj = getattr(getattr(self.assignment, "subject", None), "subject_name", "Unknown") if self.assignment else "Unknown"
        return f"{self.slot} - Batch {self.batch_name} ({subj})"


class TimeTableApprovalHistory(models.Model):
    ACTION_CHOICES = [
        ("Approved", "Approved"),
        ("Rejected", "Rejected")
    ]

    timetable = models.ForeignKey(TimeTable, on_delete=models.CASCADE, related_name="approval_history")
    action = models.CharField(max_length=10, choices=ACTION_CHOICES)
    remarks = models.TextField(null=True, blank=True)
    action_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    action_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.timetable} {self.action} by {self.action_by} at {self.action_at}"

    class Meta:
        db_table = 'timetable_approval_history'


class SemesterClassTeacher(models.Model):
    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE)
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.CASCADE)
    faculty = models.ForeignKey("faculty.Faculty", on_delete=models.CASCADE, related_name="class_teacher_semesters")
    timetable = models.ForeignKey(TimeTable, on_delete=models.SET_NULL, null=True, blank=True, related_name="class_teacher_assignments")
    assigned_at = models.DateTimeField(auto_now=True)
    assigned_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        db_table = 'semester_class_teacher'
        unique_together = ('department', 'semester', 'academic_year')

    def __str__(self):
        return f"{self.department.name} Sem {self.semester.sem_number} ({self.academic_year.year_name}) - {self.faculty.name}"
