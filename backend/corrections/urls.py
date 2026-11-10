from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import CorrectionRequestViewSet

router = DefaultRouter()
router.register(r'requests', CorrectionRequestViewSet, basename='correction-request')

urlpatterns = [
    path('', include(router.urls)),
]
