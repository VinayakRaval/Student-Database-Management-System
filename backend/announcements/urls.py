from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AnnouncementViewSet, NotificationViewSet

router = DefaultRouter()
router.register(r'items', AnnouncementViewSet, basename='announcements')
router.register(r'notifications', NotificationViewSet, basename='notifications')

urlpatterns = [
    path('', include(router.urls)),
]
