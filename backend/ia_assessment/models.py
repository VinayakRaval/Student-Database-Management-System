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
        ("Assignment", "Assignment"),
        ("Quiz", "Quiz"),
    ]

    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    faculty = models.ForeignKey(User, on_delete=models.CASCADE)

    ia_type = models.CharField(max_length=20, choices=IA_TYPE_CHOICES)
    ia_name = models.CharField(max_length=100)  # e.g., "Unit Test 1"
    max_marks = models.PositiveIntegerField()

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ia_test_setup'
        unique_together = ("subject", "ia_type", "ia_name")

    def __str__(self):
        return f"{self.subject.subject_code} - {self.ia_type} ({self.ia_name})"


# -----------------------------
# IA MARKS (STUDENT WISE)
# -----------------------------
class IAMark(models.Model):
    ia_test = models.ForeignKey(IATestSetup, on_delete=models.CASCADE, related_name="marks")
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    obtained_marks = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ia_mark'
        unique_together = ("ia_test", "student")

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
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ia_aggregate'
        unique_together = ("student", "subject")

    def __str__(self):
        return f"{self.student.usn} - {self.subject.subject_code} (Avg: {self.average_marks})"
