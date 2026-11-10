import logging
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from django.utils import timezone
from django.conf import settings

from .models import Faculty
from userlogin.models import CustomUser, PasswordAuditLog
from userlogin.password_service import set_temporary_password_for_user

logger = logging.getLogger(__name__)


@receiver(pre_save, sender=Faculty)
def auto_approve_principal(sender, instance, **kwargs):
    """Automatically approves PRINCIPAL role."""
    try:
        if instance.role and instance.role.upper() == "PRINCIPAL":
            instance.status = "approved"
    except Exception:
        pass


@receiver(post_save, sender=Faculty)
def create_or_update_user_for_faculty(sender, instance, created, **kwargs):
    if instance.status != "approved":
        return

    if instance.approved_date is None:
        instance.approved_date = timezone.now()
        Faculty.objects.filter(id=instance.id).update(approved_date=instance.approved_date)

    role_upper = (instance.role or "PROFESSOR").upper()
    if role_upper in ["FACULTY", "GUEST", "GUEST_FACULTY", "GUEST FACULTY"] or instance.is_guest_faculty or instance.employment_type == "GUEST":
        role_upper = "PROFESSOR"

    # Ensure only one principal exists
    if role_upper == "PRINCIPAL":
        CustomUser.objects.filter(role="PRINCIPAL").exclude(id=instance.user_id).update(role=None)

    # Locate existing user by relation, user_id, or email
    user = instance.user
    if not user and instance.faculty_id:
        user = CustomUser.objects.filter(user_id=instance.faculty_id).first()
    if not user and instance.email:
        user = CustomUser.objects.filter(email=instance.email).first()

    user_created = False
    try:
        if not user:
            user = CustomUser.objects.create_user(
                email=instance.email,
                phone=instance.phone,
                user_id=instance.faculty_id,
                password=None,
                role=role_upper,
                department=instance.department,
                force_password_change=True,
                is_active=True,
                is_staff=True if role_upper in ["PRINCIPAL", "SYSTEM"] else False,
            )
            user_created = True
        else:
            user.email = instance.email
            user.phone = instance.phone
            user.department = instance.department
            user.role = role_upper
            user.is_active = True
            if role_upper in ["PRINCIPAL", "SYSTEM"]:
                user.is_staff = True
            user.save()

        if instance.user_id != user.id:
            Faculty.objects.filter(id=instance.id).update(user=user)
    except Exception as e:
        logger.error(f"[FACULTY USER SYNC ERROR] Could not sync user for faculty {instance.faculty_id}: {e}", exc_info=True)
        return

    # If this is a newly created user or a user without a usable password, generate initial temporary password
    if user_created or not user.has_usable_password():
        try:
            temp_pwd = set_temporary_password_for_user(
                user=user,
                actor=None,
                action=PasswordAuditLog.ACTION_INITIAL_CREATION
            )
            instance._temporary_password = temp_pwd
            instance.temp_password = temp_pwd
            Faculty.objects.filter(id=instance.id).update(temp_password=temp_pwd)
            logger.info(f"[FACULTY PASSWORD INITIALIZED] Initial credentials generated for {instance.faculty_id}")
        except Exception as e:
            logger.error(f"[FACULTY PASSWORD ERROR] Could not generate initial password for faculty: {e}", exc_info=True)
