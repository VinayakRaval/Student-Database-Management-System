from django.urls import path
from userlogin.views import DashboardView
from .views import (
    LoginView,
    PasswordChangeView,
    PasswordResetDirectView,
    PasswordResetRequestView,
    PasswordResetVerifyView,
    PasswordSetupVerifyTokenView,
    PasswordSetupConfirmView,
    ResendInvitationView,
    RegistrationSendOTPView,
    RegistrationVerifyOTPView,
)

urlpatterns = [
    path("login/", LoginView.as_view(), name="login"),
    path("password/change/", PasswordChangeView.as_view(), name="password-change"),
    path("password/reset/direct/", PasswordResetDirectView.as_view(), name="password-reset-direct"),
    path("password/reset/request/", PasswordResetRequestView.as_view(), name="password-reset-request"),
    path("password/reset/verify/", PasswordResetVerifyView.as_view(), name="password-reset-verify"),
    path("register/send-otp/", RegistrationSendOTPView.as_view(), name="register-send-otp"),
    path("register/verify-otp/", RegistrationVerifyOTPView.as_view(), name="register-verify-otp"),
    path("setup-password/verify-token/", PasswordSetupVerifyTokenView.as_view(), name="setup-password-verify"),
    path("setup-password/confirm/", PasswordSetupConfirmView.as_view(), name="setup-password-confirm"),
    path("invitations/resend/", ResendInvitationView.as_view(), name="invitations-resend"),
    path('dashboard/', DashboardView.as_view(), name='dashboard'),
]

