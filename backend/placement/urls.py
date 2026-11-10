from django.urls import path
from .views import (
    DepartmentEligibleFacultyView,
    PlacementOfficerListView,
    AssignPlacementOfficerView,
    RevokePlacementOfficerView,
    CompanyListCreateView,
    PlacementDriveListCreateView,
    PlacementApplicationListCreateView,
    PlacementOfferListCreateView,
    StudentPlacementProfileView,
    PlacementStatsView,
    PlacementReportsView,
)

urlpatterns = [
    path('officers/', PlacementOfficerListView.as_view(), name='placement-officers-list'),
    path('officers/assign/', AssignPlacementOfficerView.as_view(), name='assign-placement-officer'),
    path('officers/<int:pk>/revoke/', RevokePlacementOfficerView.as_view(), name='revoke-placement-officer'),
    path('faculty-by-department/', DepartmentEligibleFacultyView.as_view(), name='faculty-by-department'),
    path('companies/', CompanyListCreateView.as_view(), name='companies-list-create'),
    path('drives/', PlacementDriveListCreateView.as_view(), name='drives-list-create'),
    path('applications/', PlacementApplicationListCreateView.as_view(), name='applications-list-create'),
    path('offers/', PlacementOfferListCreateView.as_view(), name='offers-list-create'),
    path('student-profile/', StudentPlacementProfileView.as_view(), name='student-placement-profile'),
    path('stats/', PlacementStatsView.as_view(), name='placement-stats'),
    path('reports/', PlacementReportsView.as_view(), name='placement-reports'),
]
