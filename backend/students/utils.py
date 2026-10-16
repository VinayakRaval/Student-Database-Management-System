import logging
from django.utils import timezone
from django.conf import settings
from userlogin.models import AccountInvitation
from userlogin.email_service import send_password_setup_invitation

logger = logging.getLogger(__name__)


def send_approval_email(student, created_by=None):
    """
    Sends a secure password setup invitation to the approved student.
    Uses non-blocking asynchronous email delivery so requests return instantly.
    """
    if not student:
        return False

    user = student.user
    if not user:
        logger.warning(f"Student {student.id} has no linked user account.")
        return False

    # Create secure one-time setup invitation
    invitation, raw_token = AccountInvitation.create_invitation(
        user=user,
        created_by=created_by,
        invitation_type=AccountInvitation.TYPE_INITIAL_SETUP,
        expiry_hours=24
    )

    # Dispatch email asynchronously in background thread
    return send_password_setup_invitation(
        user=user,
        raw_token=raw_token,
        recipient_name=student.name,
        id_value=student.usn or student.admission_id,
        role="Student",
        invitation_type=AccountInvitation.TYPE_INITIAL_SETUP,
        expiry_hours=24
    )
