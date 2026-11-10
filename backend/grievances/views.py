import os
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.contrib.auth import get_user_model
from django.db.models import Q, Count, Avg, F
from django.utils import timezone
from datetime import timedelta

from .models import Grievance, GrievanceCategory, GrievanceActivity, GrievanceAttachment
from .serializers import (
    GrievanceSerializer,
    GrievanceCreateSerializer,
    GrievanceCategorySerializer,
    GrievanceActivitySerializer,
    GrievanceAttachmentSerializer,
    StatusUpdateSerializer,
    AssignOfficerSerializer,
    RequestInfoSerializer,
    ProvideInfoSerializer,
    EscalateSerializer,
    ResolveSerializer,
    RejectSerializer,
    ReopenRequestSerializer,
    ReopenReviewSerializer,
)
from students.models import Student
from faculty.models import Faculty
from academics.models import Department

User = get_user_model()


def send_grievance_notification(recipient, title, message):
    """Safely create an in-app notification without breaking transaction on failure."""
    if not recipient:
        return
    try:
        from announcements.models import Notification
        Notification.objects.create(
            recipient=recipient,
            title=title,
            message=message,
            notification_type="GENERAL",
        )
    except Exception as e:
        print(f"[GRIEVANCE_NOTIF_ERROR] Failed to send notification: {e}")


# Pre-populated categories
DEFAULT_CATEGORIES = [
    {
        "code": "ACADEMIC",
        "name": "Academic and IA marks",
        "description": "Concerns regarding internal assessments, syllabus coverage, marks discrepancy or grades.",
        "default_target_role": "HOD",
        "sla_days": 7,
        "is_confidential_by_default": False,
    },
    {
        "code": "ATTENDANCE",
        "name": "Attendance and timetable",
        "description": "Attendance shortages, timetable conflicts, extra classes or medical leaves.",
        "default_target_role": "HOD",
        "sla_days": 5,
        "is_confidential_by_default": False,
    },
    {
        "code": "FACULTY",
        "name": "Faculty-related concerns",
        "description": "Teaching methodology, communication, scheduling or classroom interactions.",
        "default_target_role": "HOD",
        "sla_days": 5,
        "is_confidential_by_default": False,
    },
    {
        "code": "ADMISSION",
        "name": "Admission and student records",
        "description": "Enrollment, transfer certificate, category verification, personal record corrections.",
        "default_target_role": "ADMISSION",
        "sla_days": 7,
        "is_confidential_by_default": False,
    },
    {
        "code": "FEES",
        "name": "Fees and payments",
        "description": "Fee receipts, instalment requests, scholarship adjustments or online payment verification.",
        "default_target_role": "ACCOUNTS",
        "sla_days": 5,
        "is_confidential_by_default": False,
    },
    {
        "code": "LIBRARY",
        "name": "Library services",
        "description": "Book issue/return, digital library access, catalogue queries, fine disputes.",
        "default_target_role": "LIBRARY",
        "sla_days": 5,
        "is_confidential_by_default": False,
    },
    {
        "code": "INFRASTRUCTURE",
        "name": "Infrastructure and laboratory facilities",
        "description": "Lab equipment, computer systems, classroom amenities, drinking water or washroom maintenance.",
        "default_target_role": "HOD",
        "sla_days": 7,
        "is_confidential_by_default": False,
    },
    {
        "code": "TECHNICAL",
        "name": "Technical issues",
        "description": "Portal login, software errors, network/Wi-Fi or system bugs.",
        "default_target_role": "SYSTEM",
        "sla_days": 3,
        "is_confidential_by_default": False,
    },
    {
        "code": "HARASSMENT",
        "name": "Harassment and safety",
        "description": "Strictly confidential reporting of ragging, harassment, safety or discriminatory incidents.",
        "default_target_role": "PRINCIPAL",
        "sla_days": 1,
        "is_confidential_by_default": True,
    },
    {
        "code": "OTHER",
        "name": "Other",
        "description": "General grievances or miscellaneous student and faculty requests.",
        "default_target_role": "HOD",
        "sla_days": 7,
        "is_confidential_by_default": False,
    },
]


def ensure_default_categories():
    """Ensure standard categories exist in database."""
    try:
        for cat in DEFAULT_CATEGORIES:
            GrievanceCategory.objects.get_or_create(
                code=cat["code"],
                defaults=cat,
            )
    except Exception:
        pass


class GrievanceCategoryViewSet(viewsets.ModelViewSet):
    serializer_class = GrievanceCategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        ensure_default_categories()
        return GrievanceCategory.objects.filter(is_active=True).order_by("name")

    def perform_create(self, serializer):
        # Enable any authenticated user or admin to add custom categories
        name = serializer.validated_data.get("name", "").strip()
        code = serializer.validated_data.get("code", "").strip()
        if not code and name:
            code = name.upper().replace(" ", "_")[:50]
        serializer.save(code=code, is_active=True)


class GrievanceViewSet(viewsets.ModelViewSet):
    """
    Role-Based Grievance Management ViewSet.
    Handles submission, tracking, assignment, escalation, and resolution.
    """
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.action == "create":
            return GrievanceCreateSerializer
        return GrievanceSerializer

    # -------------------------------------------------------------
    # 1. Role-based, Department-based & Object-level Queryset Filtering
    # -------------------------------------------------------------
    def get_queryset(self):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()

        qs = Grievance.objects.select_related(
            "submitted_by", "student", "student__user", "department",
            "category", "target_user", "escalated_to", "resolved_by", "reopened_by"
        ).prefetch_related("activities", "activities__actor", "attachments")

        # Scope filter from frontend (e.g. scope=my or scope=assigned)
        scope = self.request.query_params.get("scope", "").strip().lower()

        # Complainant filter (e.g. Student or Faculty viewing their own submitted complaints)
        if role == "STUDENT" or scope == "my":
            qs = qs.filter(Q(submitted_by=user) | Q(student__user=user))

        elif role == "PROFESSOR":
            if scope == "assigned":
                qs = qs.filter(target_user=user)
            else:
                # Faculty sees submitted by them OR assigned to them
                qs = qs.filter(Q(submitted_by=user) | Q(target_user=user))

        elif role == "HOD":
            # HOD sees departmental grievances + complaints assigned to HOD + submitted by HOD
            hod_dept = user.department
            if not hod_dept:
                fac = Faculty.objects.filter(user=user).first()
                if fac:
                    hod_dept = fac.department

            dept_q = Q(department=hod_dept) | Q(student__department=hod_dept) if hod_dept else Q()

            # Confidential grievances in department are hidden unless explicitly assigned to HOD
            non_confidential_dept = dept_q & Q(is_confidential=False)

            if scope == "assigned":
                qs = qs.filter(target_user=user)
            else:
                qs = qs.filter(
                    non_confidential_dept
                    | Q(target_user=user)
                    | Q(submitted_by=user)
                ).distinct()

        elif role == "PRINCIPAL" or getattr(user, "is_superuser", False):
            # Principal sees all departmental complaints, escalated complaints, and complaints assigned to Principal
            if scope == "assigned":
                qs = qs.filter(target_user=user)
            elif scope == "escalated":
                qs = qs.filter(Q(is_escalated=True) | Q(status="ESCALATED"))
            # Principal sees all complaints across departments

        elif role == "ADMISSION":
            # Admission officer sees admission-related or assigned complaints
            qs = qs.filter(
                Q(target_user=user)
                | Q(target_role="ADMISSION")
                | Q(category__code="ADMISSION")
                | Q(category_name__icontains="admission")
                | Q(submitted_by=user)
            ).distinct()

        elif role == "ACCOUNTS":
            # Accounts officer sees fee-related or assigned complaints
            qs = qs.filter(
                Q(target_user=user)
                | Q(target_role="ACCOUNTS")
                | Q(category__code="FEES")
                | Q(category_name__icontains="fee")
                | Q(submitted_by=user)
            ).distinct()

        elif role == "LIBRARY":
            # Library officer sees library-related or assigned complaints
            qs = qs.filter(
                Q(target_user=user)
                | Q(target_role="LIBRARY")
                | Q(category__code="LIBRARY")
                | Q(category_name__icontains="library")
                | Q(submitted_by=user)
            ).distinct()

        elif role == "SYSTEM":
            # System Admin: technical / system-related complaints or assigned complaints.
            # Do NOT grant unrestricted access to sensitive/confidential complaints merely because Admin!
            if getattr(user, "is_superuser", False):
                # Superuser can see complaints but confidential ones require explicit assignment unless leadership
                pass
            else:
                qs = qs.filter(
                    (Q(is_confidential=False) & (
                        Q(category__code="TECHNICAL")
                        | Q(target_role="SYSTEM")
                    ))
                    | Q(target_user=user)
                    | Q(submitted_by=user)
                ).distinct()

        else:
            # Fallback for any other user: only own submitted or assigned
            qs = qs.filter(Q(submitted_by=user) | Q(target_user=user))

        # ----------------------------------------
        # Additional URL Query Parameter Filters
        # ----------------------------------------
        category_param = self.request.query_params.get("category")
        if category_param:
            if category_param.isdigit():
                qs = qs.filter(category_id=int(category_param))
            else:
                qs = qs.filter(Q(category__code=category_param.upper()) | Q(category_name__iexact=category_param))

        status_param = self.request.query_params.get("status")
        if status_param:
            # Map legacy 'Pending' if needed
            if status_param.upper() == "PENDING":
                qs = qs.filter(Q(status="SUBMITTED") | Q(status="Pending"))
            else:
                qs = qs.filter(status__iexact=status_param)

        priority_param = self.request.query_params.get("priority")
        if priority_param:
            qs = qs.filter(priority__iexact=priority_param)

        department_param = self.request.query_params.get("department_id")
        if department_param:
            qs = qs.filter(department_id=department_param)

        search_query = self.request.query_params.get("search")
        if search_query:
            qs = qs.filter(
                Q(topic__icontains=search_query)
                | Q(description__icontains=search_query)
                | Q(student__name__icontains=search_query)
                | Q(student__usn__icontains=search_query)
                | Q(submitted_by__email__icontains=search_query)
            )

        overdue_param = self.request.query_params.get("is_overdue")
        if overdue_param and overdue_param.lower() in ["true", "1"]:
            # Complaints open past SLA (approx > 7 days)
            cutoff = timezone.now() - timedelta(days=7)
            qs = qs.filter(
                created_at__lt=cutoff,
                status__in=["SUBMITTED", "UNDER_REVIEW", "IN_PROGRESS", "AWAITING_INFO", "ESCALATED", "REOPENED", "Pending"]
            )

        return qs

    # -------------------------------------------------------------
    # 2. Creation Logic & Intelligent Role-Based Routing
    # -------------------------------------------------------------
    def perform_create(self, serializer):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()

        # Resolve student / department / faculty profile
        student = None
        department = user.department

        if role == "STUDENT":
            student = Student.objects.filter(user=user).first()
            if student and student.department:
                department = student.department
        elif role in ["PROFESSOR", "HOD"]:
            fac = Faculty.objects.filter(user=user).first()
            if fac and fac.department:
                department = fac.department

        category_id = self.request.data.get("category_id")
        category_name = self.request.data.get("category_name", "Academic")
        category_obj = None

        if category_id:
            category_obj = GrievanceCategory.objects.filter(id=category_id).first()
        if not category_obj and category_name:
            category_obj = GrievanceCategory.objects.filter(
                Q(code=category_name.upper()) | Q(name__iexact=category_name)
            ).first()

        if not category_obj and category_name and category_name.strip():
            # Create custom category automatically
            category_code = category_name.upper().replace(" ", "_")[:50]
            category_obj, _ = GrievanceCategory.objects.get_or_create(
                name=category_name.strip(),
                defaults={
                    "code": category_code,
                    "default_target_role": "HOD",
                    "sla_days": 7,
                    "is_active": True,
                }
            )

        if category_obj:
            category_name = category_obj.name

        # Priority & confidentiality
        priority = (self.request.data.get("priority") or "MEDIUM").upper()
        is_confidential = self.request.data.get("is_confidential")
        if isinstance(is_confidential, str):
            is_confidential = is_confidential.lower() in ["true", "1", "yes"]
        if category_obj and category_obj.is_confidential_by_default:
            is_confidential = True

        # Intelligent routing
        target_role = self.request.data.get("target_role")
        target_user_id = self.request.data.get("target_user")
        target_user = None

        if target_user_id:
            target_user = User.objects.filter(id=target_user_id, is_active=True).first()
            if target_user:
                target_role = target_user.role

        if not target_user:
            # Determine target role from category default if not provided
            if not target_role:
                target_role = category_obj.default_target_role if category_obj else "HOD"

            # Auto-assign active officer for role
            target_role = target_role.upper()
            if target_role == "HOD" and department:
                target_user = User.objects.filter(role="HOD", department=department, is_active=True).first()
                if not target_user:
                    # Look up by faculty profile department
                    fac_hod = Faculty.objects.filter(role="HOD", department=department, user__is_active=True).first()
                    if fac_hod and fac_hod.user:
                        target_user = fac_hod.user

            if not target_user and target_role in ["PRINCIPAL", "ADMISSION", "ACCOUNTS", "LIBRARY", "SYSTEM", "EXAM"]:
                target_user = User.objects.filter(role=target_role, is_active=True).first()

            # Fallback to Principal if no officer found or if Harassment
            if not target_user or (category_obj and category_obj.code == "HARASSMENT"):
                principal = User.objects.filter(role="PRINCIPAL", is_active=True).first()
                if principal:
                    target_user = principal
                    target_role = "PRINCIPAL"

        grievance = serializer.save(
            submitted_by=user,
            student=student,
            department=department,
            category=category_obj,
            category_name=category_name,
            priority=priority,
            target_role=target_role or "HOD",
            target_user=target_user,
            is_confidential=bool(is_confidential),
            status="SUBMITTED",
        )

        # Log creation activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="SUBMITTED",
            to_status="SUBMITTED",
            notes=f"Grievance filed under category '{category_name}'.",
            attachment=grievance.attachment if grievance.attachment else None,
        )

        # Send notification to assigned officer
        if target_user:
            send_grievance_notification(
                recipient=target_user,
                title=f"New Grievance Assigned: {grievance.topic}",
                message=f"A new {priority.lower()} priority grievance has been assigned to you by {user.email}."
            )

    # -------------------------------------------------------------
    # 3. Legacy 'respond' Action (Enhanced with activity & status)
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def respond(self, request, pk=None):
        grievance = self.get_object()
        user = request.user
        role = (getattr(user, "role", "") or "").upper()

        # Authorization: assigned officer, HOD of department, or Principal
        is_assigned = grievance.target_user_id == user.id
        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_principal = role == "PRINCIPAL" or user.is_superuser

        if not (is_assigned or is_hod or is_principal):
            return Response({"error": "You are not authorized to respond to this grievance."}, status=status.HTTP_403_FORBIDDEN)

        response_text = request.data.get("response") or request.data.get("remarks")
        if not response_text:
            return Response({"error": "Response/Remarks text is required."}, status=status.HTTP_400_BAD_REQUEST)

        grievance.response = response_text
        grievance.resolution_remarks = response_text
        old_status = grievance.status
        grievance.status = "RESOLVED"
        grievance.resolved_at = timezone.now()
        grievance.resolved_by = user
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="RESOLVED",
            from_status=old_status,
            to_status="RESOLVED",
            notes=response_text,
        )

        # Notify complainant
        complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
        if complainant:
            send_grievance_notification(
                recipient=complainant,
                title=f"Grievance Resolved: {grievance.topic}",
                message=f"Officer {user.email} responded and marked your grievance as Resolved: {response_text[:120]}"
            )

        return Response({"message": "Response recorded and grievance marked Resolved.", "status": "RESOLVED"})

    # -------------------------------------------------------------
    # 4. Status Update Action
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def update_status(self, request, pk=None):
        grievance = self.get_object()
        ser = StatusUpdateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        new_status = ser.validated_data["status"]
        notes = ser.validated_data.get("notes", "")
        attachment = ser.validated_data.get("attachment")

        is_assigned = grievance.target_user_id == user.id
        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_principal = role == "PRINCIPAL" or user.is_superuser
        is_complainant = (grievance.submitted_by_id == user.id) or (
            grievance.student and grievance.student.user_id == user.id
        )

        # Permission check
        if new_status == "CLOSED":
            if not (is_complainant or is_principal or is_assigned):
                return Response({"error": "Only complainant or authorized officer can close this grievance."}, status=status.HTTP_403_FORBIDDEN)
        else:
            if not (is_assigned or is_hod or is_principal):
                return Response({"error": "You do not have permission to update this grievance status."}, status=status.HTTP_403_FORBIDDEN)

        old_status = grievance.status
        grievance.status = new_status

        if new_status == "UNDER_REVIEW":
            pass
        elif new_status == "IN_PROGRESS":
            pass
        elif new_status == "RESOLVED":
            grievance.resolved_at = timezone.now()
            grievance.resolved_by = user
            if notes:
                grievance.resolution_remarks = notes
        elif new_status == "CLOSED":
            grievance.closed_at = timezone.now()
        elif new_status == "REJECTED":
            if not notes:
                return Response({"error": "A mandatory rejection reason is required."}, status=status.HTTP_400_BAD_REQUEST)
            grievance.rejection_reason = notes

        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="STATUS_CHANGED",
            from_status=old_status,
            to_status=new_status,
            notes=notes or f"Status changed to {new_status}.",
            attachment=attachment,
        )

        # Notify complainant
        complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
        if complainant and complainant != user:
            send_grievance_notification(
                recipient=complainant,
                title=f"Grievance Status: {new_status}",
                message=f"Your grievance '{grievance.topic}' has been updated to {new_status}. {notes[:100]}"
            )

        return Response({"message": f"Status updated to {new_status} successfully.", "status": new_status})

    # -------------------------------------------------------------
    # 5. Officer Assignment / Reassignment
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def assign(self, request, pk=None):
        grievance = self.get_object()
        ser = AssignOfficerSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        target_user_id = ser.validated_data["target_user_id"]
        notes = ser.validated_data.get("notes", "")

        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_principal = role == "PRINCIPAL" or user.is_superuser

        if not (is_hod or is_principal):
            return Response({"error": "Only HOD or Principal can reassign grievances."}, status=status.HTTP_403_FORBIDDEN)

        target_officer = User.objects.filter(id=target_user_id, is_active=True).first()
        if not target_officer:
            return Response({"error": "Target officer not found or inactive."}, status=status.HTTP_400_BAD_REQUEST)

        # If HOD, verify target officer is within HOD's department or HOD self
        if role == "HOD" and not is_principal:
            if target_officer != user and target_officer.department_id != user.department_id:
                fac = Faculty.objects.filter(user=target_officer, department=user.department).first()
                if not fac:
                    return Response({"error": "You can only assign complaints to faculty within your department."}, status=status.HTTP_403_FORBIDDEN)

        old_officer_name = grievance.target_user.email if grievance.target_user else "Unassigned"
        grievance.target_user = target_officer
        grievance.target_role = target_officer.role
        if grievance.status == "SUBMITTED":
            grievance.status = "UNDER_REVIEW"
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="ASSIGNED",
            from_status=grievance.status,
            to_status=grievance.status,
            notes=notes or f"Reassigned from {old_officer_name} to {target_officer.email} ({target_officer.role}).",
        )

        # Notify new officer
        send_grievance_notification(
            recipient=target_officer,
            title=f"Grievance Reassigned: {grievance.topic}",
            message=f"You have been assigned to handle grievance #{grievance.id} by {user.email}."
        )

        return Response({"message": f"Assigned to {target_officer.email} successfully."})

    # -------------------------------------------------------------
    # 6. Request Information (Officer -> Complainant)
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def request_info(self, request, pk=None):
        grievance = self.get_object()
        ser = RequestInfoSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        notes = ser.validated_data["notes"]

        is_assigned = grievance.target_user_id == user.id
        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_principal = role == "PRINCIPAL" or user.is_superuser

        if not (is_assigned or is_hod or is_principal):
            return Response({"error": "You are not authorized to request information on this grievance."}, status=status.HTTP_403_FORBIDDEN)

        old_status = grievance.status
        grievance.status = "AWAITING_INFO"
        grievance.info_requested_notes = notes
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="INFO_REQUESTED",
            from_status=old_status,
            to_status="AWAITING_INFO",
            notes=notes,
        )

        # Notify complainant
        complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
        if complainant:
            send_grievance_notification(
                recipient=complainant,
                title=f"Action Required: Information Requested for Grievance #{grievance.id}",
                message=f"Officer requested additional details: {notes[:120]}"
            )

        return Response({"message": "Information requested from complainant.", "status": "AWAITING_INFO"})

    # -------------------------------------------------------------
    # 7. Provide Information (Complainant -> Officer)
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def provide_info(self, request, pk=None):
        grievance = self.get_object()
        ser = ProvideInfoSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        is_complainant = (grievance.submitted_by_id == user.id) or (
            grievance.student and grievance.student.user_id == user.id
        )

        if not is_complainant:
            return Response({"error": "Only the complainant can submit additional information."}, status=status.HTTP_403_FORBIDDEN)

        notes = ser.validated_data["notes"]
        attachment = ser.validated_data.get("attachment")

        old_status = grievance.status
        grievance.status = "IN_PROGRESS"
        grievance.info_provided_notes = notes
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="INFO_PROVIDED",
            from_status=old_status,
            to_status="IN_PROGRESS",
            notes=notes,
            attachment=attachment,
        )

        # Notify assigned officer
        if grievance.target_user:
            send_grievance_notification(
                recipient=grievance.target_user,
                title=f"Information Provided for Grievance #{grievance.id}",
                message=f"Complainant responded to your information request: {notes[:120]}"
            )

        return Response({"message": "Additional information submitted successfully.", "status": "IN_PROGRESS"})

    # -------------------------------------------------------------
    # 8. Escalate Grievance
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def escalate(self, request, pk=None):
        grievance = self.get_object()
        ser = EscalateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        reason = ser.validated_data["reason"]
        dest_id = ser.validated_data.get("escalated_to_id")
        dest_role = ser.validated_data.get("destination_role", "PRINCIPAL").upper()

        is_assigned = grievance.target_user_id == user.id
        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_officer = role in ["ADMISSION", "ACCOUNTS", "LIBRARY", "PROFESSOR"] and is_assigned
        is_principal = role == "PRINCIPAL" or user.is_superuser

        if not (is_assigned or is_hod or is_officer or is_principal):
            return Response({"error": "You do not have permission to escalate this grievance."}, status=status.HTTP_403_FORBIDDEN)

        target_authority = None
        if dest_id:
            target_authority = User.objects.filter(id=dest_id, is_active=True).first()
        if not target_authority:
            # Default escalation destination is Principal
            target_authority = User.objects.filter(role=dest_role, is_active=True).first()
            if not target_authority and dest_role != "PRINCIPAL":
                target_authority = User.objects.filter(role="PRINCIPAL", is_active=True).first()

        old_status = grievance.status
        grievance.status = "ESCALATED"
        grievance.is_escalated = True
        grievance.escalated_to = target_authority
        grievance.escalated_at = timezone.now()
        grievance.escalation_reason = reason
        if target_authority:
            grievance.target_user = target_authority
            grievance.target_role = target_authority.role
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="ESCALATED",
            from_status=old_status,
            to_status="ESCALATED",
            notes=f"Escalated to {target_authority.email if target_authority else dest_role}. Reason: {reason}",
        )

        # Notify destination authority
        if target_authority:
            send_grievance_notification(
                recipient=target_authority,
                title=f"URGENT: Grievance #{grievance.id} Escalated",
                message=f"Grievance '{grievance.topic}' has been escalated to you by {user.email}. Reason: {reason[:120]}"
            )

        # Notify complainant
        complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
        if complainant:
            send_grievance_notification(
                recipient=complainant,
                title=f"Grievance Escalated: #{grievance.id}",
                message=f"Your grievance '{grievance.topic}' has been escalated to higher authority for resolution."
            )

        return Response({"message": "Grievance escalated successfully.", "status": "ESCALATED"})

    # -------------------------------------------------------------
    # 9. Resolve Grievance
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def resolve(self, request, pk=None):
        grievance = self.get_object()
        ser = ResolveSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        remarks = ser.validated_data["resolution_remarks"]
        attachment = ser.validated_data.get("attachment")

        is_assigned = grievance.target_user_id == user.id
        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_principal = role == "PRINCIPAL" or user.is_superuser

        if not (is_assigned or is_hod or is_principal):
            return Response({"error": "You are not authorized to resolve this grievance."}, status=status.HTTP_403_FORBIDDEN)

        old_status = grievance.status
        grievance.status = "RESOLVED"
        grievance.resolution_remarks = remarks
        grievance.response = remarks  # Legacy support
        grievance.resolved_at = timezone.now()
        grievance.resolved_by = user
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="RESOLVED",
            from_status=old_status,
            to_status="RESOLVED",
            notes=remarks,
            attachment=attachment,
        )

        # Notify complainant
        complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
        if complainant:
            send_grievance_notification(
                recipient=complainant,
                title=f"Grievance Resolved: {grievance.topic}",
                message=f"Your grievance has been resolved. Remarks: {remarks[:140]}"
            )

        return Response({"message": "Grievance marked as Resolved successfully.", "status": "RESOLVED"})

    # -------------------------------------------------------------
    # 10. Reject Grievance
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def reject(self, request, pk=None):
        grievance = self.get_object()
        ser = RejectSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        reason = ser.validated_data["rejection_reason"]

        is_assigned = grievance.target_user_id == user.id
        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_principal = role == "PRINCIPAL" or user.is_superuser

        if not (is_assigned or is_hod or is_principal):
            return Response({"error": "You are not authorized to reject this grievance."}, status=status.HTTP_403_FORBIDDEN)

        old_status = grievance.status
        grievance.status = "REJECTED"
        grievance.rejection_reason = reason
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="REJECTED",
            from_status=old_status,
            to_status="REJECTED",
            notes=f"Grievance rejected. Reason: {reason}",
        )

        # Notify complainant
        complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
        if complainant:
            send_grievance_notification(
                recipient=complainant,
                title=f"Grievance Rejected: #{grievance.id}",
                message=f"Your grievance '{grievance.topic}' was rejected. Reason: {reason}"
            )

        return Response({"message": "Grievance has been rejected.", "status": "REJECTED"})

    # -------------------------------------------------------------
    # 11. Request Reopen (Complainant)
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def request_reopen(self, request, pk=None):
        grievance = self.get_object()
        ser = ReopenRequestSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        is_complainant = (grievance.submitted_by_id == user.id) or (
            grievance.student and grievance.student.user_id == user.id
        )

        if not is_complainant:
            return Response({"error": "Only the complainant can request reopening of this grievance."}, status=status.HTTP_403_FORBIDDEN)

        if grievance.status not in ["RESOLVED", "CLOSED", "REJECTED"]:
            return Response({"error": "Only resolved, closed or rejected grievances can be requested to reopen."}, status=status.HTTP_400_BAD_REQUEST)

        reason = ser.validated_data["reason"]
        grievance.reopen_requested = True
        grievance.reopen_request_reason = reason
        grievance.reopen_requested_at = timezone.now()
        grievance.save()

        # Log activity
        GrievanceActivity.objects.create(
            grievance=grievance,
            actor=user,
            action="REOPEN_REQUESTED",
            from_status=grievance.status,
            to_status=grievance.status,
            notes=f"Complainant requested reopening: {reason}",
        )

        # Notify officer
        if grievance.target_user:
            send_grievance_notification(
                recipient=grievance.target_user,
                title=f"Reopen Request on Grievance #{grievance.id}",
                message=f"Complainant requested reopening: {reason[:120]}"
            )

        return Response({"message": "Reopening request submitted for officer review."})

    # -------------------------------------------------------------
    # 12. Review Reopen Request (Officer / Principal)
    # -------------------------------------------------------------
    @action(detail=True, methods=["post"])
    def reopen(self, request, pk=None):
        grievance = self.get_object()
        ser = ReopenReviewSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user = request.user
        role = (getattr(user, "role", "") or "").upper()
        decision = ser.validated_data["decision"]
        notes = ser.validated_data.get("notes", "")

        is_assigned = grievance.target_user_id == user.id
        is_hod = role == "HOD" and grievance.department_id and user.department_id == grievance.department_id
        is_principal = role == "PRINCIPAL" or user.is_superuser

        if not (is_assigned or is_hod or is_principal):
            return Response({"error": "You do not have authority to review reopen requests."}, status=status.HTTP_403_FORBIDDEN)

        old_status = grievance.status

        if decision == "APPROVE":
            grievance.status = "REOPENED"
            grievance.is_reopened = True
            grievance.reopened_at = timezone.now()
            grievance.reopened_by = user
            grievance.reopen_requested = False
            grievance.save()

            GrievanceActivity.objects.create(
                grievance=grievance,
                actor=user,
                action="REOPENED",
                from_status=old_status,
                to_status="REOPENED",
                notes=notes or "Reopen request approved. Investigation resumed.",
            )

            # Notify complainant
            complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
            if complainant:
                send_grievance_notification(
                    recipient=complainant,
                    title=f"Grievance Reopened: #{grievance.id}",
                    message=f"Your grievance has been reopened by {user.email}. Investigation has resumed."
                )

            return Response({"message": "Grievance has been reopened.", "status": "REOPENED"})
        else:
            grievance.reopen_requested = False
            grievance.save()

            GrievanceActivity.objects.create(
                grievance=grievance,
                actor=user,
                action="REOPEN_REJECTED",
                from_status=old_status,
                to_status=old_status,
                notes=notes or "Reopen request rejected by officer.",
            )

            complainant = grievance.submitted_by or (grievance.student.user if grievance.student else None)
            if complainant:
                send_grievance_notification(
                    recipient=complainant,
                    title=f"Reopen Request Declined: #{grievance.id}",
                    message=f"Reopen request was declined. Notes: {notes}"
                )

            return Response({"message": "Reopening request declined."})

    # -------------------------------------------------------------
    # 13. System Metrics & Stats Overview
    # -------------------------------------------------------------
    @action(detail=False, methods=["get"])
    def stats(self, request):
        qs = self.get_queryset()

        total = qs.count()
        submitted = qs.filter(Q(status="SUBMITTED") | Q(status="Pending")).count()
        under_review = qs.filter(status="UNDER_REVIEW").count()
        in_progress = qs.filter(status="IN_PROGRESS").count()
        awaiting_info = qs.filter(status="AWAITING_INFO").count()
        resolved = qs.filter(status="RESOLVED").count()
        closed = qs.filter(status="CLOSED").count()
        rejected = qs.filter(status="REJECTED").count()
        escalated = qs.filter(Q(status="ESCALATED") | Q(is_escalated=True)).count()
        reopened = qs.filter(Q(status="REOPENED") | Q(is_reopened=True)).count()

        # Overdue SLA (> 7 days for open complaints)
        cutoff = timezone.now() - timedelta(days=7)
        overdue = qs.filter(
            created_at__lt=cutoff,
            status__in=["SUBMITTED", "UNDER_REVIEW", "IN_PROGRESS", "AWAITING_INFO", "ESCALATED", "REOPENED", "Pending"]
        ).count()

        # Groupings
        by_priority = {
            "LOW": qs.filter(priority="LOW").count(),
            "MEDIUM": qs.filter(priority="MEDIUM").count(),
            "HIGH": qs.filter(priority="HIGH").count(),
            "URGENT": qs.filter(priority="URGENT").count(),
        }

        by_category = []
        for cat in GrievanceCategory.objects.filter(is_active=True):
            count = qs.filter(category=cat).count()
            if count > 0:
                by_category.append({
                    "code": cat.code,
                    "name": cat.name,
                    "count": count,
                })

        by_department = []
        for dept in Department.objects.all():
            count = qs.filter(department=dept).count()
            if count > 0:
                by_department.append({
                    "id": dept.id,
                    "name": dept.name,
                    "count": count,
                })

        return Response({
            "total": total,
            "submitted": submitted,
            "under_review": under_review,
            "in_progress": in_progress,
            "awaiting_info": awaiting_info,
            "resolved": resolved,
            "closed": closed,
            "rejected": rejected,
            "escalated": escalated,
            "reopened": reopened,
            "overdue": overdue,
            "by_priority": by_priority,
            "by_category": by_category,
            "by_department": by_department,
        })

    # -------------------------------------------------------------
    # 14. Eligible Officers List (for Assignment / Escalation)
    # -------------------------------------------------------------
    @action(detail=False, methods=["get"])
    def officers(self, request):
        user = request.user
        role = (getattr(user, "role", "") or "").upper()

        officer_qs = User.objects.filter(
            is_active=True,
            role__in=["PRINCIPAL", "HOD", "PROFESSOR", "ADMISSION", "ACCOUNTS", "LIBRARY", "SYSTEM"]
        ).select_related("department")

        # If HOD, can select faculty within their department or Principal
        if role == "HOD" and not user.is_superuser:
            dept = user.department
            if dept:
                officer_qs = officer_qs.filter(
                    Q(department=dept) | Q(role="PRINCIPAL")
                )

        results = []
        for u in officer_qs[:50]:
            name = getattr(u, "name", None) or u.email
            fac = Faculty.objects.filter(user=u).first()
            if fac:
                name = fac.name
            results.append({
                "id": u.id,
                "name": name,
                "email": u.email,
                "role": u.role,
                "department": getattr(u.department, "name", None) if u.department else None,
            })

        return Response(results)
