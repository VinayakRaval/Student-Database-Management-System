from django.db import models
from django.conf import settings
from academics.models import Semester

# Centralized inside this file (not imported)
EXAM_TYPE_CHOICES = [
    ('FRESH', 'Fresh'),
    ('RV', 'Revaluation'),
    ('MAKEUP', 'Makeup Exam'),
]

class ExternalResult(models.Model):

    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='uploaded_results'
    )

    semester = models.ForeignKey(
        Semester,
        on_delete=models.CASCADE,
        related_name='external_results'
    )

    STATUS_CHOICES = [
        ('SUBMITTED', 'Submitted for Review'),
        ('VERIFIED', 'Verified & Approved'),
        ('CORRECTION_REQUESTED', 'Correction Required'),
    ]

    exam_type = models.CharField(max_length=20, choices=EXAM_TYPE_CHOICES)
    pdf_file = models.FileField(upload_to='documents/external_results/', null=True, blank=True)
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='SUBMITTED')
    sgpa = models.DecimalField(max_digits=4, decimal_places=2, null=True, blank=True)
    credits_cleared = models.IntegerField(default=20)
    backlogs_count = models.IntegerField(default=0)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_results'
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    remarks = models.TextField(blank=True, null=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('student', 'semester', 'exam_type')
        ordering = ['-uploaded_at']
        verbose_name = "External Result"
        verbose_name_plural = "External Results"

    def __str__(self):
        return f"{self.student} — Sem {self.semester.sem_number} ({self.exam_type})"


class ChangeLog(models.Model):

    ACTION_CHOICES = [
        ('updated', 'Updated'),
        ('deleted', 'Deleted'),
    ]

    result = models.ForeignKey(
        ExternalResult,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='result_changelogs'
    )

    action_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='performed_changelogs'
    )

    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    timestamp = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = "Result Change Log"
        verbose_name_plural = "Result Change Logs"

    def __str__(self):
        user = self.action_by or "Unknown"
        return f"{self.get_action_display()} by {user} on {self.timestamp:%Y-%m-%d %H:%M}"
