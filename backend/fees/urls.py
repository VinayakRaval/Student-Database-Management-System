from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    FeeStructureViewSet,
    StudentFeeViewSet,
    FeePaymentViewSet,
    FeeReceiptViewSet,
    AccountsDashboardView,
    FeeReportsView,
)

router = DefaultRouter()
router.register("fee-structures", FeeStructureViewSet)
router.register("student-fees", StudentFeeViewSet)
router.register("payments", FeePaymentViewSet)
router.register("receipts", FeeReceiptViewSet)

urlpatterns = [
    path("dashboard-stats/", AccountsDashboardView.as_view(), name="fee-dashboard-stats"),
    path("reports/", FeeReportsView.as_view(), name="fee-reports"),
    path("", include(router.urls)),
]
