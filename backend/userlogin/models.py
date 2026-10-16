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

    def get_full_name(self):
        try:
            if hasattr(self, 'student') and self.student and self.student.name:
                return self.student.name
        except Exception:
            pass
        try:
            if hasattr(self, 'faculty_profile') and self.faculty_profile and self.faculty_profile.name:
                return self.faculty_profile.name
        except Exception:
            pass
        role_names = {
            'LIBRARY': 'Library Officer',
            'HOD': 'Head of Department',
            'PRINCIPAL': 'College Principal',
            'ADMISSION': 'Admission Officer',
            'EXAM': 'Exam Controller',
            'ACCOUNTS': 'Accounts Officer',
            'SCHOLARSHIP': 'Scholarship Officer',
            'SYSTEM': 'System Administrator',
        }
        if self.role in role_names:
            return role_names[self.role]
        return self.user_id or (self.email.split('@')[0] if self.email else f"User {self.pk}")

    def get_short_name(self):
        return self.get_full_name()

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


class RegistrationOTP(models.Model):
    """
    Stores 6-digit OTPs sent during prospective student registration.
    """
    email = models.EmailField(db_index=True)
    otp = models.CharField(max_length=6)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "registration_otp"
        indexes = [
            models.Index(fields=["email", "created_at"]),
        ]

    def is_expired(self):
        return timezone.now() > self.created_at + timedelta(minutes=10)

    def __str__(self):
        return f"Registration OTP for {self.email} ({'verified' if self.is_verified else 'unverified'})"



class AccountInvitation(models.Model):
    """
    Secure password-setup and password-reset invitation tokens for Students and Faculty.
    Stores a cryptographic SHA-256 hash of the token, never the plaintext token itself.
    """
    TYPE_INITIAL_SETUP = 'INITIAL_SETUP'
    TYPE_PASSWORD_RESET = 'PASSWORD_RESET'
    TYPE_CHOICES = [
        (TYPE_INITIAL_SETUP, 'Initial Password Setup'),
        (TYPE_PASSWORD_RESET, 'Password Reset'),
    ]

    STATUS_PENDING = 'PENDING'
    STATUS_SENT = 'SENT'
    STATUS_ACCEPTED = 'ACCEPTED'
    STATUS_EXPIRED = 'EXPIRED'
    STATUS_REVOKED = 'REVOKED'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_SENT, 'Sent'),
        (STATUS_ACCEPTED, 'Accepted'),
        (STATUS_EXPIRED, 'Expired'),
        (STATUS_REVOKED, 'Revoked'),
    ]

    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="account_invitations")
    token_hash = models.CharField(max_length=64, unique=True, db_index=True)
    invitation_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_INITIAL_SETUP)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)

    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    created_by = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True, related_name="created_invitations")
    delivery_error = models.TextField(blank=True, default='')

    class Meta:
        db_table = "account_invitation"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=["user", "status"]),
            models.Index(fields=["token_hash"]),
        ]

    def __str__(self):
        return f"{self.invitation_type} for {self.user.email} [{self.status}]"

    def is_valid(self):
        return self.status in [self.STATUS_PENDING, self.STATUS_SENT] and timezone.now() < self.expires_at

    @classmethod
    def hash_token(cls, raw_token: str) -> str:
        import hashlib
        return hashlib.sha256(raw_token.strip().encode('utf-8')).hexdigest()

    @classmethod
    def create_invitation(cls, user, created_by=None, invitation_type=TYPE_INITIAL_SETUP, expiry_hours=24):
        """
        Generates a cryptographically secure token, hashes it, revokes prior active invitations,
        and saves a new AccountInvitation. Returns (invitation_instance, raw_token).
        """
        import secrets
        # Revoke existing pending/sent invitations for this user and type
        cls.objects.filter(
            user=user,
            invitation_type=invitation_type,
            status__in=[cls.STATUS_PENDING, cls.STATUS_SENT]
        ).update(status=cls.STATUS_REVOKED)

        raw_token = secrets.token_urlsafe(32)
        token_hash = cls.hash_token(raw_token)
        expires_at = timezone.now() + timedelta(hours=expiry_hours)

        invitation = cls.objects.create(
            user=user,
            token_hash=token_hash,
            invitation_type=invitation_type,
            status=cls.STATUS_SENT,
            expires_at=expires_at,
            created_by=created_by
        )
        return invitation, raw_token

    @classmethod
    def verify_token(cls, raw_token: str):
        """
        Validates raw token against stored hash. Returns (is_valid, invitation_or_None, error_str).
        """
        if not raw_token or not raw_token.strip():
            return False, None, "Token parameter is missing."

        token_hash = cls.hash_token(raw_token)
        invitation = cls.objects.filter(token_hash=token_hash).select_related('user', 'user__department').first()
        if not invitation:
            return False, None, "Invalid or unrecognized setup link."

        if invitation.status == cls.STATUS_ACCEPTED:
            return False, invitation, "This password setup link has already been used."

        if invitation.status == cls.STATUS_REVOKED:
            return False, invitation, "This invitation link was superseded by a newer link. Please check your latest email."

        if timezone.now() > invitation.expires_at or invitation.status == cls.STATUS_EXPIRED:
            if invitation.status != cls.STATUS_EXPIRED:
                invitation.status = cls.STATUS_EXPIRED
                invitation.save(update_fields=['status'])
            return False, invitation, "This password setup link has expired. Please request a new invitation."

        return True, invitation, None

    def accept(self, new_password: str):
        """
        Applies new password, activates user, clears force_password_change,
        marks invitation ACCEPTED, and revokes sibling invitations.
        """
        user = self.user
        user.set_password(new_password)
        user.is_active = True
        user.force_password_change = False
        user.save()

        self.status = self.STATUS_ACCEPTED
        self.used_at = timezone.now()
        self.save(update_fields=['status', 'used_at'])

        # Invalidate any other pending tokens
        AccountInvitation.objects.filter(
            user=user,
            status__in=[AccountInvitation.STATUS_PENDING, AccountInvitation.STATUS_SENT]
        ).exclude(id=self.id).update(status=AccountInvitation.STATUS_REVOKED)
