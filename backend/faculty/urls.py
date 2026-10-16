from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FacultyViewSet

router = DefaultRouter()
router.register(r"faculties", FacultyViewSet)

urlpatterns = [
    path("next-id/", FacultyViewSet.as_view({'get': 'next_id'}), name="faculty-next-id-direct"),
    path("<int:pk>/resend_invitation/", FacultyViewSet.as_view({'post': 'resend_invitation'}), name="faculty-resend-direct"),
    path("<int:pk>/approve/", FacultyViewSet.as_view({'post': 'approve'}), name="faculty-approve-direct"),
    path("", include(router.urls)),
]
