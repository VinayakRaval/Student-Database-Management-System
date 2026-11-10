from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied, ValidationError
from django.utils import timezone
from django.db import transaction
from django.db.models import Q

from .models import CorrectionRequest, CorrectionRequestHistory, CATEGORY_CHOICES, STATUS_CHOICES
from .serializers import (
    CorrectionRequestListSerializer,
    CorrectionRequestDetailSerializer,
    CorrectionRequestCreateSerializer,
)
from .routing import determine_initial_routing
from timetable.views import _resolve_department_for_user, _resolve_faculty_for_user
from students.models import Student


class CorrectionRequestViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.action == 'create':
            return CorrectionRequestCreateSerializer
        elif self.action == 'retrieve':
            return CorrectionRequestDetailSerializer
        return CorrectionRequestListSerializer

    def get_queryset(self):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        qs = CorrectionRequest.objects.all().select_related(
            'student', 'student__department', 'student__semester', 'assigned_department'
        )

        if role == "STUDENT":
            stu = Student.objects.filter(user=user).first()
            if not stu:
                return CorrectionRequest.objects.none()
            qs = qs.filter(student=stu)

        elif role == "HOD":
            dept = _resolve_department_for_user(user)
            if not dept:
                return CorrectionRequest.objects.none()
            # HOD can ONLY see requests for their own department
            qs = qs.filter(
                Q(assigned_department=dept) | Q(student__department=dept)
            )

        elif role == "ADMISSION":
            qs = qs.filter(
                Q(assigned_role='ADMISSION') | Q(category__in=['PERSONAL', 'ADMISSION_USN', 'DOCUMENTS'])
            )

        elif role == "ACCOUNTS":
            qs = qs.filter(
                Q(assigned_role='ACCOUNTS') | Q(category='FEES')
            )

        elif role == "LIBRARY":
            qs = qs.filter(
                Q(assigned_role='LIBRARY') | Q(category='LIBRARY')
            )

        elif role in ["PROFESSOR", "FACULTY"]:
            fac = _resolve_faculty_for_user(user)
            if fac:
                # Assigned directly, or attendance/IA for department or teaching subjects
                from subjects.models import SubjectAssignment
                taught_sub_ids = list(SubjectAssignment.objects.filter(faculty=fac).values_list('subject_id', flat=True))
                qs = qs.filter(
                    Q(assigned_to=user) |
                    (Q(assigned_role='PROFESSOR') & (
                        Q(assigned_department=fac.department) |
                        Q(student__department=fac.department)
                    ))
                )
            else:
                return CorrectionRequest.objects.none()

        elif role in ["PRINCIPAL", "SYSTEM"] or user.is_staff or user.is_superuser:
            pass  # Full access

        else:
            return CorrectionRequest.objects.none()

        # Filters
        status_param = self.request.query_params.get('status')
        if status_param and status_param.upper() != 'ALL':
            qs = qs.filter(status=status_param.upper())

        category_param = self.request.query_params.get('category')
        if category_param and category_param.upper() != 'ALL':
            qs = qs.filter(category=category_param.upper())

        search = self.request.query_params.get('search')
        if search:
            q = search.strip()
            qs = qs.filter(
                Q(request_id__icontains=q) |
                Q(student__name__icontains=q) |
                Q(student__usn__icontains=q) |
                Q(target_record_ref__icontains=q)
            )

        return qs

    def perform_create(self, serializer):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role != "STUDENT":
            raise PermissionDenied("Only students can submit correction requests.")

        student = Student.objects.filter(user=user).first()
        if not student:
            raise ValidationError({"student": "No active student profile found for this account."})

        category = serializer.validated_data.get('category')
        assigned_role, assigned_dept = determine_initial_routing(category, student)

        with transaction.atomic():
            instance = serializer.save(
                student=student,
                status='SUBMITTED',
                assigned_role=assigned_role,
                assigned_department=assigned_dept,
            )
            CorrectionRequestHistory.objects.create(
                request=instance,
                actor=user,
                action='SUBMITTED',
                from_status='',
                to_status='SUBMITTED',
                comments=f"Correction request submitted under '{instance.get_category_display()}'.",
                timestamp=timezone.now(),
            )

    @action(detail=True, methods=['post'])
    def review(self, request, pk=None):
        """
        Reviewer actions: approve, reject, request_info, forward.
        Enforces department-level permissions and mandatory rejection reason.
        """
        correction_req = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()

        if user_role == "STUDENT":
            raise PermissionDenied("Students cannot review correction requests.")

        if user_role == "HOD":
            dept = _resolve_department_for_user(user)
            if dept and correction_req.student.department_id != dept.id and (correction_req.assigned_department_id and correction_req.assigned_department_id != dept.id):
                raise PermissionDenied("You can only review requests for your department.")

        review_action = (request.data.get('action') or '').lower()
        comments = (request.data.get('comments') or '').strip()
        rejection_reason = (request.data.get('rejection_reason') or request.data.get('reason') or '').strip()

        from_status = correction_req.status

        with transaction.atomic():
            if review_action == 'approve':
                correction_req.status = 'APPROVED'
                correction_req.reviewer_comments = comments
                action_type = 'APPROVED'
                note = comments or "Request approved by reviewer."

            elif review_action == 'reject':
                if not rejection_reason:
                    raise ValidationError({"rejection_reason": "A reason is mandatory when rejecting a correction request."})
                correction_req.status = 'REJECTED'
                correction_req.rejection_reason = rejection_reason
                correction_req.reviewer_comments = comments
                action_type = 'REJECTED'
                note = f"Rejected: {rejection_reason}"

            elif review_action == 'request_info':
                if not comments:
                    raise ValidationError({"comments": "Please specify what additional information is required."})
                correction_req.status = 'MORE_INFO_REQUIRED'
                correction_req.reviewer_comments = comments
                action_type = 'INFO_REQUESTED'
                note = f"More info requested: {comments}"

            elif review_action == 'forward':
                forward_role = request.data.get('forward_role') or 'HOD'
                correction_req.status = 'FORWARDED'
                correction_req.assigned_role = forward_role
                correction_req.reviewer_comments = comments
                action_type = 'FORWARDED'
                note = f"Forwarded to {forward_role}. {comments}".strip()

            else:
                raise ValidationError({"action": "Invalid action. Choose from 'approve', 'reject', 'request_info', 'forward'."})

            correction_req.save()

            CorrectionRequestHistory.objects.create(
                request=correction_req,
                actor=user,
                action=action_type,
                from_status=from_status,
                to_status=correction_req.status,
                comments=note,
                timestamp=timezone.now(),
            )

        serializer = CorrectionRequestDetailSerializer(correction_req)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        """
        Marks an approved or reviewed correction request as COMPLETED after the actual record update.
        """
        correction_req = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()

        if user_role == "STUDENT":
            raise PermissionDenied("Students cannot resolve requests.")

        resolution_notes = (request.data.get('resolution_notes') or request.data.get('notes') or '').strip()
        from_status = correction_req.status

        with transaction.atomic():
            correction_req.status = 'COMPLETED'
            correction_req.resolved_at = timezone.now()
            correction_req.resolution_notes = resolution_notes or "Record verified and correction successfully completed."
            correction_req.save()

            CorrectionRequestHistory.objects.create(
                request=correction_req,
                actor=user,
                action='RESOLVED',
                from_status=from_status,
                to_status='COMPLETED',
                comments=correction_req.resolution_notes,
                timestamp=timezone.now(),
            )

        serializer = CorrectionRequestDetailSerializer(correction_req)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        """
        Allows student to reply when additional information is requested.
        """
        correction_req = self.get_object()
        user = request.user

        if correction_req.student.user_id != user.id:
            raise PermissionDenied("You can only respond to your own correction request.")

        if correction_req.status != 'MORE_INFO_REQUIRED':
            raise ValidationError({"error": "Can only respond when status is 'MORE_INFO_REQUIRED'."})

        response_text = (request.data.get('response') or request.data.get('comments') or '').strip()
        if not response_text:
            raise ValidationError({"response": "Please provide your clarification response."})

        from_status = correction_req.status
        with transaction.atomic():
            correction_req.status = 'PENDING_REVIEW'
            correction_req.save()

            CorrectionRequestHistory.objects.create(
                request=correction_req,
                actor=user,
                action='REVIEWED',
                from_status=from_status,
                to_status='PENDING_REVIEW',
                comments=f"Student Response: {response_text}",
                timestamp=timezone.now(),
            )

        serializer = CorrectionRequestDetailSerializer(correction_req)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def categories(self, request):
        """
        Returns all supported correction categories and their display labels.
        """
        data = [{'code': code, 'label': label} for code, label in CATEGORY_CHOICES]
        return Response(data)
