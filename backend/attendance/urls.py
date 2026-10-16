# File: D:\SDMSProject\backend\attendance\urls.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AttendanceViewSet, 
    AttendanceReportView, 
    StudentAttendanceView,
    AttendanceMonitoringSummaryView,
    AttendanceCorrectionReviewView,
    SubjectStudentAttendanceView
)

# Create a router and register our ViewSet with it.
router = DefaultRouter()
router.register(r'', AttendanceViewSet, basename='attendance')

urlpatterns = [
    # Standalone Reporting & Monitoring URLs
    path('monitoring/summary/', AttendanceMonitoringSummaryView.as_view(), name='attendance-monitoring-summary'),
    path('monitoring/subject-students/', SubjectStudentAttendanceView.as_view(), name='attendance-subject-students'),
    path('correction-requests/<int:pk>/review/', AttendanceCorrectionReviewView.as_view(), name='attendance-correction-review'),
    path('report/', AttendanceReportView.as_view(), name='attendance-report'),
    path('student/<int:student_id>/', StudentAttendanceView.as_view(), name='student-attendance-detail'),

    # Router URLs (ViewSet handles create, fetch_students, my_stats)
    path('', include(router.urls)),
]