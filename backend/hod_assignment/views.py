from django.utils import timezone
from django.db import transaction
from rest_framework import generics, permissions
from .models import HODAssignment
from .serializers import HODAssignmentSerializer
from faculty.models import Faculty
from userlogin.models import CustomUser


class CurrentHODView(generics.ListAPIView):
    queryset = HODAssignment.objects.filter(end_date__isnull=True)
    serializer_class = HODAssignmentSerializer
    permission_classes = [permissions.AllowAny]


class PreviousHODView(generics.ListAPIView):
    queryset = HODAssignment.objects.filter(end_date__isnull=False)
    serializer_class = HODAssignmentSerializer
    permission_classes = [permissions.AllowAny]


class AssignHODView(generics.CreateAPIView):
    queryset = HODAssignment.objects.all()
    serializer_class = HODAssignmentSerializer
    permission_classes = [permissions.IsAdminUser]

    @transaction.atomic
    def perform_create(self, serializer):
        department = serializer.validated_data["department"]
        faculty = serializer.validated_data["faculty"]
        assigned_date = serializer.validated_data.get("assigned_date", timezone.now().date())

        # End previous HOD assignments for department
        previous_hods = HODAssignment.objects.filter(department=department, end_date__isnull=True)
        for hod in previous_hods:
            hod.end_date = assigned_date
            hod.save()

            # Reset previous HOD faculty role
            prev_faculty = hod.faculty
            prev_faculty.role = "PROFESSOR"  # Or default role like 'PROFESSOR'
            prev_faculty.save()

            # Update linked CustomUser if exists
            try:
                prev_user = CustomUser.objects.get(user_id=prev_faculty.faculty_id)
                prev_user.role = "PROFESSOR"  # Or default role
                prev_user.save()
            except CustomUser.DoesNotExist:
                pass

        # Create new HOD assignment
        serializer.save(assigned_date=assigned_date)

        # Update new faculty role and department
        faculty.department = department
        faculty.role = "HOD"
        faculty.save()

        # Update linked CustomUser if exists
        try:
            user = CustomUser.objects.get(user_id=faculty.faculty_id)
            user.role = "HOD"
            user.department = department
            user.save()
        except CustomUser.DoesNotExist:
            pass
