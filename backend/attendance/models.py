from django.db import models
from django.utils import timezone
from django.contrib.auth.models import User
from students.models import Student
from faculty.models import Faculty
from subjects.models import Subject

# Attendance Sessions
class AttendanceSession(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE)
    date = models.DateField()
    session_count = models.IntegerField(default=1)
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        # Use the correct field name from your Subject model
        return f"{self.subject.subject_code} - {self.date} ({self.session_count})"
        # Or, if you want name: f"{self.subject.name} - {self.date} ({self.session_count})"


# Attendance Records

    class Meta:
        db_table = 'attendance_session'
class AttendanceRecord(models.Model):
    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, related_name="records")
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    status = models.CharField(max_length=10, choices=[("Present", "Present"), ("Absent", "Absent")])

    def __str__(self):
        # Use the correct field name in Subject and Student
        return f"{self.student.usn} - {self.session.subject.subject_code} ({self.status})"

    class Meta:
        db_table = 'attendance_record'


class AttendanceCorrectionRequest(models.Model):
    STATUS_CHOICES = [
        ("PENDING", "Pending"),
        ("APPROVED", "Approved"),
        ("REJECTED", "Rejected"),
    ]

    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, null=True, blank=True, related_name="correction_requests")
    record = models.ForeignKey(AttendanceRecord, on_delete=models.CASCADE, null=True, blank=True)
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE)
    requested_status = models.CharField(max_length=10, choices=[("Present", "Present"), ("Absent", "Absent")])
    reason = models.TextField()
    remarks = models.TextField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="PENDING")
    reviewed_by = models.ForeignKey('userlogin.CustomUser', on_delete=models.SET_NULL, null=True, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'attendance_correction_request'
        ordering = ['-created_at']

    def __str__(self):
        return f"Correction for {self.student.usn} ({self.requested_status}) - {self.status}"

