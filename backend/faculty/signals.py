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
        instance.save(update_fields=["approved_date"])

    # Ensure only one principal exists
    if instance.role and instance.role.upper() == "PRINCIPAL":
        CustomUser.objects.filter(role="PRINCIPAL").exclude(id=instance.user_id).update(role=None)

    user, user_created = CustomUser.objects.get_or_create(id=instance.user_id)

    if user_created:
        temp_password = secrets.token_urlsafe(8)
        user.set_password(temp_password)
        user.force_password_change = True
        user.save()

        context = {
            "faculty_name": instance.name,
            "faculty_id": instance.faculty_id,
            "email": instance.email,
            "temp_password": temp_password,
            "role": instance.role.title(),
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
        msg.send()

        print(f"[EMAIL SENT] Faculty ({instance.email}) login details delivered.")

    else:
        user.email = instance.email
        user.phone = instance.phone
        user.department = instance.department
        user.role = instance.role.upper()
        user.save()
