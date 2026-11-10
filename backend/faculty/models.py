
from django.db import models
from encrypted_model_fields.fields import (
    EncryptedCharField,
    EncryptedEmailField,
    EncryptedTextField,
)
from academics.models import Department
from django.utils import timezone
from userlogin.models import CustomUser


GENDER_CHOICES = [
    ("male", "Male"),
    ("female", "Female"),
    ("other", "Other"),
]

ROLE_CHOICES = [
    ("PRINCIPAL", "Principal"),
    ("HOD", "Head of Department"),
    ("PROFESSOR", "Professor"),
    ("ADMISSION", "Admission"),
    ("EXAM", "Exam"),
    ("LIBRARY", "Library"),
    ("SCHOLARSHIP", "Scholarship"),
    ("ACCOUNTS", "Accounts"),
    ("SYSTEM", "SystemAdmin"),
]

STATUS_CHOICES = [
    ("pending_office", "Pending Office Verification"),
    ("pending_principal", "Pending Principal Approval"),
    ("approved", "Approved"),
    ("rejected", "Rejected"),
]


class Faculty(models.Model):
    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="faculty_profile",
        null=True,
        blank=True,
    )

    faculty_id = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=200)
    gender = models.CharField(
        max_length=10, choices=GENDER_CHOICES, null=True, blank=True
    )
    dob = models.DateField(null=True, blank=True)

    address = EncryptedTextField(null=True, blank=True)
    phone = EncryptedCharField(max_length=15, unique=True)
    email = EncryptedEmailField(unique=True)

    department = models.ForeignKey(
        Department,
        on_delete=models.CASCADE,
        related_name="faculties",
    )
    qualification = models.CharField(max_length=200, null=True, blank=True)
    role = models.CharField(
        max_length=50, choices=ROLE_CHOICES, null=True, blank=True
    )
    designation = models.CharField(
        max_length=150, null=True, blank=True, default="Professor"
    )

    photo = models.ImageField(upload_to="photos/", null=True, blank=True)
    signature = models.ImageField(upload_to="faculty_signatures/", null=True, blank=True)

    employment_type = models.CharField(
        max_length=50,
        choices=[
            ("PERMANENT", "Permanent"),
            ("GUEST", "Guest Faculty"),
        ],
        default="PERMANENT",
        null=True,
        blank=True,
    )
    is_guest_faculty = models.BooleanField(default=False)
    date_of_joining = models.DateField(null=True, blank=True)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending_office",
    )
    registration_date = models.DateTimeField(default=timezone.now)
    approved_date = models.DateTimeField(null=True, blank=True)
    temp_password = EncryptedCharField(max_length=128, null=True, blank=True)
    password_setup_completed_at = models.DateTimeField(null=True, blank=True)

    # Automatically populate the existing database timestamp columns.
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        if self.is_guest_faculty or self.employment_type == "GUEST" or (self.designation and "guest" in str(self.designation).lower()):
            self.employment_type = "GUEST"
            self.is_guest_faculty = True
            if not self.designation:
                self.designation = "Guest Faculty"
        else:
            self.employment_type = "PERMANENT"
            self.is_guest_faculty = False
            if not self.designation:
                self.designation = "Professor" 
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.faculty_id} - {self.name}"

    class Meta:
        db_table = "faculty"
