"""
SDMS Email Service (Decommissioned)
Email delivery has been completely deactivated in SDMS.
Initial passwords and password resets are managed directly through authorized in-app interfaces.
All functions in this file are retained as safe no-op compatibility stubs.
"""
import logging

logger = logging.getLogger(__name__)


def validate_email_configuration():
    """Returns False indicating email service is deactivated."""
    return False, "EMAIL_DEACTIVATED", "Email service has been decommissioned. In-app password management is active."


def categorize_smtp_error(error):
    return "EMAIL_DEACTIVATED", "Email service is deactivated."


def get_default_from_email():
    return "SDMS <noreply@campusflow.edu>"


def send_email_message(*args, **kwargs):
    logger.info("[EMAIL DEACTIVATED] Suppressing email send attempt.")
    return False, "EMAIL_DEACTIVATED", "Email delivery deactivated in SDMS."


def send_password_setup_invitation(*args, **kwargs):
    logger.info("[EMAIL DEACTIVATED] Suppressing setup invitation email.")
    return None


def send_password_changed_notification(*args, **kwargs):
    logger.info("[EMAIL DEACTIVATED] Suppressing password changed notification.")
    return True


def send_registration_otp(*args, **kwargs):
    logger.info("[EMAIL DEACTIVATED] Suppressing registration OTP email.")
    return True


def send_faculty_credentials_email(*args, **kwargs):
    logger.info("[EMAIL DEACTIVATED] In-app password management active; email suppressed.")
    return True


def send_student_credentials_email(*args, **kwargs):
    logger.info("[EMAIL DEACTIVATED] In-app password management active; email suppressed.")
    return True
