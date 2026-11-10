from django.db import models, transaction
from django.conf import settings
from django.utils import timezone
from students.models import Student
from academics.models import Department
from userlogin.models import CustomUser

CATEGORY_CHOICES = [
    ('PERSONAL', 'Personal Details'),
    ('ADMISSION_USN', 'USN & Admission Records'),
    ('ATTENDANCE', 'Attendance'),
    ('IA_MARKS', 'IA Marks'),
    ('EXAM_RESULTS', 'External Examination Results'),
    ('FEES', 'Fees & Payments'),
    ('DOCUMENTS', 'Uploaded Documents'),
    ('LIBRARY', 'Library Records'),
    ('ACADEMIC', 'Subjects & Academic History'),
    ('ACCOUNT', 'Account Access'),
    ('OTHER', 'Other Discrepancies'),
]

STATUS_CHOICES = [
    ('SUBMITTED', 'Submitted'),
    ('PENDING_REVIEW', 'Pending Review'),
    ('MORE_INFO_REQUIRED', 'More Information Required'),
    ('FORWARDED', 'Forwarded to Reviewer'),
    ('APPROVED', 'Approved'),
    ('REJECTED', 'Rejected'),
    ('COMPLETED', 'Completed'),
]

ACTION_CHOICES = [
    ('SUBMITTED', 'Request Submitted'),
    ('REVIEWED', 'Request Under Review'),
    ('INFO_REQUESTED', 'Information Requested'),
    ('FORWARDED', 'Forwarded'),
    ('APPROVED', 'Approved'),
    ('REJECTED', 'Rejected'),
    ('RESOLVED', 'Correction Applied & Completed'),
]


def generate_correction_request_id():
    """
    Concurrency-safe generation of unique correction request IDs: CR-YYYY-XXXX
    """
    year = timezone.now().year
    prefix = f"CR-{year}-"
    with transaction.atomic():
        last_req = (
            CorrectionRequest.objects.select_for_update()
            .filter(request_id__startswith=prefix)
            .order_by('-id')
            .first()
        )
        if last_req and last_req.request_id:
            try:
                num = int(last_req.request_id.split('-')[-1]) + 1
            except Exception:
                num = CorrectionRequest.objects.count() + 1
        else:
            num = 1
        new_id = f"{prefix}{num:04d}"
        while CorrectionRequest.objects.filter(request_id=new_id).exists():
            num += 1
            new_id = f"{prefix}{num:04d}"
        return new_id


class CorrectionRequest(models.Model):
    request_id = models.CharField(max_length=30, unique=True, default=generate_correction_request_id)
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='correction_requests')
    category = models.CharField(max_length=40, choices=CATEGORY_CHOICES)
    target_record_ref = models.CharField(max_length=255, blank=True, help_text="e.g. Subject Code, Class Date, Receipt No, Document Name")
    current_value = models.TextField(blank=True, help_text="Current recorded value if known")
    requested_value = models.TextField(help_text="Requested correction or expected value")
    description = models.TextField(help_text="Detailed description of the mistake")
    reason = models.TextField(help_text="Reason for the correction request")
    evidence_file = models.FileField(upload_to='correction_evidence/', null=True, blank=True)
    
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='SUBMITTED')
    assigned_department = models.ForeignKey(Department, on_delete=models.SET_NULL, null=True, blank=True, related_name='correction_requests')
    assigned_role = models.CharField(max_length=50, blank=True, default='ADMISSION')
    assigned_to = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_corrections')
    
    reviewer_comments = models.TextField(blank=True, default='')
    rejection_reason = models.TextField(blank=True, default='')
    resolution_notes = models.TextField(blank=True, default='')
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'correction_request'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['student', 'status']),
            models.Index(fields=['assigned_department', 'status']),
            models.Index(fields=['category', 'status']),
        ]

    def __str__(self):
        return f"{self.request_id} [{self.category}] - {self.student.usn} ({self.status})"


class CorrectionRequestHistory(models.Model):
    request = models.ForeignKey(CorrectionRequest, on_delete=models.CASCADE, related_name='history')
    actor = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=40, choices=ACTION_CHOICES)
    from_status = models.CharField(max_length=30, blank=True)
    to_status = models.CharField(max_length=30, blank=True)
    comments = models.TextField(blank=True, default='')
    timestamp = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'correction_request_history'
        ordering = ['timestamp']

    def __str__(self):
        return f"{self.request.request_id}: {self.action} at {self.timestamp}"
