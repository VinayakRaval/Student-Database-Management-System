from django.db import models
from django.conf import settings
from students.models import Student
from userlogin.models import ROLE_CHOICES   # <-- Reuse existing roles

User = settings.AUTH_USER_MODEL


class Grievance(models.Model):

    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("In Progress", "In Progress"),
        ("Resolved", "Resolved"),
    ]

    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="grievances")
    topic = models.CharField(max_length=255)
    description = models.TextField()

    # Reused from CustomUser
    target_role = models.CharField(max_length=20, choices=ROLE_CHOICES)

    target_user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_grievances",
    )

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="Pending")
    response = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        student_name = getattr(self.student.user, "email", "Unknown Student")
        target = self.target_user.email if self.target_user else self.target_role
        return f"{self.topic} ({student_name} → {target})"
