from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from django.utils import timezone
from django.template.loader import render_to_string  # <-- FIX
from django.core.mail import EmailMultiAlternatives  # <-- REQUIRED
from django.conf import settings  # <-- REQUIRED

from .models import Faculty
from userlogin.models import CustomUser
import secrets

@receiver(pre_save, sender=Faculty)
def auto_approve_principal(sender, instance, **kwargs):
    """Automatically approves PRINCIPAL role."""
    try:
        if instance.role and instance.role.upper() == "PRINCIPAL":
            instance.status = "approved"
    except:
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
    temp_password = None
    if not user:
        temp_password = secrets.token_urlsafe(8)
        user = CustomUser.objects.create_user(
            email=instance.email,
            phone=instance.phone,
            user_id=instance.faculty_id,
            password=temp_password,
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
        if role_upper in ["PRINCIPAL", "SYSTEM"]:
            user.is_staff = True
        user.is_active = True
        user.save()

    if instance.user_id != user.id:
        Faculty.objects.filter(id=instance.id).update(user=user)

    if user_created and temp_password:
        try:
            context = {
                "faculty_name": instance.name,
                "faculty_id": instance.faculty_id,
                "email": instance.email,
                "temp_password": temp_password,
                "role": role_upper.title(),
                "login_url": "https://your-faculty-login-url.com",
                "year": timezone.now().year,
            }

            html_content = render_to_string("email/faculty_approval.html", context)

            msg = EmailMultiAlternatives(
                subject="Faculty Account Approved - College Portal Access",
                body="",
                from_email=settings.DEFAULT_FROM_EMAIL,
                to=[instance.email]
            )
            msg.attach_alternative(html_content, "text/html")
            msg.send(fail_silently=True)

            print(f"[EMAIL SENT] Faculty ({instance.email}) login details delivered.")
        except Exception as e:
            print(f"[EMAIL WARNING] Could not send faculty email: {e}")

