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

    # Permanent Marks Lock
    is_locked = models.BooleanField(default=False)
    locked_at = models.DateTimeField(null=True, blank=True)
    locked_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='locked_results'
    )

    class Meta:
        unique_together = ('student', 'semester', 'exam_type')
        ordering = ['-uploaded_at']
        verbose_name = "External Result"
        verbose_name_plural = "External Results"

    def save(self, *args, **kwargs):
        from django.core.exceptions import PermissionDenied
        if self.pk and not getattr(self, '_authorized_correction', False):
            orig = ExternalResult.objects.filter(pk=self.pk).first()
            if orig and orig.is_locked:
                update_fields = kwargs.get('update_fields')
                allowed = {'is_locked', 'locked_at', 'locked_by'}
                if not (update_fields and set(update_fields).issubset(allowed)):
                    raise PermissionDenied("Semester Completed – Examination results are permanently locked against modifications.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        from django.core.exceptions import PermissionDenied
        if self.is_locked and not getattr(self, '_authorized_correction', False):
            raise PermissionDenied("Semester Completed – Examination results are permanently locked against deletion.")
        super().delete(*args, **kwargs)

    def __str__(self):
        lock_str = " [LOCKED]" if self.is_locked else ""
        return f"{self.student} — Sem {self.semester.sem_number} ({self.exam_type}){lock_str}"



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
