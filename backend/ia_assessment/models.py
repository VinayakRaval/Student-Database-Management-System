from django.db import models
from django.conf import settings
from students.models import Student
from subjects.models import Subject


User = settings.AUTH_USER_MODEL


# -----------------------------
# IA TEST SETUP
# -----------------------------
class IATestSetup(models.Model):
    IA_TYPE_CHOICES = [
        ("Test1", "Test1"),
        ("Test2", "Test2"),
        ("LabTest1", "Lab Test 1"),
        ("LabTest2", "Lab Test 2"),
        ("Assignment", "Assignment"),
        ("Quiz", "Quiz"),
        ("Presentation", "Presentation"),
        ("Custom", "Custom"),
    ]

    COMPONENT_CHOICES = [
        ("THEORY", "Theory"),
        ("LAB", "Lab"),
    ]

    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    faculty = models.ForeignKey(User, on_delete=models.CASCADE)

    ia_type = models.CharField(max_length=30, choices=IA_TYPE_CHOICES)
    ia_name = models.CharField(max_length=100)  # e.g., "Unit Test 1", "Lab Internal Assessment 1"
    component_type = models.CharField(max_length=10, choices=COMPONENT_CHOICES, default="THEORY")
    batch = models.ForeignKey('attendance.LabBatch', on_delete=models.SET_NULL, null=True, blank=True, related_name="ia_tests")
    max_marks = models.PositiveIntegerField()

    # Workflow & Scheduling Fields
    assessment_date = models.DateField(null=True, blank=True)
    submission_deadline = models.DateField(null=True, blank=True)
    instructions = models.TextField(blank=True, null=True)
    STATUS_CHOICES = [
        ("DRAFT", "Draft"),
        ("CONFIGURED", "Configured"),
        ("IN_PROGRESS", "In Progress"),
        ("SUBMITTED", "Submitted to HOD"),
        ("RETURNED", "Returned for Correction"),
        ("APPROVED", "Approved by HOD"),
        ("VERIFIED", "Verified / Approved by HOD"),
        ("PUBLISHED", "Published to Students"),
        ("LOCKED", "Locked"),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="DRAFT")
    hod_remarks = models.TextField(blank=True, null=True)
    submitted_at = models.DateTimeField(null=True, blank=True)
    submitted_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="submitted_ia_tests")
    returned_at = models.DateTimeField(null=True, blank=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    approved_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="approved_ia_tests")

    # Controlled Publication Fields
    is_published = models.BooleanField(default=False)
    published_at = models.DateTimeField(null=True, blank=True)
    published_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="published_ia_tests")

    # Permanent Marks Lock Fields
    is_locked = models.BooleanField(default=False)
    locked_at = models.DateTimeField(null=True, blank=True)
    locked_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="locked_ia_tests")
    lock_reason = models.CharField(max_length=255, blank=True, default="")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ia_test_setup'
        unique_together = ("subject", "ia_type", "ia_name")

    def clean(self):
        from django.core.exceptions import ValidationError
        if self.pk:
            orig = IATestSetup.objects.filter(pk=self.pk).first()
            if orig and orig.is_locked and not getattr(self, '_authorized_correction', False):
                raise ValidationError("Semester Completed – This IA Assessment is permanently locked. Configurations cannot be changed.")

    def save(self, *args, **kwargs):
        from django.core.exceptions import PermissionDenied
        if self.pk and not getattr(self, '_authorized_correction', False):
            orig = IATestSetup.objects.filter(pk=self.pk).first()
            if orig and orig.is_locked:
                update_fields = kwargs.get('update_fields')
                allowed_locking_fields = {
                    'is_locked', 'locked_at', 'locked_by', 'lock_reason', 'status',
                    'verified_at', 'hod_remarks', 'approved_by', 'submitted_by',
                    'submitted_at', 'returned_at', 'is_published', 'published_at',
                    'published_by', 'updated_at'
                }
                if not (update_fields and set(update_fields).issubset(allowed_locking_fields)):
                    raise PermissionDenied("Semester Completed – Marks Locked. Test setup cannot be modified.")
        if self.ia_type in ["LabTest1", "LabTest2"] or (self.batch is not None):
            self.component_type = "LAB"
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        from django.core.exceptions import PermissionDenied
        if self.is_locked and not getattr(self, '_authorized_correction', False):
            raise PermissionDenied("Semester Completed – Marks Locked. Finalized assessments cannot be deleted.")
        super().delete(*args, **kwargs)

    def __str__(self):
        comp = f"[{self.component_type}] " if self.component_type else ""
        batch_str = f" ({self.batch.name})" if self.batch else ""
        lock_str = " [LOCKED]" if self.is_locked else ""
        status_str = f" [{self.status}]" if self.status else ""
        return f"{comp}{self.subject.subject_code} - {self.ia_type} ({self.ia_name}){batch_str}{status_str}{lock_str}"


# -----------------------------
# IA MARKS (STUDENT WISE)
# -----------------------------
class IAMark(models.Model):
    MARK_STATUS_CHOICES = [
        ("DRAFT", "Draft"),
        ("SUBMITTED", "Submitted"),
    ]

    ia_test = models.ForeignKey(IATestSetup, on_delete=models.CASCADE, related_name="marks")
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    obtained_marks = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    is_absent = models.BooleanField(default=False)
    is_exempted = models.BooleanField(default=False)
    remarks = models.CharField(max_length=255, blank=True, null=True)
    status = models.CharField(max_length=20, choices=MARK_STATUS_CHOICES, default="DRAFT")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ia_mark'
        unique_together = ("ia_test", "student")

    def clean(self):
        from django.core.exceptions import ValidationError
        if self.ia_test.is_locked and not getattr(self, '_authorized_correction', False):
            raise ValidationError("Semester Completed – Marks Locked. Modifications, overwrites, or deletions are permanently rejected for all roles.")

    def save(self, *args, **kwargs):
        from django.core.exceptions import PermissionDenied
        if self.ia_test.is_locked and not getattr(self, '_authorized_correction', False):
            raise PermissionDenied("Semester Completed – Marks Locked. Student marks are permanently finalized.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        from django.core.exceptions import PermissionDenied
        if self.ia_test.is_locked and not getattr(self, '_authorized_correction', False):
            raise PermissionDenied("Semester Completed – Marks Locked. Deletions are permanently prohibited.")
        super().delete(*args, **kwargs)

    def __str__(self):
        return f"{self.student.usn} - {self.ia_test.ia_name} ({self.obtained_marks})"



# -----------------------------
# AGGREGATE / AVERAGE TABLE
# -----------------------------
class IAAggregate(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    total_marks = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    average_marks = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    final_ia_marks = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    max_marks = models.DecimalField(max_digits=5, decimal_places=2, default=30)
    calculation_method = models.CharField(max_length=150, default="Best 2 of 3 (Max 30)")
    breakdown = models.JSONField(default=dict, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ia_aggregate'
        unique_together = ("student", "subject")

    def __str__(self):
        return f"{self.student.usn} - {self.subject.subject_code} (Final IA: {self.final_ia_marks}/{self.max_marks})"


# -----------------------------
# CONFIGURABLE IA CALCULATION SCHEME
# -----------------------------
class IACalculationScheme(models.Model):
    SCHEME_TYPE_CHOICES = [
        ("BEST_OF_N", "Best N of Total Tests"),
        ("AVERAGE_ALL", "Average of All Tests"),
        ("WEIGHTED", "Weighted Components (Tests + Assignments + Quizzes)"),
        ("TOTAL", "Sum of All Assessments"),
    ]
    name = models.CharField(max_length=100, default="VTU Standard Best 2 of 3")
    scheme_type = models.CharField(max_length=20, choices=SCHEME_TYPE_CHOICES, default="BEST_OF_N")
    best_n = models.PositiveIntegerField(default=2)
    max_final_ia = models.DecimalField(max_digits=5, decimal_places=2, default=30.0)
    test_weightage = models.DecimalField(max_digits=5, decimal_places=2, default=100.0)
    assignment_weightage = models.DecimalField(max_digits=5, decimal_places=2, default=0.0)
    quiz_weightage = models.DecimalField(max_digits=5, decimal_places=2, default=0.0)
    rounding_rule = models.CharField(
        max_length=20,
        choices=[
            ("ROUND_HALF_UP", "Round to nearest (0.5 up)"),
            ("CEIL", "Round up to next integer"),
            ("EXACT", "Exact 2 decimals")
        ],
        default="ROUND_HALF_UP"
    )
    department = models.ForeignKey("academics.Department", on_delete=models.SET_NULL, null=True, blank=True)
    academic_year = models.ForeignKey("academics.AcademicYear", on_delete=models.SET_NULL, null=True, blank=True)
    semester = models.ForeignKey("academics.Semester", on_delete=models.SET_NULL, null=True, blank=True)
    subject = models.ForeignKey(Subject, on_delete=models.SET_NULL, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ia_calculation_scheme'
        ordering = ['-is_active', '-created_at']

    def __str__(self):
        return f"{self.name} ({self.scheme_type}, Max: {self.max_final_ia})"


# -----------------------------
# CONTROLLED MARKS CORRECTION WORKFLOW
# -----------------------------
class MarksCorrectionRequest(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending Review'),
        ('APPROVED', 'Approved & Applied'),
        ('REJECTED', 'Rejected'),
    ]

    ia_test = models.ForeignKey(IATestSetup, on_delete=models.CASCADE, related_name="correction_requests")
    mark = models.ForeignKey(IAMark, on_delete=models.CASCADE, related_name="correction_requests")
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    original_marks = models.DecimalField(max_digits=5, decimal_places=2)
    requested_marks = models.DecimalField(max_digits=5, decimal_places=2)
    reason = models.TextField()
    requested_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name="mark_corrections_requested")
    requested_at = models.DateTimeField(auto_now_add=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="mark_corrections_reviewed")
    reviewed_at = models.DateTimeField(null=True, blank=True)
    review_remarks = models.TextField(blank=True, null=True)

    class Meta:
        db_table = 'marks_correction_request'
        ordering = ['-requested_at']

    def __str__(self):
        return f"Correction for {self.student.usn} ({self.ia_test.ia_name}): {self.original_marks} -> {self.requested_marks} [{self.status}]"


# -----------------------------
# IMMUTABLE MARKS SECURITY AUDIT LOG
# -----------------------------
class MarksSecurityAuditLog(models.Model):
    EVENT_CHOICES = [
        ('SEMESTER_FINALIZED', 'Semester Finalized & Locked'),
        ('REJECTED_MODIFICATION_ATTEMPT', 'Rejected Modification Attempt'),
        ('CORRECTION_REQUESTED', 'Correction Requested'),
        ('CORRECTION_APPROVED', 'Correction Approved'),
        ('CORRECTION_REJECTED', 'Correction Rejected'),
        ('IA_TEST_SUBMITTED', 'IA Test Submitted to HOD'),
        ('IA_TEST_APPROVED', 'IA Test Approved by HOD'),
        ('IA_TEST_RETURNED', 'IA Test Returned for Correction'),
        ('IA_TEST_PUBLISHED', 'IA Marks Published to Students'),
    ]

    event_type = models.CharField(max_length=40, choices=EVENT_CHOICES)
    actor = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="marks_audit_actions")
    role = models.CharField(max_length=50, blank=True)
    subject = models.ForeignKey(Subject, on_delete=models.SET_NULL, null=True, blank=True)
    student = models.ForeignKey(Student, on_delete=models.SET_NULL, null=True, blank=True)
    ia_test = models.ForeignKey(IATestSetup, on_delete=models.SET_NULL, null=True, blank=True)
    before_value = models.CharField(max_length=100, blank=True, null=True)
    after_value = models.CharField(max_length=100, blank=True, null=True)
    reason = models.TextField(blank=True, null=True)
    details = models.TextField()
    ip_address = models.CharField(max_length=45, blank=True, null=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'marks_security_audit_log'
        ordering = ['-timestamp']

    def __str__(self):
        return f"[{self.event_type}] {self.timestamp} - {self.actor}: {self.details[:60]}"

