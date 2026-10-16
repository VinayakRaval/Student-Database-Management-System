import logging
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from django.utils import timezone
from django.conf import settings

from .models import Faculty
from userlogin.models import CustomUser, AccountInvitation
from userlogin.email_service import send_password_setup_invitation

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
    if role_upper == "FACULTY":
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
    if not user:
        user = CustomUser.objects.create_user(
            email=instance.email,
            phone=instance.phone,
            user_id=instance.faculty_id,
            password=None,  # Unusable password until secure initial setup
            role=role_upper,
            department=instance.department,
            force_password_change=True,
            is_active=False,  # Activated upon token setup
            is_staff=True if role_upper in ["PRINCIPAL", "SYSTEM"] else False,
        )
        user_created = True
    else:
        user.email = instance.email
        user.phone = instance.phone
        user.department = instance.department
        user.role = role_upper
        if role_upper in ["PRINCIPAL", "SYSTEM"]:
            user.is_staff = True
        user.save()

    if instance.user_id != user.id:
        Faculty.objects.filter(id=instance.id).update(user=user)

    # If this is a newly created user or a user that has not set their password, send setup invitation
    if user_created or not user.has_usable_password():
        try:
            invitation, raw_token = AccountInvitation.create_invitation(
                user=user,
                invitation_type=AccountInvitation.TYPE_INITIAL_SETUP,
                expiry_hours=24
            )

            send_password_setup_invitation(
                user=user,
                raw_token=raw_token,
                recipient_name=instance.name,
                id_value=instance.faculty_id,
                role=role_upper.title(),
                invitation_type=AccountInvitation.TYPE_INITIAL_SETUP,
                expiry_hours=24
            )
            logger.info(f"[FACULTY INVITATION DISPATCHED] Setup invitation sent to {instance.email}")
        except Exception as e:
            logger.error(f"[FACULTY INVITATION FAILED] Could not dispatch faculty setup invitation: {e}", exc_info=True)
