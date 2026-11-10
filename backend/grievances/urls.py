from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import GrievanceViewSet, GrievanceCategoryViewSet

router = DefaultRouter()
router.register(r"categories", GrievanceCategoryViewSet, basename="grievance-category")
router.register(r"", GrievanceViewSet, basename="grievance")

urlpatterns = [
    path("", include(router.urls)),
]
