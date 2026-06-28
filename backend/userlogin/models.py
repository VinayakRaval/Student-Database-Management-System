from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone
from datetime import timedelta


ROLE_CHOICES = [
    ('PRINCIPAL', 'Principal'),
    ('HOD', 'Head of Department'),
    ('PROFESSOR', 'professor'),
    ('STUDENT', 'Student'),
    ('ADMISSION', 'Admission'),
    ('EXAM', 'Exam'),
    ('LIBRARY', 'Library'),
    ('SCHOLARSHIP', 'Scholarship'),
    ('ACCOUNTS', 'Accounts'),
    ('SYSTEM', 'SystemAdmin'),
]


class CustomUserManager(BaseUserManager):
    def create_user(self, email=None, phone=None, user_id=None, password=None, role="STUDENT", **extra_fields):
        if not (email or phone or user_id):
            raise ValueError("Provide at least one credential (email, phone, or user_id)")
        email = self.normalize_email(email) if email else None
        user = self.model(email=email, phone=phone, user_id=user_id, role=role, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("Superuser must have an email")
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self.create_user(email=email, password=password, role="SYSTEM", **extra_fields)


class CustomUser(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True, null=True, blank=True)
    phone = models.CharField(max_length=15, unique=True, null=True, blank=True)
    user_id = models.CharField(max_length=50, unique=True, null=True, blank=True)

    # ✅ Re-add this field
    usn = models.CharField(max_length=20, unique=True, null=True, blank=True)

    # basic profile


    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="STUDENT",blank=True, null=True)

    # academic links (use string refs to avoid circular import problems)
    department = models.ForeignKey("academics.Department", on_delete=models.SET_NULL, null=True, blank=True, related_name="users")

    # flags
    force_password_change = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    date_joined = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = CustomUserManager()

    class Meta:
        db_table = "custom_user"

    def __str__(self):
        return self.email or self.phone or self.user_id or f"User-{self.pk}"

    def save(self, *args, **kwargs):
        if not self.pk:
            self.date_joined = timezone.now()
        super().save(*args, **kwargs)


class PasswordResetOTP(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="password_otps")
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "password_reset_otp"
        indexes = [
            models.Index(fields=["user", "created_at"]),
        ]

    def is_expired(self):
        return timezone.now() > self.created_at + timedelta(minutes=10)

    def __str__(self):
        return f"OTP for {self.user}"
