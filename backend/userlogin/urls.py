from django.urls import path
from userlogin.views import DashboardView
from .views import (
    LoginView,
    PasswordChangeView,
    PasswordResetDirectView,
    PasswordResetRequestView,
    PasswordResetVerifyView,
)

urlpatterns = [
    path("login/", LoginView.as_view(), name="login"),
    path("password/change/", PasswordChangeView.as_view(), name="password-change"),
    path("password/reset/direct/", PasswordResetDirectView.as_view(), name="password-reset-direct"),
    path("password/reset/request/", PasswordResetRequestView.as_view(), name="password-reset-request"),
    path("password/reset/verify/", PasswordResetVerifyView.as_view(), name="password-reset-verify"),
    path('dashboard/', DashboardView.as_view(), name='dashboard'),
]
