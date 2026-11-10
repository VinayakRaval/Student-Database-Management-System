from django.db import models
from django.conf import settings
from faculty.models import Faculty  # adjust import as per your app layout
from academics.models import Department, Schema, Semester,  AcademicYear

class Subject(models.Model):
    schema = models.ForeignKey(Schema, on_delete=models.SET_NULL, null=True, blank=True)

    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE)
    subject_name = models.CharField(max_length=200)
    subject_code = models.CharField(max_length=50, null=True, blank=True)
    is_elective = models.BooleanField(default=False)
    offering_department = models.ForeignKey(
        Department,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='offered_elective_subjects'
    )
    has_theory = models.BooleanField(default=True)
    has_lab = models.BooleanField(default=False)
    subject_type = models.CharField(
        max_length=20,
        default="THEORY",
        choices=[
            ("THEORY", "Theory Only"),
            ("LAB", "Lab Only"),
            ("BOTH", "Both Theory and Lab"),
            ("PROJECT", "Project"),
        ],
    )
    parent_subject = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='component_subjects'
    )
    subject_group = models.CharField(max_length=50, null=True, blank=True, db_index=True)

    # Academic Details & Teaching Hours
    credits = models.PositiveIntegerField(default=4)
    theory_hours = models.PositiveIntegerField(default=3)
    tutorial_hours = models.PositiveIntegerField(default=0)
    practical_hours = models.PositiveIntegerField(default=0)
    practical_sessions = models.PositiveIntegerField(default=0)
    practical_duration_per_session = models.PositiveIntegerField(default=0)
    total_teaching_hours = models.PositiveIntegerField(default=3)

    @property
    def practical_display(self):
        if self.practical_sessions > 0 and self.practical_duration_per_session > 0:
            return f"{self.practical_sessions} × {self.practical_duration_per_session}"
        if self.practical_hours > 0:
            return str(self.practical_hours)
        return "0"

    def get_offering_department(self):
        """
        Returns the Department that offers this elective subject.
        """
        if not self.is_elective:
            return self.department

        # 1. Direct offering_department field if set
        if self.offering_department_id:
            return self.offering_department

        # 2. Parent subject's department if different from home department
        if self.parent_subject and self.parent_subject.department_id != self.department_id:
            return self.parent_subject.department

        # 3. Master / parent subject with the same subject_code in another department
        if self.subject_code:
            other = Subject.objects.filter(
                subject_code__iexact=self.subject_code.strip()
            ).exclude(department_id=self.department_id).select_related('department').first()
            if other and other.department:
                return other.department

        # 4. Infer offering department from subject code prefix
        import re
        code_upper = (self.subject_code or "").upper().strip()
        dept_prefix_map = {
            "CV": ["Civil", "Civil Engineering"],
            "CIV": ["Civil", "Civil Engineering"],
            "CS": ["Computer Science", "Computer Science and Engineering", "CSE"],
            "EC": ["Electronics", "Electronics and Communication Engineering", "ECE"],
            "ME": ["Mechanical", "Mechanical Engineering"],
            "EE": ["Electrical", "Electrical and Electronics Engineering", "EEE"],
        }
        m = re.search(r'(?:[B0-9]{1,3})?([A-Z]{2,3})\d', code_upper)
        if m:
            prefix = m.group(1)
            patterns = dept_prefix_map.get(prefix, [prefix])
            for pat in patterns:
                d = Department.objects.filter(name__icontains=pat).first()
                if d and d.id != self.department_id:
                    return d

        return self.department

    def save(self, *args, **kwargs):
        if self.practical_sessions > 0 and self.practical_duration_per_session > 0 and (not self.practical_hours or self.practical_hours == 0):
            self.practical_hours = self.practical_sessions * self.practical_duration_per_session
        self.total_teaching_hours = (self.theory_hours or 0) + (self.tutorial_hours or 0) + (self.practical_hours or 0)
        if self.practical_sessions > 0 and self.practical_duration_per_session > 0 and (not self.practical_hours or self.practical_hours == 0):
            self.practical_hours = self.practical_sessions * self.practical_duration_per_session
        self.total_teaching_hours = (self.theory_hours or 0) + (self.tutorial_hours or 0) + (self.practical_hours or 0)

        if self.subject_type == "PROJECT":
            self.has_theory = False
            self.has_lab = False
            self.theory_hours = self.theory_hours or 0
            self.tutorial_hours = self.tutorial_hours or 0
            self.practical_hours = self.practical_hours or 0
            if not self.total_teaching_hours:
                self.total_teaching_hours = self.theory_hours + self.tutorial_hours + self.practical_hours
        elif self.has_theory and self.has_lab:
            self.subject_type = "BOTH"
        elif self.has_lab:
            self.subject_type = "LAB"
            self.has_theory = False
        else:
            self.subject_type = "THEORY"
            self.has_theory = True
            self.has_lab = False
        super().save(*args, **kwargs)

    def __str__(self):
        type_str = f" [{self.subject_type}]" if self.subject_type != "THEORY" else ""
        return f"{self.subject_code} - {self.subject_name}{type_str}"

    class Meta:
        db_table = 'subject'
        unique_together = ('department', 'semester', 'subject_code')
class SubjectAssignment(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE, null=True, blank=True)
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.CASCADE)
    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    semester = models.ForeignKey(Semester, null=True, blank=True, on_delete=models.CASCADE)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'subject_assignment'
        unique_together = ('subject', 'academic_year', 'department', 'semester')

    def clean(self):
        super().clean()
        if self.subject_id and self.academic_year_id and self.department_id:
            sem_id = self.semester_id or getattr(self.subject, 'semester_id', None)
            conflict = SubjectAssignment.objects.filter(
                subject_id=self.subject_id,
                academic_year_id=self.academic_year_id,
                department_id=self.department_id,
                semester_id=sem_id,
            )
            if self.pk:
                conflict = conflict.exclude(pk=self.pk)
            conflict_obj = conflict.first()
            if conflict_obj and conflict_obj.faculty_id != self.faculty_id:
                from django.core.exceptions import ValidationError
                raise ValidationError(
                    "This subject is already assigned to another faculty member for the selected department, semester, and academic year. Each subject can be assigned to only one faculty member per academic offering. Please select a different subject or update the existing assignment."
                )

    def save(self, *args, **kwargs):
        if not self.semester and self.subject and self.subject.semester:
            self.semester = self.subject.semester
        if not self.department and self.subject and self.subject.department:
            self.department = self.subject.department
        self.clean()
        super().save(*args, **kwargs)

    def __str__(self):
        faculty_name = self.faculty.name if self.faculty else "Unassigned"
        return f"{self.subject.subject_code} assigned to {faculty_name}"


class StudentWork(models.Model):
    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE, related_name="given_works", null=True, blank=True)
    created_by_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="created_works", null=True, blank=True)
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name="assigned_works")
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default="")
    work_image = models.ImageField(upload_to="student_works/", null=True, blank=True)
    due_date = models.DateField(null=True, blank=True)
    max_marks = models.PositiveIntegerField(default=10)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'student_work'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} ({self.subject.subject_code})"


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
