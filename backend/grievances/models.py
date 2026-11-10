from django.db import models
from django.conf import settings
from students.models import Student
from academics.models import Department
from userlogin.models import ROLE_CHOICES

User = settings.AUTH_USER_MODEL


class GrievanceCategory(models.Model):
    """
    Configurable grievance categories managed by System Admin or preloaded.
    """
    code = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True, default="")
    default_target_role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="HOD")
    sla_days = models.PositiveIntegerField(default=7, help_text="Target resolution time in days")
    is_confidential_by_default = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "grievance_category"
        ordering = ["name"]

    def __str__(self):
        return f"{self.name} ({self.code})"


class Grievance(models.Model):
    STATUS_CHOICES = [
        ("SUBMITTED", "Submitted"),
        ("UNDER_REVIEW", "Under Review"),
        ("IN_PROGRESS", "In Progress"),
        ("AWAITING_INFO", "Awaiting Information"),
        ("RESOLVED", "Resolved"),
        ("CLOSED", "Closed"),
        ("REJECTED", "Rejected"),
        ("ESCALATED", "Escalated"),
        ("REOPENED", "Reopened"),
        # Legacy status support
        ("Pending", "Pending"),
    ]

    PRIORITY_CHOICES = [
        ("LOW", "Low"),
        ("MEDIUM", "Medium"),
        ("HIGH", "High"),
        ("URGENT", "Urgent"),
    ]

    # Complainant
    submitted_by = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="submitted_grievances",
        null=True,
        blank=True,
    )
    student = models.ForeignKey(
        Student,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="grievances",
    )
    department = models.ForeignKey(
        Department,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="grievances",
    )

    # Classification & Content
    category = models.ForeignKey(
        GrievanceCategory,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="grievances",
    )
    category_name = models.CharField(max_length=100, default="Academic")
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default="MEDIUM")
    topic = models.CharField(max_length=255)
    description = models.TextField()
    attachment = models.FileField(upload_to="grievance_attachments/", null=True, blank=True)
    is_confidential = models.BooleanField(default=False)

    # Assignment & Target
    target_role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="HOD")
    target_user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_grievances",
    )

    # Status & Workflow
    status = models.CharField(max_length=25, choices=STATUS_CHOICES, default="SUBMITTED")
    response = models.TextField(blank=True, null=True)  # Legacy support
    resolution_remarks = models.TextField(blank=True, null=True)
    rejection_reason = models.TextField(blank=True, null=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolved_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="resolved_grievances",
    )
    closed_at = models.DateTimeField(null=True, blank=True)

    # Information Request
    info_requested_notes = models.TextField(blank=True, null=True)
    info_provided_notes = models.TextField(blank=True, null=True)

    # Escalation
    is_escalated = models.BooleanField(default=False)
    escalated_to = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="escalated_grievances",
    )
    escalated_at = models.DateTimeField(null=True, blank=True)
    escalation_reason = models.TextField(blank=True, null=True)

    # Reopening
    reopen_requested = models.BooleanField(default=False)
    reopen_request_reason = models.TextField(blank=True, null=True)
    reopen_requested_at = models.DateTimeField(null=True, blank=True)
    is_reopened = models.BooleanField(default=False)
    reopened_at = models.DateTimeField(null=True, blank=True)
    reopened_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reopened_grievances",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "grievance"
        ordering = ["-created_at"]

    def __str__(self):
        user_label = getattr(self.submitted_by, "email", None) or (
            getattr(self.student.user, "email", "Student") if self.student else "User"
        )
        target = self.target_user.email if self.target_user else self.target_role
        return f"[{self.status}] {self.topic} ({user_label} → {target})"


class GrievanceActivity(models.Model):
    """
    Audit log / timeline for every action taken on a grievance.
    """
    grievance = models.ForeignKey(
        Grievance,
        on_delete=models.CASCADE,
        related_name="activities",
    )
    actor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="grievance_activities",
    )
    action = models.CharField(max_length=50)
    from_status = models.CharField(max_length=25, blank=True, null=True)
    to_status = models.CharField(max_length=25, blank=True, null=True)
    notes = models.TextField(blank=True, default="")
    attachment = models.FileField(upload_to="grievance_activity_attachments/", null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "grievance_activity"
        ordering = ["created_at"]

    def __str__(self):
        actor_email = getattr(self.actor, "email", "System")
        return f"{self.action} on #{self.grievance_id} by {actor_email} at {self.created_at}"


class GrievanceAttachment(models.Model):
    """
    Supporting attachments uploaded during investigation or submission.
    """
    grievance = models.ForeignKey(
        Grievance,
        on_delete=models.CASCADE,
        related_name="attachments",
    )
    file = models.FileField(upload_to="grievance_documents/")
    file_name = models.CharField(max_length=255)
    file_size = models.PositiveIntegerField(default=0)
    uploaded_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "grievance_attachment"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.file_name} (#{self.grievance_id})"
