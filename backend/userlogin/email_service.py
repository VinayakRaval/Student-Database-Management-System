import logging
import threading
from concurrent.futures import ThreadPoolExecutor
from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.utils import timezone

logger = logging.getLogger(__name__)

# Background thread pool for non-blocking email dispatch
_EMAIL_EXECUTOR = ThreadPoolExecutor(max_workers=4, thread_name_prefix="email_worker")


def _send_email_worker(subject, to_email, html_content, text_content=None, from_email=None):
    """Worker executed in background thread pool to send email without blocking the HTTP request."""
    try:
        from_email = from_email or getattr(settings, 'DEFAULT_FROM_EMAIL', None) or getattr(settings, 'EMAIL_HOST_USER', 'noreply@sdms.edu')
        if not text_content:
            text_content = strip_tags(html_content)

        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=from_email,
            to=[to_email] if isinstance(to_email, str) else list(to_email)
        )
        msg.attach_alternative(html_content, "text/html")
        msg.send(fail_silently=False)
        logger.info(f"[EMAIL DISPATCHED] Subject: '{subject}' -> Recipient: {to_email}")
    except Exception as e:
        logger.error(f"[EMAIL FAILED] Could not send email to {to_email}: {e}", exc_info=True)


def send_async_email(subject, to_email, html_content, text_content=None, from_email=None):
    """
    Dispatches email asynchronously in a background thread.
    Returns immediately (< 2ms) so the API response is instantaneous.
    """
    if not to_email:
        logger.warning("Attempted to send email with empty recipient.")
        return False
    _EMAIL_EXECUTOR.submit(_send_email_worker, subject, to_email, html_content, text_content, from_email)
    return True


def get_frontend_base_url():
    """Returns the base frontend URL from settings or default localhost."""
    url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173')
    return url.rstrip('/')


def send_password_setup_invitation(user, raw_token, recipient_name=None, id_value=None, role=None, invitation_type='INITIAL_SETUP', expiry_hours=24):
    """
    Builds and sends a password setup or reset invitation email asynchronously.
    """
    if not user or not user.email:
        logger.warning(f"User {user} has no email; cannot send setup invitation.")
        return False

    name = recipient_name or user.get_full_name() or "User"
    role_name = role or getattr(user, 'role', 'Student')
    dept_name = user.department.name if getattr(user, 'department', None) else "College of Engineering"
    id_display = id_value or getattr(user, 'usn', None) or getattr(user, 'user_id', None) or user.email

    frontend_base = get_frontend_base_url()
    # Format link for Flutter Web / Hash router / Path router
    setup_url = f"{frontend_base}/#/setup-password?token={raw_token}"

    is_reset = invitation_type == 'PASSWORD_RESET'
    subject = "Reset Your SDMS Account Password" if is_reset else f"SDMS Account Activation & Password Setup — {name}"

    context = {
        "recipient_name": name,
        "role_name": role_name,
        "department_name": dept_name,
        "id_value": id_display,
        "email": user.email,
        "setup_url": setup_url,
        "expiry_hours": expiry_hours,
        "is_reset": is_reset,
        "college_name": "Government Engineering College, Chamarajanagar",
        "year": timezone.now().year,
    }

    try:
        html_content = render_to_string("email/password_setup_invitation.html", context)
    except Exception as e:
        logger.error(f"Error rendering setup template: {e}. Falling back to default.")
        action_text = "reset your password" if is_reset else "set up your new account password"
        html_content = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
            <h2 style="color: #0d2158;">SDMS Portal Access</h2>
            <p>Dear <strong>{name}</strong>,</p>
            <p>Please click the secure button below to {action_text}. This link is valid for {expiry_hours} hours.</p>
            <p style="text-align: center; margin: 30px 0;">
                <a href="{setup_url}" style="background-color: #0d2158; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                    Set Up Password
                </a>
            </p>
            <p>Or paste this link into your browser: <br><a href="{setup_url}">{setup_url}</a></p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">
            <p style="font-size: 12px; color: #64748b;">Government Engineering College, Chamarajanagar</p>
        </div>
        """

    # Print token directly to console for instant local development/testing without opening email client
    print(f"\n=======================================================")
    print(f"[PASSWORD SETUP LINK GENERATED]")
    print(f"   Recipient: {user.email} ({name} - {role_name})")
    print(f"   Setup URL: {setup_url}")
    print(f"   Raw Token: {raw_token}")
    print(f"   Expires:   In {expiry_hours} hours")
    print(f"=======================================================\n")

    return send_async_email(subject, user.email, html_content)


def send_password_changed_notification(user):
    """Sends notification that account password was successfully updated."""
    if not user or not user.email:
        return False

    name = user.get_full_name() or "User"
    frontend_base = get_frontend_base_url()
    login_url = f"{frontend_base}/#/login"

    subject = "Security Notice: Your SDMS Password Was Successfully Updated"
    html_content = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
        <h2 style="color: #0d2158;">Password Changed Successfully</h2>
        <p>Dear <strong>{name}</strong>,</p>
        <p>This is to confirm that the password for your SDMS account (<strong>{user.email}</strong>) was successfully updated on {timezone.now().strftime('%d %B %Y at %I:%M %p')}.</p>
        <p>You may now log in to the portal using your new password.</p>
        <p style="margin: 25px 0;">
            <a href="{login_url}" style="background-color: #059669; color: #ffffff; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                Log In to SDMS Portal
            </a>
        </p>
        <p style="color: #dc2626; font-size: 13px;">If you did not perform this action, please contact your Head of Department or System Administrator immediately.</p>
        <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">
        <p style="font-size: 12px; color: #64748b;">Government Engineering College, Chamarajanagar</p>
    </div>
    """

    return send_async_email(subject, user.email, html_content)


def send_registration_otp(email, otp):
    """
    Sends email verification OTP to prospective student during registration.
    Dispatches asynchronously and prints to server console for testing.
    """
    if not email:
        return False

    subject = f"Your SDMS Registration Verification Code: {otp}"
    html_content = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 25px; border: 1px solid #e2e8f0; border-radius: 8px;">
        <h2 style="color: #0d2158; margin-top: 0;">SDMS Student Registration</h2>
        <p>Hello,</p>
        <p>Thank you for initiating your admission registration at <strong>Government Engineering College, Chamarajanagar</strong>.</p>
        <p>Your one-time email verification code is:</p>
        <div style="text-align: center; margin: 30px 0;">
            <div style="display: inline-block; background-color: #f1f5f9; border: 2px dashed #0d2158; padding: 15px 35px; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #0d2158; border-radius: 8px;">
                {otp}
            </div>
        </div>
        <p style="color: #475569; font-size: 14px;">This code is valid for <strong>10 minutes</strong>. Please do not share this OTP with anyone.</p>
        <p style="color: #64748b; font-size: 13px;">If you did not request this verification, please disregard this email.</p>
        <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;">
        <p style="font-size: 12px; color: #94a3b8; margin-bottom: 0;">Government Engineering College, Chamarajanagar &bull; Student Data Management System</p>
    </div>
    """

    print(f"\n=======================================================")
    print(f"[REGISTRATION OTP GENERATED]")
    print(f"   Recipient: {email}")
    print(f"   OTP Code:  {otp}")
    print(f"   Valid For: 10 minutes")
    print(f"=======================================================\n")

    return send_async_email(subject, email, html_content)

