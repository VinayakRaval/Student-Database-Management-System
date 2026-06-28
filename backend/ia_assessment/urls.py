from django.urls import path
from . import views

urlpatterns = [
    path("ia-tests/create/", views.IATestSetupCreateView.as_view()),
    path("ia-tests/<int:test_id>/update-marks/", views.BulkIAMarkUpdateView.as_view()),
    path("faculty/active-students/", views.FacultyActiveStudentsView.as_view()),
    path("faculty/ia-marks/", views.FacultyIAMarkListView.as_view()),
    path("student/ia-marks/", views.StudentIAMarkListView.as_view()),
]
