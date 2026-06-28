from django.urls import path
from .views import (
    StudentCreateView,
    StudentListView,
    StudentDetailUpdateView,
    AssignUSNView,
    DepartmentVerificationView,
    PrincipalApprovalView,
    StudentDetailView,
    promote_student,  # <-- import the promote_semester view
)

urlpatterns = [
    # Step 1: Student registration
    path('create/', StudentCreateView.as_view(), name='student-create'),

    # List all students (admin/authorized)
    path('list/', StudentListView.as_view(), name='student-list'),

    # Get or update student by ID
    path('<int:id>/', StudentDetailUpdateView.as_view(), name='student-detail-update'),

    # Assign USN to student
    path('<int:id>/assign-usn/', AssignUSNView.as_view(), name='student-assign-usn'),


    # Step 2: Department verifies registration (only department staff)
    path('<int:id>/verify/', DepartmentVerificationView.as_view(), name='student-verify'),

    # Step 3: Principal approves or rejects registration
    path('<int:id>/approve/', PrincipalApprovalView.as_view(), name='student-approve'),

    # Student views their own details (after approval/login)
    path('me/', StudentDetailView.as_view(), name='student-self-detail'),

    # Promote semester for students of a department (only HOD)
    path('<int:id>/promote/', promote_student, name='student-promote'),

]
