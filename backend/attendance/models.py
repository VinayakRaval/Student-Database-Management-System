from django.db import models
from django.utils import timezone
from students.models import Student
from faculty.models import Faculty
from subjects.models import Subject
from academics.models import Department, Semester, AcademicYear


# ==========================================
# LAB BATCH MANAGEMENT
# ==========================================
def get_department_code(dept):
    if not dept:
        return ""
    name = getattr(dept, "name", str(dept)).strip()
    name_upper = name.upper()
    if "COMPUTER" in name_upper or "CSE" in name_upper:
        return "CSE"
    if "ELECTRONIC" in name_upper or "ECE" in name_upper:
        return "ECE"
    if "MECHANICAL" in name_upper or "MECH" in name_upper:
        return "ME"
    if "CIVIL" in name_upper:
        return "CIVIL"
    words = [w[0].upper() for w in name.split() if w.lower() not in ["and", "of", "the", "&"]]
    return "".join(words) if words else name


class LabBatch(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.SET_NULL, null=True, blank=True, related_name="lab_batches")
    department = models.ForeignKey(Department, on_delete=models.SET_NULL, null=True, blank=True)
    semester = models.ForeignKey(Semester, on_delete=models.SET_NULL, null=True, blank=True)
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.SET_NULL, null=True, blank=True)
    faculty = models.ForeignKey(Faculty, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_lab_batches")
    name = models.CharField(max_length=50)  # e.g. "Batch A", "Batch B", "Batch C", "Batch D"
    created_by = models.ForeignKey('userlogin.CustomUser', on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'lab_batch'
        ordering = ['name']

    @property
    def identifier(self):
        dept_code = get_department_code(self.department) or (self.department.name if self.department else "")
        ay_str = self.academic_year.year_name if self.academic_year else ""
        sem_str = f"Semester {self.semester.sem_number}" if self.semester else ""
        parts = [p for p in [dept_code, ay_str, sem_str, self.name] if p]
        return " – ".join(parts)

    def __str__(self):
        if self.department and self.semester and self.academic_year and not self.subject:
            return self.identifier
        dept_sem = f"{self.department.name if self.department else ''} Sem {self.semester.sem_number if self.semester else ''}".strip()
        sub_code = self.subject.subject_code if self.subject else ""
        if sub_code:
            return f"{sub_code} - {self.name}"
        return f"{dept_sem} - {self.name}" if dept_sem else self.name


class LabBatchStudent(models.Model):
    batch = models.ForeignKey(LabBatch, on_delete=models.CASCADE, related_name="batch_students")
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="lab_batch_assignments")
    assigned_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'lab_batch_student'
        unique_together = ('batch', 'student')

    def __str__(self):
        sub_code = self.batch.subject.subject_code if (self.batch and self.batch.subject) else "Lab"
        return f"{self.student.usn} in {self.batch.name} ({sub_code})"


# ==========================================
# EXTRA CLASS SESSION MANAGEMENT
# ==========================================
class ExtraClassSession(models.Model):
    STATUS_CHOICES = [
        ("PENDING", "Pending"),
        ("APPROVED", "Approved"),
        ("REJECTED", "Rejected"),
        ("COMPLETED", "Completed"),
        ("CANCELLED", "Cancelled"),
    ]
    SESSION_TYPE_CHOICES = [
        ("THEORY", "Theory"),
        ("LAB", "Lab"),
    ]

    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name="extra_classes")
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE, related_name="extra_classes")
    session_type = models.CharField(max_length=10, choices=SESSION_TYPE_CHOICES, default="THEORY")
    batch = models.ForeignKey(LabBatch, on_delete=models.SET_NULL, null=True, blank=True, related_name="extra_classes")
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    duration_minutes = models.PositiveIntegerField(default=60)
    room = models.CharField(max_length=50, blank=True, default="")
    reason = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="PENDING")

    reviewed_by = models.ForeignKey('userlogin.CustomUser', on_delete=models.SET_NULL, null=True, blank=True, related_name="reviewed_extra_classes")
    reviewed_at = models.DateTimeField(null=True, blank=True)
    remarks = models.TextField(blank=True, null=True)

    created_by = models.ForeignKey('userlogin.CustomUser', on_delete=models.SET_NULL, null=True, blank=True, related_name="created_extra_classes")
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'extra_class_session'
        ordering = ['-date', 'start_time']

    def __str__(self):
        batch_info = f" ({self.batch.name})" if self.batch else ""
        return f"Extra Class: {self.subject.subject_code}{batch_info} on {self.date} [{self.status}]"


# ==========================================
# ATTENDANCE SESSIONS & RECORDS
# ==========================================
class AttendanceSession(models.Model):
    SESSION_TYPE_CHOICES = [
        ("THEORY", "Theory"),
        ("LAB", "Lab"),
    ]

    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE)
    session_type = models.CharField(max_length=10, choices=SESSION_TYPE_CHOICES, default="THEORY")
    batch = models.ForeignKey(LabBatch, on_delete=models.CASCADE, null=True, blank=True, related_name="sessions")
    extra_class = models.ForeignKey(ExtraClassSession, null=True, blank=True, on_delete=models.SET_NULL, related_name="attendance_sessions")
    start_time = models.TimeField(null=True, blank=True)
    end_time = models.TimeField(null=True, blank=True)
    date = models.DateField()
    session_count = models.IntegerField(default=1)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'attendance_session'
        constraints = [
            models.UniqueConstraint(
                fields=['subject', 'faculty', 'date'],
                condition=models.Q(session_type='THEORY', extra_class__isnull=True),
                name='unique_theory_session_per_subject_faculty_date'
            ),
            models.UniqueConstraint(
                fields=['subject', 'faculty', 'date', 'batch'],
                condition=models.Q(session_type='LAB', extra_class__isnull=True),
                name='unique_lab_session_per_subject_faculty_date_batch'
            ),
            models.UniqueConstraint(
                fields=['extra_class'],
                condition=models.Q(extra_class__isnull=False),
                name='unique_attendance_per_extra_class'
            ),
        ]

    def __str__(self):
        type_str = f"[{self.session_type}]"
        batch_str = f" ({self.batch.name})" if self.batch else ""
        extra_str = f" [Extra Class #{self.extra_class_id}]" if self.extra_class_id else ""
        return f"{self.subject.subject_code} {type_str}{batch_str}{extra_str} - {self.date} ({self.session_count})"


class AttendanceRecord(models.Model):
    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, related_name="records")
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    status = models.CharField(max_length=10, choices=[("Present", "Present"), ("Absent", "Absent")])

    class Meta:
        db_table = 'attendance_record'
        unique_together = ("session", "student")

    def __str__(self):
        return f"{self.student.usn} - {self.session.subject.subject_code} ({self.status})"


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
    is_self_approved = models.BooleanField(default=False)
    reviewed_by = models.ForeignKey('userlogin.CustomUser', on_delete=models.SET_NULL, null=True, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'attendance_correction_request'
        ordering = ['-created_at']

    def __str__(self):
        self_str = " (Self-Approved)" if self.is_self_approved else ""
        return f"Correction for {self.student.usn} ({self.requested_status}) - {self.status}{self_str}"


class AttendanceAuditLog(models.Model):
    user = models.ForeignKey('userlogin.CustomUser', on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=100)  # CREATE_BATCH, UPDATE_BATCH, SELF_APPROVE_ATTENDANCE, SELF_APPROVE_IA
    details = models.TextField()
    timestamp = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'attendance_audit_log'
        ordering = ['-timestamp']

    def __str__(self):
        user_str = self.user.email if self.user else "System"
        return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] {user_str} - {self.action}"
