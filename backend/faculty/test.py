from django.test import TestCase
from django.contrib.auth import get_user_model
from django.db import IntegrityError
from django.utils import timezone

from academics.models import Department
from .models import Faculty

User = get_user_model()


class FacultyModelSignalTests(TestCase):
    def setUp(self):
        # create a department
        self.dept = Department.objects.create(name="CSE")

        # create users for linking with faculty objects
        self.user1 = User.objects.create_user(email="u1@example.com", password="pass123", role=None)
        self.user2 = User.objects.create_user(email="u2@example.com", password="pass123", role="PRINCIPAL")
        self.user3 = User.objects.create_user(email="u3@example.com", password="pass123", role=None)

    def test_default_status_is_pending_office(self):
        f = Faculty.objects.create(
            user=self.user1,
            faculty_id="FAC001",
            name="Alice",
            phone="9000000001",
            email="alice@example.com",
            department=self.dept,
        )
        # model default
        self.assertEqual(f.status, "pending_office")

    def test_principal_role_with_pending_principal_auto_approves_on_save(self):
        # create faculty with role PRINCIPAL and status pending_principal
        f = Faculty.objects.create(
            user=self.user3,
            faculty_id="FAC_PRINC",
            name="New Principal",
            phone="9000000002",
            email="principal_new@example.com",
            department=self.dept,
            role="PRINCIPAL",
            status="pending_principal",
        )
        # pre_save signal should convert pending_principal -> approved
        f.refresh_from_db()
        self.assertEqual(f.status, "approved")
        # approved_date should be set by post_save (since status == approved)
        self.assertIsNotNone(f.approved_date)

    def test_post_save_updates_user_and_sets_approved_date_when_approved_and_user_provided(self):
        # ensure user2 currently has role PRINCIPAL
        self.assertEqual(self.user2.role, "PRINCIPAL")

        # create a faculty linked to user2 and set status=approved
        f = Faculty.objects.create(
            user=self.user2,
            faculty_id="FAC002",
            name="Bob",
            phone="9000000003",
            email="bob@example.com",
            department=self.dept,
            role="PRINCIPAL",
            status="approved",  # post_save should set approved_date and update user fields
        )

        f.refresh_from_db()
        self.user2.refresh_from_db()

        # post_save should set approved_date if it was None
        self.assertIsNotNone(f.approved_date)
        # user2.role should remain PRINCIPAL (because we set this user's faculty as principal)
        self.assertEqual(self.user2.role, "PRINCIPAL")
        # user's email and phone updated from faculty
        self.assertEqual(self.user2.email, f.email)
        self.assertEqual(self.user2.phone, f.phone)

    def test_principal_uniqueness_clears_other_principal_roles(self):
        # At start user2 has role PRINCIPAL
        self.assertEqual(self.user2.role, "PRINCIPAL")

        # Create a new user and new faculty that will be PRINCIPAL and approved
        new_user = User.objects.create_user(email="newp@example.com", password="pass123", role=None)
        f_new = Faculty.objects.create(
            user=new_user,
            faculty_id="FAC_PRINC_2",
            name="Principal Two",
            phone="9000000004",
            email="principal2@example.com",
            department=self.dept,
            role="PRINCIPAL",
            status="approved",
        )

        # refresh old principal user
        self.user2.refresh_from_db()
        # the signal should have cleared other users' roles (set to None)
        self.assertNotEqual(self.user2.role, "PRINCIPAL")

        def test_duplicate_email_or_phone_allowed_due_to_encryption(self):
          """
            Encrypted fields DO NOT enforce DB-level uniqueness.
        Ciphertext differs each time → DB allows duplicates.
        Validation should happen at API level, not model.
        """

        # first faculty
        Faculty.objects.create(
            user=self.user1,
            faculty_id="FAC_DUP1",
            name="Dup One",
            phone="9000000010",
            email="dup@example.com",
            department=self.dept,
            status="pending_office",
        )

        # second faculty with SAME phone + email (plaintext)
        # Should NOT raise IntegrityError
        Faculty.objects.create(
            user=self.user3,
            faculty_id="FAC_DUP2",
            name="Dup Two",
            phone="9000000010",   # same phone
            email="dup@example.com",  # same email
            department=self.dept,
            status="pending_office",
        )

        # Ensure both records exist
        self.assertGreaterEqual(Faculty.objects.count(), 2)

