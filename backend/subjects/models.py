from django.db import models
from faculty.models import Faculty  # adjust import as per your app layout
from academics.models import Department, Schema, Semester,  AcademicYear

class Subject(models.Model):
    schema = models.ForeignKey(Schema, on_delete=models.SET_NULL, null=True, blank=True)

    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE)
    subject_name = models.CharField(max_length=200)
    subject_code = models.CharField(max_length=50, unique=True, null=True, blank=True)


    def __str__(self):
        return f"{self.subject_code} - {self.subject_name}"



    class Meta:
        db_table = 'subject'
class SubjectAssignment(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE)
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.CASCADE)
    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    semester = models.ForeignKey(Semester, null=True, blank=True, on_delete=models.CASCADE)


    class Meta:
        db_table = 'subject_assignment'
        unique_together = ('subject', 'faculty', 'academic_year',  'department','semester')

    def __str__(self):
        return f"{self.subject.subject_code} assigned to {self.faculty.name}"
