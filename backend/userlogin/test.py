from django.urls import reverse
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from userlogin.models import PasswordResetOTP
from unittest.mock import patch


User = get_user_model()


class UserLoginTests(APITestCase):

    def setUp(self):
        # Normal user
        self.user = User.objects.create_user(
            email="user@test.com",
            password="pass123",
            role="STUDENT",
            force_password_change=True
        )

        # Admin user
        self.admin = User.objects.create_superuser(
            email="admin@test.com",
            password="adminpass",
        )

        self.client_user = APIClient()
        self.client_admin = APIClient()

        self.client_user.force_authenticate(self.user)
        self.client_admin.force_authenticate(self.admin)

    # ---------------------------------------------------------
    # 1. LOGIN SUCCESS
    # ---------------------------------------------------------
    def test_login_success(self):
        url = reverse("login")
        payload = {"identifier": "user@test.com", "password": "pass123"}

        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertIn("access", res.data)
        self.assertIn("refresh", res.data)
        self.assertEqual(res.data["role"], "STUDENT")
        self.assertEqual(res.data["force_password_change"], True)

    # ---------------------------------------------------------
    # 2. LOGIN WRONG PASSWORD
    # ---------------------------------------------------------
    def test_login_wrong_password(self):
        url = reverse("login")
        payload = {"identifier": "user@test.com", "password": "wrongpass"}

        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("error", res.data)

    # ---------------------------------------------------------
    # 3. LOGIN NO CREDENTIALS
    # ---------------------------------------------------------
    def test_login_missing_credentials(self):
        url = reverse("login")
        res = self.client.post(url, {}, format="json")

        self.assertEqual(res.status_code, 400)
        self.assertIn("error", res.data)

    # ---------------------------------------------------------
    # 4. PASSWORD CHANGE (Authenticated)
    # ---------------------------------------------------------
    def test_password_change(self):
        url = reverse("password-change")
        payload = {
            "old_password": "pass123",
            "new_password": "newpass321"
        }

        res = self.client_user.post(url, payload, format="json")
        self.assertEqual(res.status_code, 200)

        self.user.refresh_from_db()
        self.assertFalse(self.user.force_password_change)
        self.assertTrue(self.user.check_password("newpass321"))

    # ---------------------------------------------------------
    # 5. PASSWORD CHANGE WRONG OLD PASSWORD
    # ---------------------------------------------------------
    def test_password_change_wrong_old(self):
        url = reverse("password-change")
        payload = {"old_password": "wrong", "new_password": "newpass"}

        res = self.client_user.post(url, payload, format="json")
        self.assertEqual(res.status_code, 400)

    # ---------------------------------------------------------
    # 6. ADMIN DIRECT PASSWORD RESET
    # ---------------------------------------------------------
    def test_admin_direct_password_reset(self):
        url = reverse("password-reset-direct")
        payload = {"identifier": "user@test.com", "new_password": "updated123"}

        res = self.client_admin.post(url, payload, format="json")
        self.assertEqual(res.status_code, 200)

        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("updated123"))

    # ---------------------------------------------------------
    # 7. PASSWORD RESET REQUEST (OTP)
    # ---------------------------------------------------------
    @patch("userlogin.utils.send_otp_email")
    def test_password_reset_request(self, mock_send_email):
        mock_send_email.return_value = True

        url = reverse("password-reset-request")
        payload = {"email": "user@test.com"}

        res = self.client.post(url, payload, format="json")

        self.assertEqual(res.status_code, 200)
        self.assertTrue(PasswordResetOTP.objects.filter(user=self.user).exists())

    # ---------------------------------------------------------
    # 8. PASSWORD RESET VERIFY
    # ---------------------------------------------------------
    def test_password_reset_verify(self):
        otp_obj = PasswordResetOTP.objects.create(
            user=self.user,
            otp="999999"
        )

        url = reverse("password-reset-verify")
        payload = {
            "email": "user@test.com",
            "otp": "999999",
            "new_password": "abc12345"
        }

        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 200)

        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("abc12345"))
        self.assertFalse(PasswordResetOTP.objects.filter(otp="999999").exists())

    # ---------------------------------------------------------
    # 9. PASSWORD RESET INVALID OTP
    # ---------------------------------------------------------
    def test_password_reset_invalid_otp(self):
        url = reverse("password-reset-verify")
        payload = {
            "email": "user@test.com",
            "otp": "111111",
            "new_password": "abc12345"
        }

        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("error", res.data)

    # ---------------------------------------------------------
    # 10. PASSWORD RESET INVALID EMAIL FORMAT
    # ---------------------------------------------------------
    def test_password_reset_invalid_email_format(self):
        url = reverse("password-reset-request")
        payload = {"email": "notanemail"}

        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("valid email", str(res.data).lower())
