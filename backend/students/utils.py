from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import timezone
from django.conf import settings

def send_approval_email(student):
    subject = "Student Admission Approval - College Portal"
    from_email = settings.DEFAULT_FROM_EMAIL
    to = [student.email]

    context = {
        "student_name": student.name,
        "student_admission_id": student.admission_id,
        "password": student.temporary_password,
        "login_url": "https://your-app-login-url.com",
        "college_name": "Government Engineering College, Chamarajanagar",
        "year": timezone.now().year,
    }

    html_message = render_to_string("email/student_approval.html", context)

    msg = EmailMultiAlternatives(subject, "", from_email, to)
    msg.attach_alternative(html_message, "text/html")
    msg.send()
