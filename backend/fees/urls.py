from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FeeStructureViewSet, StudentFeeViewSet, FeePaymentViewSet, FeeReceiptViewSet
router = DefaultRouter()
router.register("fee-structures", FeeStructureViewSet)
router.register("student-fees", StudentFeeViewSet)
router.register("payments", FeePaymentViewSet)
router.register("receipts", FeeReceiptViewSet)

urlpatterns = [
    path("", include(router.urls)),
]
