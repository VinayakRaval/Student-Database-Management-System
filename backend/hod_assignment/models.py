from django.db import models
from django.utils import timezone
from academics.models import Department
from faculty.models import Faculty

class HODAssignment(models.Model):
    faculty = models.ForeignKey(
        Faculty, on_delete=models.CASCADE, related_name="hod_assignments"
    )
    department = models.ForeignKey(
        Department, on_delete=models.CASCADE, related_name="hod_assignments"
    )
    assigned_date = models.DateField(auto_now_add=True)
    end_date = models.DateField(null=True, blank=True)

    def is_current(self):
        return self.end_date is None

    def __str__(self):
        status = "Current" if self.is_current() else "Previous"
        return f"{self.faculty.name} - {self.department.name} ({status})"
