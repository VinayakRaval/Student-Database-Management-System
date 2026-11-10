from django.urls import path
from .views import (
    StudentCreateView,
    StudentListView,
    StudentDetailUpdateView,
    AssignUSNView,
    DepartmentVerificationView,
    PrincipalApprovalView,
    StudentDetailView,
    promote_student,
    reset_student_password,
    resend_student_invitation,
    StudentAcademicHistoryListView,
    StudentAcademicHistoryDetailView,
    update_student_status,
)

urlpatterns = [
    # Step 1: Student registration
    path('create/', StudentCreateView.as_view(), name='student-create'),

    # List all students (admin/authorized)
    path('', StudentListView.as_view(), name='student-list-root'),
    path('list/', StudentListView.as_view(), name='student-list'),

    # Get or update student by ID
    path('<int:id>/', StudentDetailUpdateView.as_view(), name='student-detail-update'),

    # Assign USN to student
    path('<int:id>/assign-usn/', AssignUSNView.as_view(), name='student-assign-usn'),


    # Step 2: Department verifies registration (only department staff)
    path('<int:id>/verify/', DepartmentVerificationView.as_view(), name='student-verify'),

    # Step 3: Principal approves or rejects registration
    path('<int:id>/approve/', PrincipalApprovalView.as_view(), name='student-approve'),

    # Reset Student Password / Resend Invitation (HOD/Principal/Admin)
    path('<int:id>/reset-password/', reset_student_password, name='student-reset-password'),
    path('<int:id>/reset_password/', reset_student_password, name='student-reset-password-underscore'),
    path('<int:id>/resend-invitation/', resend_student_invitation, name='student-resend-invitation'),

    # Student views their own details (after approval/login)
    path('me/', StudentDetailView.as_view(), name='student-self-detail'),

    # Promote semester for students of a department (only HOD)
    path('<int:id>/promote/', promote_student, name='student-promote'),

    # Academic History & Records Preservation
    path('academic-history/', StudentAcademicHistoryListView.as_view(), name='student-academic-history-list'),
    path('<int:id>/academic-history/', StudentAcademicHistoryDetailView.as_view(), name='student-academic-history-detail'),
    path('<int:id>/update-status/', update_student_status, name='student-update-status'),
]
