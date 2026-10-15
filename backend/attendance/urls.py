# File: D:\SDMSProject\backend\attendance\urls.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AttendanceViewSet, 
    AttendanceReportView, 
    StudentAttendanceView
)

# Create a router and register our ViewSet with it.
router = DefaultRouter()
router.register(r'', AttendanceViewSet, basename='attendance')

urlpatterns = [
    # Standalone Reporting URLs
    path('report/', AttendanceReportView.as_view(), name='attendance-report'),
    path('student/<int:student_id>/', StudentAttendanceView.as_view(), name='student-attendance-detail'),

    # Router URLs (ViewSet handles create, fetch_students, my_stats)
    path('', include(router.urls)),
]