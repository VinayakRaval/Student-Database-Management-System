from django.urls import path
from . import views

urlpatterns = [
    path("ia-tests/", views.IATestSetupListView.as_view()),
    path("ia-tests/create/", views.IATestSetupCreateView.as_view()),
    path("ia-tests/<int:test_id>/update-marks/", views.BulkIAMarkUpdateView.as_view()),
    path("ia-tests/<int:test_id>/review/", views.IATestReviewView.as_view()),
    path("ia-tests/<int:test_id>/publish/", views.IATestPublishView.as_view()),
    path("ia-tests/<int:test_id>/lock-status/", views.IATestLockStatusView.as_view()),
    path("faculty/active-students/", views.FacultyActiveStudentsView.as_view()),
    path("faculty/ia-marks/", views.FacultyIAMarkListView.as_view()),
    path("student/ia-marks/", views.StudentIAMarkListView.as_view()),
    path("student/portal-summary/", views.StudentIAPortalView.as_view()),
    path("calculation-schemes/", views.IACalculationSchemeView.as_view()),
    path("hod/performance-summary/", views.HODAcademicPerformanceView.as_view()),
    path("hod/test-students/", views.HODTestStudentsView.as_view()),
    path("hod/pre-lock-summary/", views.HODPreLockSummaryView.as_view()),
    path("hod/lock-semester-ia/", views.HODLockSemesterIAView.as_view()),
    path("corrections/request/", views.MarksCorrectionRequestCreateView.as_view()),
    path("corrections/", views.MarksCorrectionRequestListView.as_view()),
    path("corrections/<int:pk>/review/", views.MarksCorrectionRequestReviewView.as_view()),
    path("audit-logs/", views.MarksSecurityAuditLogListView.as_view()),
]


