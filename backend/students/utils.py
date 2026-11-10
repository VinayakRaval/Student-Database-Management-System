import logging

logger = logging.getLogger(__name__)


def send_approval_email(student, created_by=None):
    """
    Deprecated email stub. Email delivery has been deactivated in SDMS.
    Initial passwords and resets are managed directly in-app.
    """
    logger.info(f"[DEPRECATED EMAIL STUB] Email deactivated. Initial password for student {getattr(student, 'id', None)} managed in-app.")
    return True
