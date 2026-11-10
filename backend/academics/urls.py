from django.urls import path
from .views import (
    DepartmentListCreateView, DepartmentDetailView,
    SemesterListCreateView, SemesterDetailView,
    AcademicYearListCreateView, AcademicYearDetailView,
    SchemaListCreateView, SchemaDetailView,
    SemesterFinalizeView, SemesterFinalizationStatusView
)
from .reports import DepartmentReportsView

urlpatterns = [
    # Department
    path("departments/", DepartmentListCreateView.as_view(), name="department_list_create"),
    path("departments/<int:pk>/", DepartmentDetailView.as_view(), name="department_detail"),

    # Semester
    path("semesters/", SemesterListCreateView.as_view(), name="semester_list_create"),
    path("semesters/<int:pk>/", SemesterDetailView.as_view(), name="semester_detail"),


    # Academic Year
    path("academic-years/", AcademicYearListCreateView.as_view(), name="academic_year_list_create"),
    path("academic-years/<int:pk>/", AcademicYearDetailView.as_view(), name="academic_year_detail"),

    # Schema
    path("schemas/", SchemaListCreateView.as_view(), name="schema_list_create"),
    path("schemas/<int:pk>/", SchemaDetailView.as_view(), name="schema_detail"),

    # Department & Faculty Reports
    path("reports/department/", DepartmentReportsView.as_view(), name="department_reports"),
    path("reports/faculty/", DepartmentReportsView.as_view(), name="faculty_reports"),

    # Semester Finalization & Marks Lock
    path("semesters/finalize/", SemesterFinalizeView.as_view(), name="semester_finalize"),
    path("semesters/finalization-status/", SemesterFinalizationStatusView.as_view(), name="semester_finalization_status"),
]
