import logging
import secrets
import string
from django.utils import timezone
from userlogin.models import CustomUser, PasswordAuditLog, AccountInvitation

logger = logging.getLogger(__name__)


def generate_secure_temporary_password(length=12) -> str:
    """
    Generates a cryptographically secure, readable temporary password containing
    uppercase letters, lowercase letters, digits, and safe special characters.
    """
    if length < 10:
        length = 10

    uppercase = "ABCDEFGHJKLMNPQRSTUVWXYZ"  # Exclude I, O to avoid confusion
    lowercase = "abcdefghjkmnpqrstuvwxyz"  # Exclude l, o to avoid confusion
    digits = "23456789"                    # Exclude 0, 1 to avoid confusion
    specials = "@#$%&*"

    # Ensure at least one character from each required category
    password = [
        secrets.choice(uppercase),
        secrets.choice(lowercase),
        secrets.choice(digits),
        secrets.choice(specials),
    ]

    all_chars = uppercase + lowercase + digits + specials
    for _ in range(length - 4):
        password.append(secrets.choice(all_chars))

    # Shuffle to ensure unpredictable positioning
    secrets.SystemRandom().shuffle(password)
    return "".join(password)


def revoke_user_tokens(user: CustomUser):
    """
    Invalidates all existing JWT refresh tokens for the given user so that
    existing sessions cannot be used after an administrative password reset.
    """
    try:
        from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
        tokens = OutstandingToken.objects.filter(user=user)
        revoked_count = 0
        for token in tokens:
            _, created = BlacklistedToken.objects.get_or_create(token=token)
            if created:
                revoked_count += 1
        if revoked_count > 0:
            logger.info(f"[JWT REVOCATION] Blacklisted {revoked_count} active token(s) for user {user.id}")
    except Exception as e:
        logger.warning(f"[JWT REVOCATION ERROR] Could not blacklist tokens for user {user.id}: {e}")


def record_password_audit_log(
    target_user: CustomUser,
    actor: CustomUser = None,
    action: str = PasswordAuditLog.ACTION_RESET,
    status: str = "SUCCESS",
    reason: str = "",
    request=None
):
    """
    Safely records a password management event without logging or saving
    passwords, hashes, tokens, or credential payloads.
    """
    try:
        ip_addr = None
        if request:
            x_forwarded_for = request.META.get("HTTP_X_FORWARDED_FOR")
            if x_forwarded_for:
                ip_addr = x_forwarded_for.split(",")[0].strip()
            else:
                ip_addr = request.META.get("REMOTE_ADDR")

        actor_email = ""
        actor_role = ""
        if actor and getattr(actor, "is_authenticated", False):
            actor_email = getattr(actor, "email", "") or getattr(actor, "user_id", "") or str(actor.id)
            actor_role = (getattr(actor, "role", "") or ("SUPERUSER" if getattr(actor, "is_superuser", False) else "")).upper()

        target_id_str = getattr(target_user, "user_id", "") or getattr(target_user, "usn", "") or getattr(target_user, "email", "") or str(target_user.id)
        target_role = (getattr(target_user, "role", "") or "").upper()

        PasswordAuditLog.objects.create(
            actor=actor if (actor and getattr(actor, "is_authenticated", False)) else None,
            actor_email=actor_email,
            actor_role=actor_role,
            target_user=target_user,
            target_user_id_str=target_id_str,
            target_role=target_role,
            action=action,
            ip_address=ip_addr,
            status=status,
            reason=reason or ""
        )
    except Exception as e:
        logger.error(f"[AUDIT LOG ERROR] Failed to record password audit log: {e}", exc_info=True)


def set_temporary_password_for_user(
    user: CustomUser,
    actor: CustomUser = None,
    action: str = PasswordAuditLog.ACTION_INITIAL_CREATION,
    request=None,
    temporary_password: str = None
) -> str:
    """
    Sets a cryptographically secure temporary password for a user using Django's password hasher.
    Enforces account activation, requires password change upon login, invalidates active JWT
    tokens if this is a reset, revokes pending email invitation records, and records an audit log.

    NEVER stores plaintext password in the database or logs. Returns the temporary password
    so it can be displayed ONLY once in the authorized creation/reset response.
    """
    temp_pwd = temporary_password or generate_secure_temporary_password()

    # Set password using Django's built-in PBKDF2/Argon2 hasher
    user.set_password(temp_pwd)
    user.is_active = True
    user.force_password_change = True
    user.save(update_fields=["password", "is_active", "force_password_change"])

    # If this is a password reset, invalidate all existing refresh tokens
    if action == PasswordAuditLog.ACTION_RESET:
        revoke_user_tokens(user)

    # Invalidate any outstanding email setup/reset invitation records
    try:
        AccountInvitation.objects.filter(
            user=user,
            status__in=[AccountInvitation.STATUS_PENDING, AccountInvitation.STATUS_SENT]
        ).update(status=AccountInvitation.STATUS_REVOKED)
    except Exception:
        pass

    # Record sanitized audit trail
    record_password_audit_log(
        target_user=user,
        actor=actor,
        action=action,
        status="SUCCESS",
        reason="Administrative password management action executed successfully",
        request=request
    )

    return temp_pwd
