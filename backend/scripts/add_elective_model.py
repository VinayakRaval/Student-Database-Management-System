with open("subjects/models.py", "r", encoding="utf-8") as f:
    text = f.read()

elective_model = """

class ElectiveSubjectEnrollment(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name="elective_enrollments")
    student = models.ForeignKey('students.Student', on_delete=models.CASCADE, related_name="elective_enrollments")
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.CASCADE, null=True, blank=True)
    batch = models.CharField(max_length=50, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    enrolled_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'elective_subject_enrollment'
        unique_together = ('subject', 'student', 'academic_year')
        ordering = ['student__usn']

    def __str__(self):
        return f"{self.student.usn} -> {self.subject.subject_code} ({self.subject.subject_name})"
"""

if "class ElectiveSubjectEnrollment" not in text:
    text += elective_model
    with open("subjects/models.py", "w", encoding="utf-8") as f:
        f.write(text)
    print("ElectiveSubjectEnrollment added to subjects/models.py")
else:
    print("Already present.")
