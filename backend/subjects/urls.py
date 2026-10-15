from django.urls import path
from .views import (
    AddSubjectView, GetSubjectsView, 
    AssignSubjectsView, GetAssignedProfessorsView,
    ViewAssignedByDepartmentView, GetAssignedSubjectsForProfessorView,
    DeleteSubjectView
)

urlpatterns = [
    path('addSubject/', AddSubjectView.as_view(), name='add-subject'),
    path('getSubjects/', GetSubjectsView.as_view(), name='get-subjects'),
    path('assign_subjects/', AssignSubjectsView.as_view(), name='assign-subjects'),
    path('getAssignedProfessors/', GetAssignedProfessorsView.as_view(), name='get-assigned-professors'),
    path('view-assigned-by-department/', ViewAssignedByDepartmentView.as_view(), name='view-assigned-dept'),
    path('professor/subjects/', GetAssignedSubjectsForProfessorView.as_view(), name='professor-subjects'),
    path('delete/<int:pk>/', DeleteSubjectView.as_view(), name='delete-subject'),
]
