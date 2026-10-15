from django.db import models
from django.conf import settings
from academics.models import Department, Semester,  AcademicYear
from subjects.models import SubjectAssignment

class TimeTable(models.Model):
    STATUS_CHOICES = [
        ("Draft", "Draft"),
        ("Pending", "Pending Approval"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
    ]

    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE)
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.PROTECT)

    version = models.PositiveIntegerField(default=1)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="timetable_created")
    created_at = models.DateTimeField(auto_now_add=True)

    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default="Draft")
    is_active = models.BooleanField(default=False)

    approved_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="timetable_approved")
    approved_at = models.DateTimeField(null=True, blank=True)
    remarks = models.TextField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)

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
    assignment = models.ForeignKey(SubjectAssignment, on_delete=models.CASCADE, related_name="timetable_slots")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("timetable", "day", "start_time", "end_time", "assignment")

    def clean(self):
        if self.start_time >= self.end_time:
            raise ValueError("start_time must be before end_time")

    def __str__(self):
        # Use 'subject_name' instead of 'name'
        subject_name = getattr(self.assignment.subject, "subject_name", "Unknown Subject")
        return f"{self.timetable} | {self.day} {self.start_time}-{self.end_time} | {subject_name}"


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
