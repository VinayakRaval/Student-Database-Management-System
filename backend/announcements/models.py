from django.db import models
from django.conf import settings
from django.utils import timezone


class Announcement(models.Model):
    CATEGORY_CHOICES = [
        ("GENERAL", "General Notice"),
        ("TEST", "Internal Test"),
        ("EXAM", "Semester Exam"),
        ("TIMETABLE", "Timetable Change"),
        ("HOLIDAY", "Holiday"),
        ("EVENT", "College Event"),
    ]

    PRIORITY_CHOICES = [
        ("NORMAL", "Normal"),
        ("IMPORTANT", "Important"),
        ("URGENT", "Urgent"),
    ]

    title = models.CharField(max_length=255)
    content = models.TextField()
    category = models.CharField(max_length=100, default="GENERAL")
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default="NORMAL")

    image = models.ImageField(upload_to="announcements/images/", null=True, blank=True)
    attachment = models.FileField(upload_to="announcements/docs/", null=True, blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="created_announcements"
    )
    department = models.ForeignKey(
        "academics.Department",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        help_text="Null indicates a campus-wide announcement"
    )
    target_roles = models.JSONField(
        default=list,
        blank=True,
        help_text="List of roles e.g. ['ALL'], ['HOD', 'PROFESSOR', 'STUDENT']"
    )
    target_audience = models.CharField(
        max_length=20,
        choices=[("BOTH", "Both Faculty & Students"), ("STUDENTS", "Students Only"), ("FACULTY", "Faculty Only")],
        default="BOTH"
    )
    target_semester = models.ForeignKey(
        "academics.Semester",
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    academic_year = models.ForeignKey(
        "academics.AcademicYear",
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    publish_date = models.DateTimeField(default=timezone.now)
    expiry_date = models.DateTimeField(null=True, blank=True)
    is_published = models.BooleanField(default=True)
    is_archived = models.BooleanField(default=False)
    notify_users = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "announcement"
        ordering = ["-publish_date", "-created_at"]

    def __str__(self):
        return f"{self.title} ({self.category} - {self.priority})"


class Notification(models.Model):
    TYPE_CHOICES = [
        ("ANNOUNCEMENT", "Announcement"),
        ("ATTENDANCE", "Attendance Alert"),
        ("IA", "IA Assessment"),
        ("TIMETABLE", "Timetable"),
        ("GENERAL", "General Notification"),
    ]

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications"
    )
    announcement = models.ForeignKey(
        Announcement,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="notifications"
    )
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(max_length=50, choices=TYPE_CHOICES, default="ANNOUNCEMENT")
    
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notification"
        ordering = ["-created_at"]

    def __str__(self):
        return f"Notification for {self.recipient_id}: {self.title} (Read: {self.is_read})"
