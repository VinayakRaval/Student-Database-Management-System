from django.db import models
from django.contrib.auth import get_user_model
from academics.models import Department, Semester, AcademicYear
from encrypted_model_fields.fields import EncryptedTextField, EncryptedCharField, EncryptedEmailField

CustomUser = get_user_model()

GENDER_CHOICES = [('male', 'Male'), ('female', 'Female'), ('other', 'Other')]
STATUS_CHOICES = [('active', 'Active'), ('inactive', 'Inactive')]
SEAT_CHOICES = [('general_merit', 'General Merit (GM)'), ('snq', 'SNQ'),('lateral', 'Lateral')]

REGISTRATION_STATUS_CHOICES = [
    ('pending', 'Pending'),
    ('verified', 'Verified'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
]

class Student(models.Model):
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, null=True, blank=True)

    # Personal Info
    name = models.CharField(max_length=100)
    cet_no = models.CharField(max_length=50)
    dob = models.DateField()
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, blank=True, null=True)

    religion = EncryptedCharField(max_length=50)
    city_type = EncryptedCharField(max_length=50)
    mobile_no = EncryptedCharField(max_length=15)
    email = EncryptedEmailField(unique=True)
    father_name = EncryptedCharField(max_length=100, blank=True, null=True)
    mother_name = EncryptedCharField(max_length=100, blank=True, null=True)
    parent_occupation = EncryptedCharField(max_length=100)
    address = EncryptedTextField()
    permanent_address = EncryptedTextField()
    nationality = EncryptedCharField(max_length=50, blank=True, null=True)
    state = EncryptedCharField(max_length=50, blank=True, null=True)
    date_of_admission = models.DateField()

    seat_type = models.CharField(max_length=20,choices=SEAT_CHOICES)
    other_reservation = EncryptedCharField(max_length=50, blank=True, null=True)
    caste = EncryptedCharField(max_length=50, blank=True, null=True)

    # Academic relations
    department = models.ForeignKey(Department, on_delete=models.SET_NULL, null=True, blank=True, related_name="students")
    semester = models.ForeignKey(Semester, on_delete=models.SET_NULL, null=True, blank=True)
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.SET_NULL, null=True, blank=True)

    # Admission & status
    admission_id = models.CharField(max_length=20, unique=True, blank=True)
    usn = models.CharField(max_length=20, unique=True, blank=True, null=True)
    admission_quota = models.CharField(max_length=100, blank=True, null=True)
    rank = EncryptedCharField(max_length=20, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active', blank=True, null=True)
    registration_status = models.CharField(max_length=20, choices=REGISTRATION_STATUS_CHOICES, default='pending')

    # Marks & Documents
    sslc_regno = EncryptedCharField(max_length=50, blank=True, null=True)
    sslc_year = models.CharField(max_length=4, blank=True, null=True)
    sslc_obtain_marks = models.IntegerField(blank=True, null=True)
    sslc_total_marks = models.IntegerField(blank=True, null=True)
    sslc_marksheet = models.FileField(upload_to='documents/sslc/', null=True, blank=True)

    puc_regno = EncryptedCharField(max_length=50, blank=True, null=True)
    puc_year = models.CharField(max_length=4, blank=True, null=True)
    puc_obtain_marks = models.IntegerField(blank=True, null=True)
    puc_total_marks = models.IntegerField(blank=True, null=True)
    puc_marksheet = models.FileField(upload_to='documents/puc/', null=True, blank=True)

    diploma_regno = EncryptedCharField(max_length=50, blank=True, null=True)
    diploma_year = models.CharField(max_length=4, blank=True, null=True)
    diploma_obtain_marks = models.IntegerField(blank=True, null=True)
    diploma_total_marks = models.IntegerField(blank=True, null=True)
    diploma_marksheet = models.FileField(upload_to='documents/diploma/', null=True, blank=True)

    kannada_medium_certificate = models.FileField(upload_to='documents/certificates/', null=True, blank=True)
    hyderabad_karnataka_certificate = models.FileField(upload_to='documents/certificates/', null=True, blank=True)
    caste_certificate = models.FileField(upload_to='documents/certificates/', null=True, blank=True)
    kea_acknowledgement = models.FileField(upload_to='documents/kea/', null=True, blank=True)
    study_certificate = models.FileField(upload_to='documents/certificates/', null=True, blank=True)
    photo = models.ImageField(upload_to='photos/', null=True, blank=True)
    signature = models.ImageField(upload_to='signatures/', null=True, blank=True)
    temporary_password = models.CharField(max_length=50, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True, null=True, blank=True)

    def save(self, *args, **kwargs):
        if not self.admission_id:
            last_student = Student.objects.order_by('id').last()
            next_num = 1
            if last_student and last_student.admission_id:
                import re
                nums = re.findall(r'\d+', last_student.admission_id)
                if nums:
                    try:
                        next_num = int(nums[-1]) + 1
                    except ValueError:
                        next_num = (last_student.id or 0) + 1
            self.admission_id = f"GECC{next_num:06d}"
        super().save(*args, **kwargs)


    class Meta:
        db_table = 'student_details'

    def __str__(self):
        return f"{self.name} ({self.admission_id})"
