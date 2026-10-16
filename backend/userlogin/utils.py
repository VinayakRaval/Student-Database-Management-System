import random
from django.core.mail import send_mail
from .models import CustomUser
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives
from django.utils.html import strip_tags
from datetime import datetime

def generate_otp():
    """Generate a 6-digit OTP as string."""
    return "{:06d}".format(random.randint(0, 999999))

def get_user_by_identifier(identifier):
    """Fetch user by email, phone, user_id, usn, or admission_id."""
    user = None
    if not identifier:
        return None
    identifier = str(identifier).strip()
    if "@" in identifier:
        user = CustomUser.objects.filter(email__iexact=identifier).first()
    elif identifier.isdigit():
        user = CustomUser.objects.filter(phone__iexact=identifier).first()
        if not user:
            user = CustomUser.objects.filter(user_id__iexact=identifier).first()
        if not user:
            user = CustomUser.objects.filter(usn__iexact=identifier).first()
    else:
        user = CustomUser.objects.filter(user_id__iexact=identifier).first()
        if not user:
            user = CustomUser.objects.filter(usn__iexact=identifier).first()

    # Fallback to linked Student or Faculty profiles
    if not user:
        try:
            from students.models import Student
            stu = Student.objects.filter(usn__iexact=identifier).select_related('user').first()
            if not stu:
                stu = Student.objects.filter(admission_id__iexact=identifier).select_related('user').first()
            if stu and stu.user:
                user = stu.user
        except Exception:
            pass

    if not user:
        try:
            from faculty.models import Faculty
            fac = Faculty.objects.filter(faculty_id__iexact=identifier).select_related('user').first()
            if fac and fac.user:
                user = fac.user
        except Exception:
            pass

    return user



def send_otp_email(user, otp, subject="Password Reset Verification"):
    if not user or not user.email:
        return False

    context = {
        "OTP": otp,
        "YEAR": datetime.now().year,
        "USER": user
    }

    html_message = render_to_string("email/otp_template.html", context)
    plain_message = strip_tags(html_message)

    msg = EmailMultiAlternatives(
        subject=subject,
        body=plain_message,
        from_email="noreply@college.edu",
        to=[user.email],
    )

    msg.attach_alternative(html_message, "text/html")

    try:
        msg.send()
        return True
    except Exception as e:
        print("Email sending failed:", e)
        return False
