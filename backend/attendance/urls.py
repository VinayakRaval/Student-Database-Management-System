from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AttendanceViewSet, 
    AttendanceReportView, 
    StudentAttendanceView,
    AttendanceMonitoringSummaryView,
    AttendanceCorrectionReviewView,
    SubjectStudentAttendanceView,
    AttendanceCorrectionSubmitView,
    FacultyCorrectionRequestsListView,
    LabBatchViewSet,
    AttendanceAuditLogListView,
    ExtraClassSessionViewSet,
    TodaySessionsView,
)

router = DefaultRouter()
router.register(r'extra-classes', ExtraClassSessionViewSet, basename='extra-class')
router.register(r'batches', LabBatchViewSet, basename='lab-batch')
router.register(r'', AttendanceViewSet, basename='attendance')

urlpatterns = [
    # Standalone Reporting & Monitoring URLs
    path('today-sessions/', TodaySessionsView.as_view(), name='today-sessions'),
    path('monitoring/summary/', AttendanceMonitoringSummaryView.as_view(), name='attendance-monitoring-summary'),
    path('monitoring/subject-students/', SubjectStudentAttendanceView.as_view(), name='attendance-subject-students'),
    path('correction-requests/submit/', AttendanceCorrectionSubmitView.as_view(), name='attendance-correction-submit'),
    path('correction-requests/my-requests/', FacultyCorrectionRequestsListView.as_view(), name='faculty-correction-requests'),
    path('correction-requests/<int:pk>/review/', AttendanceCorrectionReviewView.as_view(), name='attendance-correction-review'),
    path('audit-logs/', AttendanceAuditLogListView.as_view(), name='attendance-audit-logs'),
    path('report/', AttendanceReportView.as_view(), name='attendance-report'),
    path('student/<int:student_id>/', StudentAttendanceView.as_view(), name='student-attendance-detail'),

    # Router URLs (batches + extra-classes + attendance)
    path('', include(router.urls)),
]