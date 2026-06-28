from rest_framework import viewsets, permissions, serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.authentication import TokenAuthentication
from django.contrib.auth import get_user_model
from students.models import Student
from .models import Grievance
from .serializers import GrievanceSerializer
from django.shortcuts import get_object_or_404

User = get_user_model()


class GrievanceViewSet(viewsets.ModelViewSet):
    """
    Handles grievance creation and responses.
    Role-based visibility:
      - Students: can submit grievances (faculty / HOD / principal / accounts)
      - Faculty / HOD / Principal / Accounts: can respond to assigned grievances
      - Admin: sees all grievances
    """
    serializer_class = GrievanceSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [TokenAuthentication]

    def get_object(self):
      """
    For the `respond` action, load the grievance WITHOUT queryset filtering.
    Otherwise, DRF returns 404 before permission logic.
    """
    # For normal actions, use default filtered queryset
      if self.action != "respond":
        return super().get_object()

    # For respond action → bypass filtering & get the object directly
      return get_object_or_404(Grievance, pk=self.kwargs.get("pk"))

    # ----------------------------
    # ✅ Queryset filtering
    # ----------------------------
    def get_queryset(self):
        user = self.request.user

        # Superuser sees all
        if getattr(user, "is_superuser", False):
            return Grievance.objects.all()

        # Student sees only own grievances
        if hasattr(user, "student"):
            return Grievance.objects.filter(student__user=user)

        # Faculty / HOD / Principal / Accounts see grievances assigned to them
        return Grievance.objects.filter(target_user=user)

    # ----------------------------
    # ✅ Creation logic
    # ----------------------------
    def perform_create(self, serializer):
        """
        When a student creates a grievance:
          - Links to their Student record
          - Automatically assigns active HOD, Principal, and Accounts users
            if those roles are chosen.
        """
        user = self.request.user

        # Ensure only students can create
        if user.role != "STUDENT":
            raise serializers.ValidationError({"detail": "Only students can submit grievances."})

        # Get or create student record
        student, _ = Student.objects.get_or_create(user=user)

        # Determine role target
        target_role = self.request.data.get("target_role")

        if not target_role:
            raise serializers.ValidationError({"detail": "target_role is required."})

        # Select target users by role
        targets = User.objects.filter(
            role=target_role,
            is_active=True,
        )

        # Extra logic for HOD/Principal/Accounts: match department
        if target_role in ["HOD", "PRINCIPAL", "ACCOUNTS"]:
            if student.department:
                targets = targets.filter(department=student.department)

        if not targets.exists():
            raise serializers.ValidationError({"detail": f"No active users found for role {target_role}."})

        # Assign the first active target (you can modify to support multiple targets)
        target_user = targets.first()

        grievance = serializer.save(student=student, target_user=target_user)
        print(f"[DEBUG] Grievance {grievance.id} saved for {user} targeting {target_role}")

    # ----------------------------
    # ✅ Respond to grievance
    # ----------------------------
    @action(detail=True, methods=["post"])
    def respond(self, request, pk=None):
        grievance = self.get_object()

        if grievance.target_user != request.user:
            return Response({"detail": "You are not assigned to this grievance."}, status=403)

        response_text = request.data.get("response")
        if not response_text:
            return Response({"detail": "Response text required."}, status=400)

        grievance.response = response_text
        grievance.status = "Resolved"
        grievance.save()
        return Response({"detail": "Response saved successfully."})
    


