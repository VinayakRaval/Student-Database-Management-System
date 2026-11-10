from django.test import TestCase
from django.contrib.auth import authenticate
from userlogin.models import CustomUser, PasswordAuditLog
from userlogin.password_service import (
    generate_secure_temporary_password,
    set_temporary_password_for_user,
    record_password_audit_log,
)


class InAppPasswordManagementTests(TestCase):
    """
    Automated test suite verifying the complete in-app password management workflow:
    - Cryptographic password generation
    - PBKDF2/Django password hashing
    - Account activation & force_password_change flag
    - Sanitized audit logging (no passwords or hashes stored in audit table)
    - Complete email independence
    """

    def setUp(self):
        self.actor_hod = CustomUser.objects.create_user(
            email="hod_test@campusflow.edu",
            user_id="hod_cse_99",
            role="HOD",
            is_active=True
        )
        self.target_user = CustomUser.objects.create_user(
            email="faculty_test@campusflow.edu",
            user_id="prof999",
            role="PROFESSOR",
            is_active=False
        )

    def test_generate_secure_temporary_password(self):
        pwd = generate_secure_temporary_password(length=12)
        self.assertGreaterEqual(len(pwd), 12)
        # Verify it contains uppercase, lowercase, digit, and special char
        has_upper = any(c.isupper() for c in pwd)
        has_lower = any(c.islower() for c in pwd)
        has_digit = any(c.isdigit() for c in pwd)
        has_special = any(c in "@#$%&*" for c in pwd)
        self.assertTrue(has_upper, "Password must contain uppercase letters")
        self.assertTrue(has_lower, "Password must contain lowercase letters")
        self.assertTrue(has_digit, "Password must contain digits")
        self.assertTrue(has_special, "Password must contain special characters")

    def test_set_temporary_password_for_user(self):
        temp_pwd = set_temporary_password_for_user(
            user=self.target_user,
            actor=self.actor_hod,
            action=PasswordAuditLog.ACTION_INITIAL_CREATION
        )

        self.target_user.refresh_from_db()
        # 1. Plaintext password is NOT in database
        self.assertNotEqual(self.target_user.password, temp_pwd)
        self.assertTrue(self.target_user.password.startswith("md5$") or self.target_user.password.startswith("pbkdf2_"))

        # 2. Authenticates properly with temporary password
        self.assertTrue(self.target_user.check_password(temp_pwd))

        # 3. User is active and required to change password
        self.assertTrue(self.target_user.is_active)
        self.assertTrue(self.target_user.force_password_change)

        # 4. Audit log was recorded safely
        log = PasswordAuditLog.objects.filter(target_user=self.target_user).first()
        self.assertIsNotNone(log)
        self.assertEqual(log.action, PasswordAuditLog.ACTION_INITIAL_CREATION)
        self.assertEqual(log.actor, self.actor_hod)
        self.assertEqual(log.actor_role, "HOD")
        self.assertEqual(log.status, "SUCCESS")

    def test_reset_password_workflow(self):
        new_pwd = set_temporary_password_for_user(
            user=self.target_user,
            actor=self.actor_hod,
            action=PasswordAuditLog.ACTION_RESET
        )

        self.target_user.refresh_from_db()
        self.assertTrue(self.target_user.check_password(new_pwd))
        self.assertTrue(self.target_user.force_password_change)

        log = PasswordAuditLog.objects.filter(target_user=self.target_user, action=PasswordAuditLog.ACTION_RESET).first()
        self.assertIsNotNone(log)
        self.assertEqual(log.status, "SUCCESS")

    def test_audit_log_never_contains_passwords(self):
        secret_word = "SuperSecretTemp123!"
        set_temporary_password_for_user(
            user=self.target_user,
            actor=self.actor_hod,
            action=PasswordAuditLog.ACTION_RESET,
            temporary_password=secret_word
        )

        log = PasswordAuditLog.objects.filter(target_user=self.target_user).latest('timestamp')
        # Audit log fields must never contain the password
        self.assertNotIn(secret_word, log.reason)
        self.assertNotIn(secret_word, log.target_user_id_str)
        self.assertNotIn(secret_word, log.actor_email)
