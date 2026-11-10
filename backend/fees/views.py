import csv
from decimal import Decimal
from django.db import transaction, models
from django.db.models import Sum, Count, Q
from django.utils import timezone
from django.http import HttpResponse
from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from students.models import Student
from academics.models import Department, Semester, AcademicYear
from .models import FeeStructure, StudentFee, FeePayment, FeeReceipt, PaymentMode
from .serializers import (
    FeeStructureSerializer,
    StudentFeeSerializer,
    FeePaymentSerializer,
    FeeReceiptSerializer,
)


def send_fee_notification(user_id, title, message, notif_type="GENERAL"):
    """Helper to send in-app notification to a user safely without throwing errors."""
    try:
        from announcements.models import Notification
        Notification.objects.create(
            recipient_id=user_id,
            title=title,
            message=message,
            notification_type=notif_type,
        )
    except Exception:
        pass


class IsRole(permissions.BasePermission):
    """
    Allows access only to users with specific roles, staff, or superusers.
    """
    allowed_roles = []

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_staff or request.user.is_superuser:
            return True
        allowed = getattr(view, "allowed_roles", self.allowed_roles)
        user_role = getattr(request.user, "role", "") or ""
        return user_role in allowed or user_role.upper() in [r.upper() for r in allowed]


class IsAccounts(IsRole):
    allowed_roles = ["ACCOUNTS"]


class IsPrincipal(IsRole):
    allowed_roles = ["PRINCIPAL"]


# ---------- FeeStructure ----------
class FeeStructureViewSet(viewsets.ModelViewSet):
    queryset = FeeStructure.objects.prefetch_related("components")
    serializer_class = FeeStructureSerializer

    def get_permissions(self):
        """Make list and retrieve publicly accessible (AllowAny)."""
        if self.action in ["list", "retrieve"]:
            return [AllowAny()]
        return super().get_permissions()

    def get_queryset(self):
        qs = FeeStructure.objects.select_related(
            "department", "academic_year", "semester", "created_by", "approved_by"
        ).prefetch_related("components")

        dept_id = self.request.query_params.get("department")
        if dept_id:
            qs = qs.filter(department_id=dept_id)

        sem_id = self.request.query_params.get("semester")
        if sem_id:
            qs = qs.filter(semester_id=sem_id)

        ay_id = self.request.query_params.get("academic_year")
        if ay_id:
            qs = qs.filter(academic_year_id=ay_id)

        status_param = self.request.query_params.get("status")
        if status_param and status_param.lower() != "all":
            qs = qs.filter(approval_status__iexact=status_param.lower())

        search = self.request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(title__icontains=search) |
                Q(department__name__icontains=search) |
                Q(academic_year__year_name__icontains=search)
            )

        return qs

    def perform_create(self, serializer):
        user = self.request.user if (self.request.user and self.request.user.is_authenticated) else None
        serializer.save(created_by=user)

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def approve(self, request, pk=None):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role != "PRINCIPAL" and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Principal can approve."}, status=403)

        fs = self.get_object()

        fs.approval_status = "approved"
        fs.is_active = True
        fs.approved_by = request.user
        fs.approved_on = timezone.now()
        fs.save()

        seat_map = {
            "gm": "general_merit",
            "general_merit": "general_merit",
            "snq": "snq",
            "lateral": "lateral",
            "Lateral": "lateral",
            "management": "management",
            "nri": "nri",
        }
        student_seat_type = seat_map.get(fs.seat_type, fs.seat_type)

        students = Student.objects.filter(
            department=fs.department,
            semester=fs.semester,
            academic_year=fs.academic_year,
            seat_type=student_seat_type,
            status__iexact="active",
        )

        created = 0
        for s in students:
            sf_obj, was_created = StudentFee.objects.get_or_create(student=s, fee_structure=fs)
            if was_created:
                created += 1
                if getattr(s, "user_id", None):
                    send_fee_notification(
                        s.user_id,
                        "Fee Structure Assigned",
                        f"Fee structure for Semester {fs.semester.sem_number} ({fs.get_seat_type_display()}) has been assigned. Total Amount: ₹{fs.total_amount:,.2f}."
                    )

        # Notify the Accounts Officer who created the structure
        if fs.created_by_id:
            send_fee_notification(
                fs.created_by_id,
                "Fee Structure Approved by Principal",
                f"Principal {request.user.email} approved fee structure '{fs.title}' ({fs.department.name}, Semester {fs.semester.sem_number}). Total: ₹{fs.total_amount:,.2f}. Assigned to {students.count()} students.",
                notif_type="ANNOUNCEMENT"
            )
        from django.contrib.auth import get_user_model
        for u in get_user_model().objects.filter(role__iexact="ACCOUNTS"):
            if u.id != fs.created_by_id:
                send_fee_notification(
                    u.id,
                    "Fee Structure Approved by Principal",
                    f"Principal {request.user.email} approved fee structure '{fs.title}' ({fs.department.name}, Semester {fs.semester.sem_number}). Total: ₹{fs.total_amount:,.2f}.",
                    notif_type="ANNOUNCEMENT"
                )

        return Response({
            "status": "approved",
            "assigned_to": students.count(),
            "created": created,
        }, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def reject(self, request, pk=None):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role != "PRINCIPAL" and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Principal can reject."}, status=403)

        fs = self.get_object()

        remark = request.data.get("remark", "").strip()
        if not remark:
            return Response({"detail": "Remark is required when rejecting."}, status=400)

        fs.approval_status = "rejected"
        fs.is_active = False
        fs.rejected_by = request.user
        fs.rejected_on = timezone.now()
        fs.rejection_remark = remark
        fs.save()

        # Notify Accounts Officers
        if fs.created_by_id:
            send_fee_notification(
                fs.created_by_id,
                "Fee Structure Returned by Principal",
                f"Principal {request.user.email} returned fee structure '{fs.title}' for corrections. Remark: '{remark}'.",
                notif_type="ANNOUNCEMENT"
            )
        from django.contrib.auth import get_user_model
        for u in get_user_model().objects.filter(role__iexact="ACCOUNTS"):
            if u.id != fs.created_by_id:
                send_fee_notification(
                    u.id,
                    "Fee Structure Returned by Principal",
                    f"Fee structure '{fs.title}' returned for corrections. Remark: '{remark}'.",
                    notif_type="ANNOUNCEMENT"
                )

        return Response({
            "status": "rejected",
            "remark": remark,
            "message": "Fee structure rejected successfully."
        }, status=200)


# ---------- StudentFee ----------
class StudentFeeViewSet(viewsets.ModelViewSet):
    queryset = StudentFee.objects.select_related("student", "fee_structure")
    serializer_class = StudentFeeSerializer

    def get_permissions(self):
        if self.action in ["bulk_assign", "apply_concession"]:
            return [permissions.IsAuthenticated()]
        return [permissions.AllowAny()]

    def get_queryset(self):
        qs = StudentFee.objects.select_related(
            "student",
            "student__department",
            "fee_structure",
            "fee_structure__semester",
            "fee_structure__academic_year",
            "concession_approved_by",
        ).prefetch_related(
            "fee_structure__components",
            "payments",
            "payments__receipt",
        )

        search = self.request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(student__usn__icontains=search) |
                Q(student__first_name__icontains=search) |
                Q(student__last_name__icontains=search) |
                Q(student__email__icontains=search)
            )

        dept_id = self.request.query_params.get("department")
        if dept_id:
            qs = qs.filter(student__department_id=dept_id)

        sem_id = self.request.query_params.get("semester")
        if sem_id:
            qs = qs.filter(fee_structure__semester_id=sem_id)

        academic_year_id = self.request.query_params.get("academic_year")
        if academic_year_id:
            qs = qs.filter(fee_structure__academic_year_id=academic_year_id)

        seat_type = self.request.query_params.get("seat_type")
        if seat_type:
            qs = qs.filter(fee_structure__seat_type__iexact=seat_type)

        fee_status = self.request.query_params.get("status")
        if fee_status:
            qs = qs.filter(status__iexact=fee_status)

        return qs

    # ----------------- Bulk Assign for Staff -----------------
    @action(detail=False, methods=["post"], url_path="bulk-assign")
    @transaction.atomic
    def bulk_assign(self, request):
        role = getattr(request.user, "role", "") or ""
        if role.upper() not in ["ACCOUNTS", "PRINCIPAL"] and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Accounts or Principal can assign fees."}, status=403)

        dept_id = request.data.get("department_id")
        sem_id = request.data.get("semester_id")
        ay_id = request.data.get("academic_year")
        seat_type = request.data.get("seat_type")
        fs_id = request.data.get("fee_structure_id")

        if not all([dept_id, sem_id, ay_id, seat_type, fs_id]):
            return Response({"detail": "All fields are required."}, status=400)

        try:
            department = Department.objects.get(id=dept_id)
            semester = Semester.objects.get(id=sem_id)
            academic_year = AcademicYear.objects.get(id=ay_id)
            fee_struct = FeeStructure.objects.get(id=fs_id, approval_status="approved")
        except Exception:
            return Response({"detail": "Invalid IDs or fee structure not approved."}, status=400)

        students = Student.objects.filter(
            department=department,
            semester=semester,
            status__iexact="active",
            seat_type=seat_type,
        )

        created = 0
        for s in students:
            obj, was_created = StudentFee.objects.get_or_create(student=s, fee_structure=fee_struct)
            if was_created:
                created += 1
                if getattr(s, "user_id", None):
                    send_fee_notification(
                        s.user_id,
                        "Fee Assigned",
                        f"Fee structure for Semester {fee_struct.semester.sem_number} assigned. Total: ₹{fee_struct.total_amount:,.2f}."
                    )

        return Response({"assigned_to": students.count(), "created": created})

    # ----------------- Apply Concession / Scholarship -----------------
    @action(detail=True, methods=["post"], url_path="apply-concession")
    @transaction.atomic
    def apply_concession(self, request, pk=None):
        role = getattr(request.user, "role", "") or ""
        if role.upper() not in ["ACCOUNTS", "PRINCIPAL"] and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Accounts or Principal can apply concessions."}, status=403)

        sf = self.get_object()
        try:
            amount = float(request.data.get("concession_amount", 0))
        except (ValueError, TypeError):
            return Response({"detail": "Invalid concession amount."}, status=400)

        if amount < 0:
            return Response({"detail": "Concession amount cannot be negative."}, status=400)

        if amount > float(sf.total_amount):
            return Response({
                "detail": f"Concession amount (₹{amount}) cannot exceed total fee (₹{sf.total_amount})."
            }, status=400)

        reason = request.data.get("concession_reason", "").strip() or "Fee Concession / Scholarship"

        sf.concession_amount = amount
        sf.concession_reason = reason
        sf.concession_approved_by = request.user
        sf.concession_approved_on = timezone.now()
        sf.recalculate_status()
        sf.save()

        if getattr(sf.student, "user_id", None):
            send_fee_notification(
                sf.student.user_id,
                "Fee Concession Applied",
                f"A concession / scholarship of ₹{amount:,.2f} ({reason}) has been credited to your fee account. Remaining balance: ₹{sf.balance_amount:,.2f}."
            )

        return Response(StudentFeeSerializer(sf).data)

    # ----------------- Fee Statement -----------------
    @action(detail=True, methods=["get"], url_path="statement")
    def statement(self, request, pk=None):
        sf = self.get_object()
        data = {
            "student": {
                "id": sf.student.id,
                "name": sf.student.name,
                "usn": sf.student.usn,
                "email": sf.student.email,
                "department": sf.student.department.name if sf.student.department else "N/A",
                "semester": f"Semester {sf.fee_structure.semester.sem_number}" if sf.fee_structure.semester else "N/A",
                "seat_type": sf.fee_structure.get_seat_type_display(),
                "academic_year": sf.fee_structure.academic_year.year_name if sf.fee_structure.academic_year else "N/A",
            },
            "fee_structure": {
                "id": sf.fee_structure.id,
                "title": sf.fee_structure.title,
                "total_amount": float(sf.total_amount),
                "components": [
                    {"name": c.name, "amount": float(c.amount)} for c in sf.fee_structure.components.all()
                ],
            },
            "concession": {
                "amount": float(sf.concession_amount or 0),
                "reason": sf.concession_reason or "",
                "approved_by": (getattr(sf.concession_approved_by, "email", None) or getattr(sf.concession_approved_by, "user_id", None)) if sf.concession_approved_by else None,
                "approved_on": sf.concession_approved_on.strftime("%d/%m/%Y") if sf.concession_approved_on else None,
            },
            "net_payable": float(sf.net_payable),
            "total_paid": float(sf.paid_amount),
            "balance_amount": float(sf.balance_amount),
            "status": sf.status,
            "due_date": sf.due_date.strftime("%d/%m/%Y") if sf.due_date else "N/A",
            "payments": [
                {
                    "id": p.id,
                    "amount": float(p.amount),
                    "mode": p.get_mode_display(),
                    "paid_on": p.paid_on.strftime("%d/%m/%Y %H:%M") if p.paid_on else None,
                    "reference_no": p.reference_no or p.upi_txn_id or p.bank_reference_no or "",
                    "receipt_no": p.receipt.receipt_no if hasattr(p, "receipt") else None,
                    "verified": p.verified,
                    "is_reversed": p.is_reversed,
                    "remark": p.remark or "",
                    "entered_by": (getattr(p.entered_by, "email", None) or getattr(p.entered_by, "user_id", None)) if p.entered_by else "Student Online",
                }
                for p in sf.payments.all().order_by("-paid_on")
            ],
        }
        return Response(data)

    # ----------------- Academic Year Fee Summary -----------------
    @action(detail=False, methods=["get"], url_path="academic-year-summary")
    def academic_year_summary(self, request):
        """
        Calculates and returns aggregated academic year fee metrics:
        total fees, completed (paid) fees, not completed (unpaid) fees,
        completion percentage, and status.
        """
        student_fee_id = request.query_params.get("student_fee_id")
        usn = request.query_params.get("usn")
        ay_param = request.query_params.get("academic_year")

        student = None
        academic_year = None

        if student_fee_id:
            try:
                sf = StudentFee.objects.select_related(
                    "student", "student__department", "fee_structure__academic_year"
                ).get(id=student_fee_id)
                student = sf.student
                academic_year = sf.fee_structure.academic_year if sf.fee_structure else None
            except StudentFee.DoesNotExist:
                return Response({"detail": "StudentFee not found"}, status=404)
        elif usn:
            from students.models import Student
            student = Student.objects.filter(usn__iexact=usn.strip()).select_related("department").first()
            if not student:
                return Response({"detail": "Student not found with this USN"}, status=404)

        if not student:
            return Response({"detail": "Either student_fee_id or usn is required"}, status=400)

        qs = StudentFee.objects.filter(student=student).select_related(
            "fee_structure", "fee_structure__semester", "fee_structure__academic_year"
        )

        if ay_param:
            if str(ay_param).isdigit():
                qs = qs.filter(fee_structure__academic_year_id=ay_param)
            else:
                qs = qs.filter(fee_structure__academic_year__year_name__iexact=ay_param.strip())
        elif academic_year:
            qs = qs.filter(fee_structure__academic_year=academic_year)

        total_fees = sum(float(f.total_amount) for f in qs)
        concessions = sum(float(f.concession_amount or 0) for f in qs)
        net_payable = sum(float(f.net_payable) for f in qs)
        completed_fees = sum(float(f.paid_amount) for f in qs)
        not_completed_fees = sum(float(f.balance_amount) for f in qs)

        pct = (completed_fees / net_payable * 100) if net_payable > 0 else (100.0 if total_fees == 0 else 0.0)
        pct = round(min(100.0, max(0.0, pct)), 1)

        if not_completed_fees <= 0 and net_payable > 0:
            status_label = "COMPLETED"
        elif completed_fees > 0:
            status_label = "PARTIALLY_COMPLETED"
        else:
            status_label = "NOT_COMPLETED"

        ay_display = (
            academic_year.year_name
            if academic_year
            else (ay_param or (qs.first().fee_structure.academic_year.year_name if qs.exists() and qs.first().fee_structure and qs.first().fee_structure.academic_year else "2025-2026"))
        )

        breakdown = []
        for f in qs:
            breakdown.append({
                "student_fee_id": f.id,
                "structure_title": f.fee_structure.title if f.fee_structure else "Fee Structure",
                "semester": f.fee_structure.semester.sem_number if f.fee_structure and f.fee_structure.semester else "N/A",
                "total_amount": float(f.total_amount),
                "concession_amount": float(f.concession_amount or 0),
                "net_payable": float(f.net_payable),
                "paid_amount": float(f.paid_amount),
                "balance_amount": float(f.balance_amount),
                "status": f.status,
            })

        return Response({
            "usn": student.usn,
            "student_name": student.name,
            "department": student.department.name if student.department else "N/A",
            "academic_year": ay_display,
            "total_fees": total_fees,
            "concessions": concessions,
            "net_payable": net_payable,
            "completed_fees": completed_fees,
            "not_completed_fees": not_completed_fees,
            "completion_percentage": pct,
            "status": status_label,
            "breakdown": breakdown,
        })

    # ----------------- Student View -----------------
    @action(detail=False, methods=["get"], url_path="my-fees")
    def my_fees(self, request):
        try:
            student = request.user.student
        except Exception:
            return Response({"detail": "Student profile not found."}, status=404)

        fees = StudentFee.objects.filter(student=student).select_related(
            "fee_structure", "fee_structure__semester", "fee_structure__academic_year"
        ).prefetch_related("fee_structure__components")
        return Response(StudentFeeSerializer(fees, many=True).data)


# ---------- FeePayment ----------
class FeePaymentViewSet(viewsets.ModelViewSet):
    queryset = FeePayment.objects.select_related(
        "student_fee",
        "student_fee__student",
        "student_fee__student__department",
        "student_fee__fee_structure",
        "student_fee__fee_structure__academic_year",
        "student_fee__fee_structure__semester",
        "entered_by",
        "reversed_by",
    )
    serializer_class = FeePaymentSerializer

    def get_queryset(self):
        qs = FeePayment.objects.select_related(
            "student_fee",
            "student_fee__student",
            "student_fee__student__department",
            "student_fee__fee_structure",
            "student_fee__fee_structure__academic_year",
            "student_fee__fee_structure__semester",
            "entered_by",
            "reversed_by",
            "receipt",
        ).prefetch_related(
            "student_fee__fee_structure__components"
        )

        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "STUDENT" or (hasattr(user, "student") and user.student):
            student_obj = getattr(user, "student", None) or Student.objects.filter(user=user).first()
            if student_obj:
                qs = qs.filter(student_fee__student=student_obj)
            else:
                qs = qs.none()

        dept_id = self.request.query_params.get("department")
        if dept_id:
            qs = qs.filter(student_fee__student__department_id=dept_id)

        sem_id = self.request.query_params.get("semester")
        if sem_id:
            qs = qs.filter(student_fee__fee_structure__semester_id=sem_id)

        ay_id = self.request.query_params.get("academic_year")
        if ay_id:
            qs = qs.filter(student_fee__fee_structure__academic_year_id=ay_id)

        sf_id = self.request.query_params.get("student_fee")
        if sf_id:
            qs = qs.filter(student_fee_id=sf_id)

        status_filter = self.request.query_params.get("status")
        if status_filter == "verified":
            qs = qs.filter(verified=True, is_reversed=False)
        elif status_filter == "pending":
            qs = qs.filter(verified=False, is_reversed=False).exclude(remark__icontains="rejected")
        elif status_filter == "rejected":
            qs = qs.filter(verified=False, remark__icontains="rejected")
        elif status_filter == "reversed":
            qs = qs.filter(is_reversed=True)

        search = self.request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(student_fee__student__usn__icontains=search) |
                Q(student_fee__student__name__icontains=search) |
                Q(reference_no__icontains=search) |
                Q(receipt__receipt_no__icontains=search)
            )

        return qs.order_by("-paid_on", "-id")

    def get_permissions(self):
        if self.action == "proof":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def perform_create(self, serializer):
        serializer.save(entered_by=self.request.user)

    @action(detail=True, methods=["get"], url_path="proof", permission_classes=[permissions.AllowAny])
    def proof(self, request, pk=None):
        """
        Serves the payment proof document (images / PDFs) for verification display.
        """
        payment = self.get_object()
        file_obj = payment.upi_screenshot or payment.bank_statement_file
        if not file_obj:
            return Response(
                {"error": "No payment proof file has been uploaded for this payment record."},
                status=status.HTTP_404_NOT_FOUND
            )

        import mimetypes
        import os
        from django.http import FileResponse

        try:
            file_path = file_obj.path
            if os.path.exists(file_path):
                file_handle = open(file_path, 'rb')
            else:
                file_handle = file_obj.open('rb')
            
            content_type, _ = mimetypes.guess_type(file_obj.name)
            if not content_type:
                content_type = "image/jpeg"

            return FileResponse(file_handle, content_type=content_type)
        except Exception as e:
            return Response({"error": f"Failed to retrieve proof file: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    # -------------------- DIRECT PAYMENT RECORDING (ACCOUNTS) --------------------
    @action(detail=False, methods=["post"], url_path="record-payment")
    @transaction.atomic
    def record_payment(self, request):
        role = getattr(request.user, "role", "") or ""
        if role.upper() not in ["ACCOUNTS", "PRINCIPAL"] and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Accounts can record payments directly."}, status=403)

        sf_id = request.data.get("student_fee_id")
        if not sf_id:
            return Response({"detail": "student_fee_id is required."}, status=400)

        try:
            sf = StudentFee.objects.select_for_update().get(id=sf_id)
        except StudentFee.DoesNotExist:
            return Response({"detail": "StudentFee record not found."}, status=404)

        try:
            amount = float(request.data.get("amount", 0))
        except (ValueError, TypeError):
            return Response({"detail": "Invalid payment amount."}, status=400)

        if amount <= 0:
            return Response({"detail": "Payment amount must be greater than zero."}, status=400)

        if amount > float(sf.balance_amount):
            return Response({
                "detail": f"Payment amount (₹{amount}) exceeds outstanding balance (₹{sf.balance_amount})."
            }, status=400)

        mode = request.data.get("mode", "cash").lower()
        valid_modes = [c[0] for c in PaymentMode.choices]
        if mode not in valid_modes:
            mode = "cash"

        ref = request.data.get("reference_no", "").strip()
        if ref:
            dup = FeePayment.objects.filter(
                Q(reference_no__iexact=ref) |
                Q(upi_txn_id__iexact=ref) |
                Q(bank_reference_no__iexact=ref),
                is_reversed=False,
            )
            if dup.exists():
                return Response({
                    "detail": f"Payment reference '{ref}' already exists in record #{dup.first().id}."
                }, status=400)

        remark = request.data.get("remark", "").strip()
        component_name = request.data.get("component_name", "").strip()
        if component_name and component_name.lower() not in ["all", "all assigned fees", "none", ""]:
            remark = f"[{component_name}] {remark}".strip()

        # Handle proof upload (hidden if mode is cash, but handled safely here)
        proof_file = request.FILES.get("proof_image") or request.FILES.get("fee_receipt") or request.FILES.get("upi_screenshot") or request.FILES.get("bank_statement_file")

        payment = FeePayment.objects.create(
            student_fee=sf,
            amount=amount,
            mode=mode,
            reference_no=ref if ref else None,
            upi_txn_id=ref if mode == "upi" else None,
            bank_reference_no=ref if mode in ["bank", "dd", "cheque"] else None,
            entered_by=request.user,
            verified=True,
            remark=remark,
            upi_screenshot=proof_file if (mode == "upi" and proof_file) else None,
            bank_statement_file=proof_file if (mode in ["bank", "dd", "cheque", "online"] and proof_file) else None,
        )

        # Inherit student's uploaded proof file if available on existing payment submission
        if not proof_file:
            prev_proof = sf.payments.exclude(pk=payment.pk).filter(
                Q(upi_screenshot__isnull=False) | Q(bank_statement_file__isnull=False)
            ).order_by('-id').first()
            if prev_proof:
                if prev_proof.upi_screenshot:
                    payment.upi_screenshot = prev_proof.upi_screenshot
                if prev_proof.bank_statement_file:
                    payment.bank_statement_file = prev_proof.bank_statement_file
                payment.save(update_fields=["upi_screenshot", "bank_statement_file"])
        payment_date_str = request.data.get("payment_date")
        if payment_date_str:
            try:
                from django.utils.dateparse import parse_datetime, parse_date
                import datetime
                p_dt = parse_datetime(str(payment_date_str))
                if not p_dt:
                    d = parse_date(str(payment_date_str)[:10])
                    if d:
                        p_dt = timezone.make_aware(datetime.datetime.combine(d, datetime.time(12, 0)))
                if p_dt:
                    payment.paid_on = p_dt
                    payment.save(update_fields=["paid_on"])
            except Exception:
                pass

        receipt = FeeReceipt.objects.create(
            payment=payment,
            receipt_no=FeeReceipt.make_receipt_no(),
            verified_by=request.user,
        )

        sf.recalculate_status()
        sf.save()

        if getattr(sf.student, "user_id", None):
            send_fee_notification(
                sf.student.user_id,
                "Payment Recorded",
                f"Your payment of ₹{amount:,.2f} via {payment.get_mode_display()} has been recorded. Official Receipt {receipt.receipt_no} is generated."
            )

        components_data = [
            {"name": c.name, "amount": float(c.amount)}
            for c in sf.fee_structure.components.all()
        ]

        return Response({
            "message": "Payment recorded successfully.",
            "payment_id": payment.id,
            "receipt_no": receipt.receipt_no,
            "amount": float(payment.amount),
            "remaining_balance": float(sf.balance_amount),
            "status": sf.status,
            "paid_on": payment.paid_on.isoformat() if payment.paid_on else timezone.now().isoformat(),
            "mode": payment.mode,
            "mode_display": payment.get_mode_display(),
            "reference_no": payment.reference_no or payment.upi_txn_id or payment.bank_reference_no or "",
            "remark": payment.remark or "",
            "student": {
                "id": sf.student.id,
                "name": sf.student.name,
                "usn": sf.student.usn,
                "email": sf.student.email,
                "department": sf.student.department.name if sf.student.department else "N/A",
                "semester": f"Semester {sf.fee_structure.semester.sem_number}" if sf.fee_structure.semester else "N/A",
                "seat_type": sf.fee_structure.get_seat_type_display(),
                "academic_year": sf.fee_structure.academic_year.year_name if sf.fee_structure.academic_year else "N/A",
            },
            "fee_structure": {
                "id": sf.fee_structure.id,
                "title": sf.fee_structure.title,
                "total_amount": float(sf.total_amount),
                "components": components_data,
            },
            "net_payable": float(sf.net_payable),
            "total_paid": float(sf.paid_amount),
        }, status=201)

    # -------------------- VERIFY PAYMENT --------------------
    @action(detail=True, methods=["post"], url_path="verify")
    @transaction.atomic
    def verify(self, request, pk=None):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role not in ["ACCOUNTS", "PRINCIPAL"] and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Accounts can verify payments."}, status=403)

        try:
            payment = FeePayment.objects.select_for_update().get(pk=pk)
        except FeePayment.DoesNotExist:
            return Response({"detail": "Payment not found."}, status=404)

        if payment.verified:
            return Response({"detail": "Already verified"})

        if payment.is_reversed:
            return Response({"detail": "Cannot verify a reversed payment."}, status=400)

        payment.verified = True
        payment.save()

        receipt = getattr(payment, "receipt", None)
        if receipt is None:
            receipt = FeeReceipt.objects.create(
                payment=payment,
                receipt_no=FeeReceipt.make_receipt_no(),
                verified_by=request.user,
            )

        sf = StudentFee.objects.select_for_update().get(pk=payment.student_fee_id)
        sf.recalculate_status()
        sf.save()

        if getattr(sf.student, "user_id", None):
            send_fee_notification(
                sf.student.user_id,
                "Payment Verified",
                f"Your payment of ₹{payment.amount} has been verified. Official Receipt {receipt.receipt_no} is now available."
            )

        return Response({"receipt_no": receipt.receipt_no, "status": "verified"})

    # -------------------- REJECT PAYMENT --------------------
    @action(detail=True, methods=["post"], url_path="reject")
    @transaction.atomic
    def reject(self, request, pk=None):
        role = getattr(request.user, "role", "") or ""
        if role.upper() not in ["ACCOUNTS", "PRINCIPAL"] and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Accounts can reject payments."}, status=403)

        payment = self.get_object()

        if payment.verified:
            return Response({"detail": "Cannot reject an already verified payment; use controlled reversal."}, status=400)

        remark = request.data.get("remark", "").strip()
        if not remark:
            return Response({"detail": "Remark is required when rejecting payment."}, status=400)

        payment.verified = False
        payment.remark = f"Rejected: {remark}"
        payment.save()

        sf = payment.student_fee
        sf.recalculate_status()
        sf.save()

        if getattr(sf.student, "user_id", None):
            send_fee_notification(
                sf.student.user_id,
                "Payment Proof Rejected",
                f"Your payment proof of ₹{payment.amount} was rejected. Reason: {remark}"
            )

        return Response({
            "status": "rejected",
            "remark": remark,
            "message": "Payment rejected successfully.",
        }, status=200)

    # -------------------- PAYMENT REVERSAL --------------------
    @action(detail=True, methods=["post"], url_path="reverse")
    @transaction.atomic
    def reverse(self, request, pk=None):
        role = getattr(request.user, "role", "") or ""
        if role.upper() not in ["ACCOUNTS", "PRINCIPAL"] and not request.user.is_staff and not request.user.is_superuser:
            return Response({"detail": "Only Accounts or Principal can reverse payments."}, status=403)

        try:
            payment = FeePayment.objects.select_for_update().get(pk=pk)
        except FeePayment.DoesNotExist:
            return Response({"detail": "Payment not found."}, status=404)

        if payment.is_reversed:
            return Response({"detail": "Payment has already been reversed."}, status=400)

        reason = request.data.get("reason", "").strip()
        if not reason:
            return Response({"detail": "Reason is required for payment reversal."}, status=400)

        payment.is_reversed = True
        payment.reversed_at = timezone.now()
        payment.reversed_by = request.user
        payment.reversal_reason = reason
        payment.save()

        sf = StudentFee.objects.select_for_update().get(pk=payment.student_fee_id)
        sf.recalculate_status()
        sf.save()

        if getattr(sf.student, "user_id", None):
            send_fee_notification(
                sf.student.user_id,
                "Payment Reversal Notice",
                f"Payment #{payment.id} of ₹{payment.amount:,.2f} has been reversed. Reason: {reason}. Outstanding balance is now ₹{sf.balance_amount:,.2f}."
            )

        return Response({
            "message": "Payment reversed successfully.",
            "payment_id": payment.id,
            "reversal_reason": reason,
            "remaining_balance": float(sf.balance_amount),
            "status": sf.status,
        })


# ---------- FeeReceipt ----------
class FeeReceiptViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = FeeReceipt.objects.select_related(
        "payment",
        "payment__student_fee",
        "payment__student_fee__student",
    )
    serializer_class = FeeReceiptSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        student_id = self.request.query_params.get("student_id")
        if student_id:
            qs = qs.filter(payment__student_fee__student_id=student_id)
        return qs


# ---------- Accounts Dashboard API ----------
class AccountsDashboardView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        today = timezone.now().date()

        # Gross verified collections (total verified before reversals)
        gross_payments = FeePayment.objects.filter(verified=True)
        gross_collected = float(gross_payments.aggregate(s=Sum("amount"))["s"] or 0)
        today_gross = float(gross_payments.filter(paid_on__date=today).aggregate(s=Sum("amount"))["s"] or 0)

        # Reversals
        reversals_qs = FeePayment.objects.filter(is_reversed=True)
        total_reversals = float(reversals_qs.aggregate(s=Sum("amount"))["s"] or 0)
        reversals_count = reversals_qs.count()
        today_reversals = float(reversals_qs.filter(reversed_at__date=today).aggregate(s=Sum("amount"))["s"] or 0)

        # Net verified collections (strictly excluding reversed payments)
        net_payments = FeePayment.objects.filter(verified=True, is_reversed=False)
        net_collected = float(net_payments.aggregate(s=Sum("amount"))["s"] or 0)
        today_net = float(net_payments.filter(paid_on__date=today).aggregate(s=Sum("amount"))["s"] or 0)

        verified_payments = net_payments
        total_collected = net_collected
        today_collections = today_net

        # Pending unverified payments (excluding rejected)
        pending_qs = FeePayment.objects.filter(verified=False, is_reversed=False).exclude(remark__icontains="rejected")
        pending_payments_count = pending_qs.count()
        pending_payments_amount = float(pending_qs.aggregate(s=Sum("amount"))["s"] or 0)

        # Rejected payments count
        rejected_qs = FeePayment.objects.filter(verified=False, remark__icontains="rejected")
        rejected_payments_count = rejected_qs.count()

        # Assigned Fees, Concessions & Outstanding
        total_concessions = float(StudentFee.objects.aggregate(s=Sum("concession_amount"))["s"] or 0)
        
        # Calculate total assigned
        all_student_fees = StudentFee.objects.select_related("fee_structure").prefetch_related("fee_structure__components")
        total_assigned = 0.0
        for sf in all_student_fees:
            total_assigned += float(sf.total_amount)

        total_outstanding = max(total_assigned - total_concessions - total_collected, 0.0)

        # Student status distribution
        status_dist = {
            "paid": StudentFee.objects.filter(status="paid").count(),
            "partial": StudentFee.objects.filter(status="partial").count(),
            "pending": StudentFee.objects.filter(status="pending").count(),
        }

        # Collection summary by payment mode
        mode_breakdown = []
        for m_code, m_label in PaymentMode.choices:
            val = float(verified_payments.filter(mode=m_code).aggregate(s=Sum("amount"))["s"] or 0)
            if val > 0:
                mode_breakdown.append({"mode": m_code, "label": m_label, "amount": val})

        # Collection summary by seat_type
        seat_type_breakdown = []
        for st_code, st_label in FeeStructure.SeatType.choices:
            val = float(
                verified_payments.filter(student_fee__fee_structure__seat_type=st_code)
                .aggregate(s=Sum("amount"))["s"] or 0
            )
            if val > 0:
                seat_type_breakdown.append({"seat_type": st_code, "label": st_label, "amount": val})

        # Collection by department
        dept_breakdown = []
        for dept in Department.objects.all():
            val = float(
                verified_payments.filter(student_fee__student__department=dept)
                .aggregate(s=Sum("amount"))["s"] or 0
            )
            if val > 0:
                dept_breakdown.append({"department_id": dept.id, "name": dept.name, "amount": val})

        # Recent Transactions
        recent_payments = (
            FeePayment.objects.select_related(
                "student_fee__student",
                "student_fee__student__department",
                "student_fee__fee_structure",
                "receipt",
            )
            .prefetch_related("student_fee__fee_structure__components")
            .order_by("-paid_on")[:15]
        )
        recent_txns = []
        for p in recent_payments:
            rec_no = p.receipt.receipt_no if hasattr(p, "receipt") else None
            student_obj = p.student_fee.student
            comps = []
            if p.student_fee and p.student_fee.fee_structure:
                comps = [
                    {"name": c.name, "amount": float(c.amount)}
                    for c in p.student_fee.fee_structure.components.all()
                ]
            recent_txns.append({
                "id": p.id,
                "student_id": student_obj.id,
                "student_name": student_obj.name,
                "student_usn": student_obj.usn,
                "department": student_obj.department.name if student_obj.department else "N/A",
                "amount": float(p.amount),
                "mode": p.mode,
                "mode_display": p.get_mode_display(),
                "paid_on": p.paid_on.strftime("%d/%m/%Y %H:%M") if p.paid_on else None,
                "verified": p.verified,
                "is_reversed": p.is_reversed,
                "reference_no": p.reference_no or p.upi_txn_id or p.bank_reference_no or "",
                "receipt_no": rec_no,
                "components": comps,
            })

        return Response({
            "gross_collected": gross_collected,
            "total_reversals": total_reversals,
            "reversals_count": reversals_count,
            "net_collected": net_collected,
            "total_collected": net_collected,
            "today_gross": today_gross,
            "today_reversals": today_reversals,
            "today_net": today_net,
            "today_collections": today_net,
            "total_outstanding": total_outstanding,
            "total_concessions": total_concessions,
            "pending_payments_count": pending_payments_count,
            "pending_payments_amount": pending_payments_amount,
            "rejected_payments_count": rejected_payments_count,
            "active_structures_count": FeeStructure.objects.filter(is_active=True).count(),
            "status_distribution": status_dist,
            "collection_by_mode": mode_breakdown,
            "collection_by_seat_type": seat_type_breakdown,
            "collection_by_department": dept_breakdown,
            "recent_transactions": recent_txns,
        })


# ---------- Financial Reports API ----------
class FeeReportsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        report_type = request.query_params.get("report_type", "collections").lower()
        export = request.query_params.get("export", "").lower()

        now_str = timezone.now().strftime("%d/%m/%Y %H:%M:%S")
        actor_name = getattr(request.user, "email", None) or getattr(request.user, "user_id", "Accounts")

        # 1. Defaulters / Outstanding Report
        if report_type in ["defaulters", "outstanding"]:
            fees_qs = (
                StudentFee.objects.filter(status__in=["pending", "partial"])
                .select_related("student", "student__department", "fee_structure", "fee_structure__semester")
                .order_by("student__department__name", "student__usn")
            )
            rows = []
            for sf in fees_qs:
                rows.append({
                    "student_id": sf.student.id,
                    "student_name": sf.student.name,
                    "usn": sf.student.usn,
                    "department": sf.student.department.name if sf.student.department else "N/A",
                    "semester": sf.fee_structure.semester.sem_number if sf.fee_structure.semester else "N/A",
                    "seat_type": sf.fee_structure.get_seat_type_display(),
                    "total_fee": float(sf.total_amount),
                    "concession": float(sf.concession_amount or 0),
                    "paid_amount": float(sf.paid_amount),
                    "balance_amount": float(sf.balance_amount),
                    "status": sf.status.upper(),
                })

            if export == "csv":
                response = HttpResponse(content_type="text/csv")
                response["Content-Disposition"] = 'attachment; filename="fee_defaulters_report.csv"'
                writer = csv.writer(response)
                writer.writerow(["# CampusFlow SDMS - Fee Defaulters Report"])
                writer.writerow(["# Generated On:", now_str])
                writer.writerow(["# Exported By:", actor_name])
                writer.writerow(["# Total Outstanding Defaulters:", len(rows)])
                writer.writerow([])
                writer.writerow(["USN", "Student Name", "Department", "Semester", "Category", "Total Fee", "Concession", "Paid", "Balance", "Status"])
                for r in rows:
                    writer.writerow([r["usn"], r["student_name"], r["department"], r["semester"], r["seat_type"], r["total_fee"], r["concession"], r["paid_amount"], r["balance_amount"], r["status"]])
                return response

            return Response({
                "report_title": "Outstanding Fee Defaulters Report",
                "generated_on": now_str,
                "exported_by": actor_name,
                "total_records": len(rows),
                "total_outstanding": sum(r["balance_amount"] for r in rows),
                "data": rows,
            })

        # 2. Concessions & Scholarships Report
        elif report_type == "concessions":
            qs = (
                StudentFee.objects.filter(concession_amount__gt=0)
                .select_related("student", "student__department", "concession_approved_by")
                .order_by("-concession_approved_on")
            )
            rows = []
            for sf in qs:
                rows.append({
                    "student_name": sf.student.name,
                    "usn": sf.student.usn,
                    "department": sf.student.department.name if sf.student.department else "N/A",
                    "concession_amount": float(sf.concession_amount),
                    "reason": sf.concession_reason or "N/A",
                    "approved_by": (getattr(sf.concession_approved_by, "email", None) or getattr(sf.concession_approved_by, "user_id", None) or "Staff") if sf.concession_approved_by else "Staff",
                    "approved_on": sf.concession_approved_on.strftime("%d/%m/%Y") if sf.concession_approved_on else "N/A",
                })

            if export == "csv":
                response = HttpResponse(content_type="text/csv")
                response["Content-Disposition"] = 'attachment; filename="fee_concessions_report.csv"'
                writer = csv.writer(response)
                writer.writerow(["# CampusFlow SDMS - Approved Concessions & Scholarships Report"])
                writer.writerow(["# Generated On:", now_str])
                writer.writerow(["# Exported By:", actor_name])
                writer.writerow(["# Total Concession Records:", len(rows)])
                writer.writerow([])
                writer.writerow(["USN", "Student Name", "Department", "Concession Amount", "Reason/Scholarship", "Approved By", "Approved Date"])
                for r in rows:
                    writer.writerow([r["usn"], r["student_name"], r["department"], r["concession_amount"], r["reason"], r["approved_by"], r["approved_on"]])
                return response

            return Response({
                "report_title": "Approved Concessions & Scholarships Report",
                "generated_on": now_str,
                "exported_by": actor_name,
                "total_records": len(rows),
                "total_concessions": sum(r["concession_amount"] for r in rows),
                "data": rows,
            })

        # 3. Department-wise Collection Summary
        elif report_type == "departments":
            rows = []
            for dept in Department.objects.all():
                stu_count = Student.objects.filter(department=dept).count()
                collected = float(
                    FeePayment.objects.filter(
                        student_fee__student__department=dept, verified=True, is_reversed=False
                    ).aggregate(s=Sum("amount"))["s"] or 0
                )
                fees = StudentFee.objects.filter(student__department=dept).select_related("fee_structure").prefetch_related("fee_structure__components")
                assigned = sum(float(sf.total_amount) for sf in fees)
                concessions = float(fees.aggregate(s=Sum("concession_amount"))["s"] or 0)
                outstanding = max(assigned - concessions - collected, 0.0)

                rows.append({
                    "department_id": dept.id,
                    "department_name": dept.name,
                    "students_count": stu_count,
                    "assigned_amount": assigned,
                    "collected_amount": collected,
                    "outstanding_amount": outstanding,
                })

            if export == "csv":
                response = HttpResponse(content_type="text/csv")
                response["Content-Disposition"] = 'attachment; filename="department_collections_report.csv"'
                writer = csv.writer(response)
                writer.writerow(["# CampusFlow SDMS - Department Collections Summary"])
                writer.writerow(["# Generated On:", now_str])
                writer.writerow(["# Exported By:", actor_name])
                writer.writerow([])
                writer.writerow(["Department", "Total Students", "Total Assigned", "Collected", "Outstanding"])
                for r in rows:
                    writer.writerow([r["department_name"], r["students_count"], r["assigned_amount"], r["collected_amount"], r["outstanding_amount"]])
                return response

            return Response({
                "report_title": "Department-wise Collection Summary",
                "generated_on": now_str,
                "exported_by": actor_name,
                "total_collected": sum(r["collected_amount"] for r in rows),
                "total_outstanding": sum(r["outstanding_amount"] for r in rows),
                "data": rows,
            })

        # 4. Default: Overall Collections (Daily, Monthly, Recent)
        else:
            # Daily trends for the last 30 days
            from datetime import timedelta
            end_date = timezone.now().date()
            start_date = end_date - timedelta(days=29)

            daily_qs = (
                FeePayment.objects.filter(
                    verified=True, is_reversed=False, paid_on__date__gte=start_date, paid_on__date__lte=end_date
                )
                .values("paid_on__date")
                .annotate(total=Sum("amount"), count=Count("id"))
                .order_by("-paid_on__date")
            )

            daily_rows = [
                {
                    "date": d["paid_on__date"].strftime("%d/%m/%Y"),
                    "amount": float(d["total"]),
                    "transactions_count": d["count"],
                }
                for d in daily_qs
            ]

            if export == "csv":
                response = HttpResponse(content_type="text/csv")
                response["Content-Disposition"] = 'attachment; filename="daily_fee_collections.csv"'
                writer = csv.writer(response)
                writer.writerow(["# CampusFlow SDMS - Daily Collections Report"])
                writer.writerow(["# Period:", f"{start_date.strftime('%d/%m/%Y')} to {end_date.strftime('%d/%m/%Y')}"])
                writer.writerow(["# Generated On:", now_str])
                writer.writerow(["# Exported By:", actor_name])
                writer.writerow([])
                writer.writerow(["Date", "Total Amount Collected", "Transaction Count"])
                for r in daily_rows:
                    writer.writerow([r["date"], r["amount"], r["transactions_count"]])
                return response

            total_verified = float(FeePayment.objects.filter(verified=True, is_reversed=False).aggregate(s=Sum("amount"))["s"] or 0)
            return Response({
                "report_title": "Daily & Periodic Collections Report",
                "period": f"{start_date.strftime('%d/%m/%Y')} to {end_date.strftime('%d/%m/%Y')}",
                "generated_on": now_str,
                "exported_by": actor_name,
                "total_collected": total_verified,
                "data": daily_rows,
            })