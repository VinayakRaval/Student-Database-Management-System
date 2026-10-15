from django.db import models
from django.contrib.auth.models import User
from students.models import Student
from faculty.models import Faculty
from subjects.models import Subject

# Attendance Sessions
class AttendanceSession(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE)
    date = models.DateField()
    session_count = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        # Use the correct field name from your Subject model
        return f"{self.subject.subject_code} - {self.date} ({self.session_count})"
        # Or, if you want name: f"{self.subject.name} - {self.date} ({self.session_count})"


# Attendance Records

    class Meta:
        db_table = 'attendance_session'
class AttendanceRecord(models.Model):
    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, related_name="records")
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    status = models.CharField(max_length=10, choices=[("Present", "Present"), ("Absent", "Absent")])

    def __str__(self):
        # Use the correct field name in Subject and Student
        return f"{self.student.usn} - {self.session.subject.subject_code} ({self.status})"

    class Meta:
        db_table = 'attendance_record'
