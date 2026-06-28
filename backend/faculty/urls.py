from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FacultyViewSet

router = DefaultRouter()
router.register(r"faculties", FacultyViewSet)

urlpatterns = [
    path("", include(router.urls)),
]
