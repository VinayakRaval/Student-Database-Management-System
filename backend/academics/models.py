
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
