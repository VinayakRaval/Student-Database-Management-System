
from django.db import models


class TimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class Department(TimestampedModel):
    name = models.CharField(max_length=100, unique=True)

    class Meta:
        db_table = "department"
        verbose_name = "Department"
        verbose_name_plural = "Departments"

    def __str__(self):
        return self.name


class Semester(TimestampedModel):
    sem_number = models.IntegerField(default=1)

    class Meta:
        db_table = "semester"
        verbose_name = "Semester"
        verbose_name_plural = "Semesters"

    def __str__(self):
        return f"Semester {self.sem_number}"


class AcademicYear(TimestampedModel):
    year_name = models.CharField(max_length=20, unique=True)

    class Meta:
        db_table = "academic_year"
        verbose_name = "Academic Year"
        verbose_name_plural = "Academic Years"

    def __str__(self):
        return self.year_name


class Schema(TimestampedModel):
    name = models.CharField(max_length=100, unique=True)
    department = models.ForeignKey(
        Department,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="schemas",
    )

    class Meta:
        db_table = "schema"
        verbose_name = "Schema"
        verbose_name_plural = "Schemas"

    def __str__(self):
        return (
            f"{self.name} "
            f"({self.department.name if self.department else 'No Department'})"
        )


class SemesterFinalization(TimestampedModel):
    department = models.ForeignKey(
        Department,
        on_delete=models.CASCADE,
        related_name="finalized_semesters",
    )
    semester = models.ForeignKey(
        Semester,
        on_delete=models.CASCADE,
        related_name="finalized_semesters",
    )
    academic_year = models.ForeignKey(
        AcademicYear,
        on_delete=models.CASCADE,
        related_name="finalized_semesters",
    )
    is_finalized = models.BooleanField(default=False)
    finalized_at = models.DateTimeField(null=True, blank=True)
    finalized_by = models.ForeignKey(
        'userlogin.CustomUser',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="authorized_finalizations",
    )
    remarks = models.TextField(blank=True, null=True)

    class Meta:
        db_table = "semester_finalization"
        unique_together = ("department", "semester", "academic_year")
        verbose_name = "Semester Finalization"
        verbose_name_plural = "Semester Finalizations"

    def __str__(self):
        status = "FINALIZED" if self.is_finalized else "OPEN"
        return f"{self.department.name} - Sem {self.semester.sem_number} ({self.academic_year.year_name}) [{status}]"

