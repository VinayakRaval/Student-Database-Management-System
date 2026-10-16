from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.utils import timezone
from django.db.models import Q
from django.contrib.auth import get_user_model

from .models import Announcement, Notification
from .serializers import AnnouncementSerializer, NotificationSerializer
from timetable.views import _resolve_department_for_user, _resolve_faculty_for_user
from students.models import Student

User = get_user_model()


class AnnouncementViewSet(viewsets.ModelViewSet):
    serializer_class = AnnouncementSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        qs = Announcement.objects.filter(is_archived=False)

        # Principal & Superuser can see everything
        if role in ["PRINCIPAL", "SYSTEM"] or user.is_superuser:
            pass
        elif role == "HOD":
            dept = _resolve_department_for_user(user)
            if dept:
                qs = qs.filter(Q(department=dept) | Q(department__isnull=True))
            else:
                qs = qs.filter(department__isnull=True)
        elif role == "PROFESSOR":
            fac = _resolve_faculty_for_user(user)
            fac_dept = fac.department if fac else getattr(user, "department", None)
            dept_q = Q(department=fac_dept) if fac_dept else Q()
            now = timezone.now()
            qs = qs.filter(
                (dept_q | Q(department__isnull=True)),
                is_published=True,
                publish_date__lte=now
            ).exclude(target_audience="STUDENTS").filter(
                Q(expiry_date__isnull=True) | Q(expiry_date__gte=now)
            )
        elif role == "STUDENT":
            student = getattr(user, "student", None)
            if not student:
                student = Student.objects.filter(user=user).first()
            now = timezone.now()
            if student:
                qs = qs.filter(
                    (Q(department=student.department) | Q(department__isnull=True)),
                    (Q(target_semester=student.semester) | Q(target_semester__isnull=True)),
                    is_published=True,
                    publish_date__lte=now
                ).exclude(target_audience="FACULTY").filter(
                    Q(expiry_date__isnull=True) | Q(expiry_date__gte=now)
                )
            else:
                qs = qs.filter(
                    department__isnull=True,
                    is_published=True,
                    publish_date__lte=now
                ).exclude(target_audience="FACULTY").filter(
                    Q(expiry_date__isnull=True) | Q(expiry_date__gte=now)
                )
        else:
            # ACCOUNTS or other roles
            now = timezone.now()
            qs = qs.filter(
                department__isnull=True,
                is_published=True,
                publish_date__lte=now
            ).filter(
                Q(expiry_date__isnull=True) | Q(expiry_date__gte=now)
            )

        # Filters
        category = self.request.query_params.get("category")
        if category:
            qs = qs.filter(category__iexact=category)

        priority = self.request.query_params.get("priority")
        if priority:
            qs = qs.filter(priority__iexact=priority)

        dept_id = self.request.query_params.get("department_id")
        if dept_id:
            qs = qs.filter(department_id=dept_id)

        # Status filter: ALL, PUBLISHED, DRAFT, SCHEDULED, EXPIRED
        status_filter = (self.request.query_params.get("status_filter") or "").upper()
        now = timezone.now()
        if status_filter == "DRAFT":
            qs = qs.filter(is_published=False)
        elif status_filter == "PUBLISHED":
            qs = qs.filter(is_published=True, publish_date__lte=now).filter(Q(expiry_date__isnull=True) | Q(expiry_date__gte=now))
        elif status_filter == "SCHEDULED":
            qs = qs.filter(is_published=True, publish_date__gt=now)
        elif status_filter == "EXPIRED":
            qs = qs.filter(expiry_date__lt=now)

        return qs.order_by("-publish_date", "-created_at")

    def perform_create(self, serializer):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        if role == "HOD":
            dept = _resolve_department_for_user(user)
            if not dept:
                raise PermissionDenied("HOD must belong to an active department to publish announcements.")
            announcement = serializer.save(created_by=user, department=dept)
        elif role in ["PRINCIPAL", "SYSTEM"] or user.is_superuser:
            announcement = serializer.save(created_by=user)
        else:
            raise PermissionDenied("Only HOD and Principal can create announcements.")

        # Trigger notification dispatch if published and notifications enabled
        if announcement.is_published and announcement.notify_users:
            self._dispatch_notifications(announcement)

    def update(self, request, *args, **kwargs):
        kwargs['partial'] = True
        return super().update(request, *args, **kwargs)

    def perform_update(self, serializer):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        instance = self.get_object()
        if role == "HOD":
            dept = _resolve_department_for_user(user)
            if not dept or instance.department_id != dept.id:
                raise PermissionDenied("You can only edit announcements for your own department.")
        elif role not in ["PRINCIPAL", "SYSTEM"] and not user.is_superuser:
            raise PermissionDenied("You do not have permission to edit announcements.")

        remove_image = str(self.request.data.get("remove_image", "")).lower() in ["true", "1"]
        remove_attachment = str(self.request.data.get("remove_attachment", "")).lower() in ["true", "1"]

        announcement = serializer.save()
        if remove_image and announcement.image:
            announcement.image.delete(save=False)
            announcement.image = None
            announcement.save(update_fields=["image"])
        if remove_attachment and announcement.attachment:
            announcement.attachment.delete(save=False)
            announcement.attachment = None
            announcement.save(update_fields=["attachment"])

    def perform_destroy(self, instance):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        if role == "HOD":
            dept = _resolve_department_for_user(user)
            if not dept or instance.department_id != dept.id:
                raise PermissionDenied("You can only delete announcements for your own department.")
            instance.delete()
        elif role in ["PRINCIPAL", "SYSTEM"] or user.is_superuser:
            instance.delete()
        else:
            raise PermissionDenied("You do not have permission to delete announcements.")

    def _dispatch_notifications(self, announcement):
        """Creates Notification records for intended audience."""
        try:
            target_users = User.objects.filter(is_active=True).exclude(id=announcement.created_by_id)

            if announcement.department:
                target_users = target_users.filter(
                    Q(department=announcement.department) |
                    Q(faculty_profile__department=announcement.department) |
                    Q(student__department=announcement.department)
                )

            # Target Audience filter: STUDENTS, FACULTY, BOTH
            if announcement.target_audience == "STUDENTS":
                target_users = target_users.filter(role__iexact="STUDENT")
            elif announcement.target_audience == "FACULTY":
                target_users = target_users.filter(role__in=["PROFESSOR", "FACULTY", "HOD"])

            # Semester filtering for students
            if announcement.target_semester:
                target_users = target_users.filter(
                    Q(role__in=["PROFESSOR", "FACULTY", "HOD", "PRINCIPAL"]) |
                    Q(student__semester=announcement.target_semester)
                )

            notifications = [
                Notification(
                    recipient=u,
                    announcement=announcement,
                    title=f"[{announcement.category}] {announcement.title}",
                    message=announcement.content[:160] + ("..." if len(announcement.content) > 160 else ""),
                    notification_type="ANNOUNCEMENT",
                )
                for u in target_users.distinct()[:500]  # Safe batch
            ]
            if notifications:
                Notification.objects.bulk_create(notifications)
        except Exception as e:
            import logging
            logging.getLogger(__name__).exception("Failed to dispatch notifications: %s", e)


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user).order_by("-created_at")

    @action(detail=False, methods=["get"])
    def unread_count(self, request):
        count = self.get_queryset().filter(is_read=False).count()
        return Response({"unread_count": count})

    @action(detail=True, methods=["post"])
    def mark_read(self, request, pk=None):
        notif = self.get_object()
        if not notif.is_read:
            notif.is_read = True
            notif.read_at = timezone.now()
            notif.save(update_fields=["is_read", "read_at"])
        return Response({"status": "success", "is_read": True})

    @action(detail=False, methods=["post"])
    def mark_all_read(self, request):
        updated = self.get_queryset().filter(is_read=False).update(
            is_read=True,
            read_at=timezone.now()
        )
        return Response({"status": "success", "marked_read_count": updated})
