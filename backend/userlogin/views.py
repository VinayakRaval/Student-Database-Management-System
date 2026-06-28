import logging
import re
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework_simplejwt.tokens import RefreshToken
from .models import CustomUser, PasswordResetOTP
from .serializers import UserSerializer
from .utils import generate_otp, get_user_by_identifier, send_otp_email
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        identifier = request.data.get("identifier")
        password = request.data.get("password")
        if not identifier or not password:
            return Response({"error": "Identifier and password required"}, status=status.HTTP_400_BAD_REQUEST)

        user = get_user_by_identifier(identifier)
        if not user or not user.check_password(password):
            logger.warning(f"Failed login attempt: {identifier}")
            return Response({"error": "Invalid credentials"}, status=status.HTTP_400_BAD_REQUEST)

        # If force_password_change is True, include that info so frontend can redirect
        refresh = RefreshToken.for_user(user)
        data = {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "role": user.role,
            "force_password_change": user.force_password_change,
            "user": UserSerializer(user).data
        }
        return Response(data, status=status.HTTP_200_OK)



class PasswordChangeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        old_password = request.data.get("old_password")
        new_password = request.data.get("new_password")
        user = request.user

        if not old_password or not new_password:
            return Response({"error": "Both old and new password required"}, status=status.HTTP_400_BAD_REQUEST)

        if not user.check_password(old_password):
            return Response({"error": "Old password is incorrect"}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.force_password_change = False  # clear flag on manual change
        user.save()
        logger.info(f"Password changed for user_id: {user.user_id or user.email}")
        return Response({"message": "Password changed successfully"}, status=status.HTTP_200_OK)


class PasswordResetDirectView(APIView):
    """
    Admin-only: reset any user's password directly (no OTP).
    """
    permission_classes = [permissions.IsAdminUser]

    def post(self, request):
        identifier = request.data.get("identifier")
        new_password = request.data.get("new_password")
        if not identifier or not new_password:
            return Response({"error": "Both identifier and new password required"}, status=status.HTTP_400_BAD_REQUEST)

        user = get_user_by_identifier(identifier)
        if not user:
            return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        user.set_password(new_password)
        user.force_password_change = True  # force them to change on next login if you prefer
        user.save()
        logger.info(f"Admin reset password for {identifier}")
        return Response({"message": "Password reset successful"}, status=status.HTTP_200_OK)
    import re


EMAIL_REGEX = r"[^@]+@[^@]+\.[^@]+"  # basic email validation


class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email") or request.data.get("identifier")
        if not email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)

        # Validate email format
        if not re.match(EMAIL_REGEX, email):
            return Response({"error": "Enter a valid email"}, status=status.HTTP_400_BAD_REQUEST)

        # Check if user exists
        users = CustomUser.objects.filter(email__iexact=email)
        if not users.exists():
            return Response({"error": "No user found with this email"}, status=status.HTTP_404_NOT_FOUND)
        if users.count() > 1:
            return Response({"error": "Duplicate email exists, cannot generate OTP"}, status=status.HTTP_400_BAD_REQUEST)

        user = users.first()

        # Generate OTP
        otp = generate_otp()
        PasswordResetOTP.objects.create(user=user, otp=otp)

        # Send OTP via email
        try:
            send_otp_email(user, otp)
        except Exception as e:
            return Response({"error": f"Failed to send OTP: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response({"message": f"OTP sent successfully to {email}"}, status=status.HTTP_200_OK)
    
class PasswordResetVerifyView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email")
        otp = request.data.get("otp")
        new_password = request.data.get("new_password")

        if not (email and otp and new_password):
            return Response({"error": "All fields are required"}, status=status.HTTP_400_BAD_REQUEST)

        user = CustomUser.objects.filter(email__iexact=email).first()
        if not user:
            return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        otp_obj = PasswordResetOTP.objects.filter(user=user, otp=otp).first()
        if not otp_obj:
            return Response({"error": "Invalid OTP"}, status=status.HTTP_400_BAD_REQUEST)

        # Check if OTP expired (10 minutes)
        if timezone.now() > otp_obj.created_at + timedelta(minutes=10):
            otp_obj.delete()
            return Response({"error": "OTP expired"}, status=status.HTTP_400_BAD_REQUEST)

        # Reset password
        user.set_password(new_password)
        user.force_password_change = False
        user.save()
        otp_obj.delete()

        return Response({"message": "Password reset successful"}, status=status.HTTP_200_OK)