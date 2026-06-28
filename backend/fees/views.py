from django.db import transaction
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.apps import apps

from students.models import Student
from academics.models import Department, Semester, AcademicYear
from .models import FeeStructure, StudentFee, FeePayment, FeeReceipt
from .serializers import (
    FeeStructureSerializer,
    StudentFeeSerializer,
    FeePaymentSerializer,
    FeeReceiptSerializer,
)

# ---------- Role-based Permissions ----------
class IsRole(permissions.BasePermission):
    """
    Allows access only to users with specific roles.
    """
    allowed_roles = []

    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            request.user.role in getattr(view, "allowed_roles", self.allowed_roles)
        )


class IsAccounts(IsRole):
    allowed_roles = ["ACCOUNTS"]


class IsPrincipal(IsRole):
    allowed_roles = ["PRINCIPAL"]


# ---------- FeeStructure ----------
class FeeStructureViewSet(viewsets.ModelViewSet):
    queryset = FeeStructure.objects.prefetch_related("components")
    serializer_class = FeeStructureSerializer

    # <<< ADDED: allow anonymous list & retrieve >>>>
    def get_permissions(self):
        """
        Make list and retrieve publicly accessible (AllowAny).
        Other actions will follow the default permission classes.
        """
        if self.action in ["list", "retrieve"]:
            return [AllowAny()]
        return super().get_permissions()
    # <<< END ADDED >>>

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def approve(self, request, pk=None):
        # Only Principal can approve
        if not request.user or getattr(request.user, "role", None) != "PRINCIPAL":
            return Response({"detail": "Only Principal can approve."}, status=403)

        fs = self.get_object()

        # Approve FeeStructure
        fs.approval_status = "approved"
        fs.is_active = True
        fs.approved_by = request.user
        fs.approved_on = timezone.now()
        fs.save()

        # ---- Map seat_type if needed ----
        seat_map = {
            "gm": "general_merit",
            "snq": "snq",
            "Lateral": "lateral"
        }
        student_seat_type = seat_map.get(fs.seat_type, fs.seat_type)

        # ---- Fetch active students matching criteria ----
        students = Student.objects.filter(
            department=fs.department,
            semester=fs.semester,
            academic_year=fs.academic_year,
            seat_type=student_seat_type,
            status__iexact="active"  # case-insensitive
        )

        created = 0
        for s in students:
            sf_obj, was_created = StudentFee.objects.get_or_create(student=s, fee_structure=fs)
            if was_created:
                created += 1
               
        return Response({
            "status": "approved",
            "assigned_to": students.count(),
            "created": created
        }, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def reject(self, request, pk=None):
    # Only Principal can reject
        if request.user.role != "PRINCIPAL":
            return Response({"detail": "Only Principal can reject."}, status=403)

        fs = self.get_object()

        # Get remark from request body
        remark = request.data.get("remark", "").strip()
        if not remark:
            return Response({"detail": "Remark is required when rejecting."}, status=400)

        # Update FeeStructure as rejected
        fs.approval_status = "rejected"
        fs.is_active = False
        fs.rejected_by = request.user
        fs.rejected_on = timezone.now()
        fs.rejection_remark = remark
        fs.save()

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
        if self.action in ["bulk_assign", "approve"]:
            return [IsAccounts()]
        return [permissions.AllowAny()]

    # ----------------- Bulk Assign for Staff -----------------
    @action(detail=False, methods=["post"], url_path="bulk-assign")
    @transaction.atomic
    def bulk_assign(self, request):
        if not request.user or getattr(request.user, "role", None) != "ACCOUNTS":
            return Response({"detail": "Only Accounts can assign fees."}, status=403)

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
            is_active=True,
            seat_type=seat_type
        )

        created = 0
        for s in students:
            obj, was_created = StudentFee.objects.get_or_create(student=s, fee_structure=fee_struct)
            if was_created:
                created += 1
    
        return Response({"assigned_to": students.count(), "created": created})


    # ----------------- Student View -----------------
    # GET /api/student-fees/my-fees/
    @action(detail=False, methods=["get"], url_path="my-fees")
    def my_fees(self, request):
        """
        Returns overview of all fees assigned to the logged-in student.
        Only basic info like id, semester, academic_year, status, balance.
        """
        try:
            student = request.user.student
        except Exception:
            return Response({"detail": "Student profile not found."}, status=404)

        fees = StudentFee.objects.filter(student=student)
        # Only select overview fields
        data = [
            {
                "id": f.id,
                "semester": str(f.fee_structure.semester.sem_number),
                "academic_year": str(f.fee_structure.academic_year.year_name),
                "status": f.status,
                "balance_amount": f.balance_amount,
                "total_fee": f.total_amount,
            }
            for f in fees
        ]
        return Response(data)


# ---------- FeePayment ----------
class FeePaymentViewSet(viewsets.ModelViewSet):
    queryset = FeePayment.objects.select_related("student_fee")
    serializer_class = FeePaymentSerializer

    def get_permissions(self):
        if self.action == "verify":
            return [IsAccounts()]
        return [permissions.IsAuthenticated()]

    def perform_create(self, serializer):
        serializer.save(entered_by=self.request.user)
        sf = serializer.instance.student_fee
        # Additional logic if needed

    # -------------------- VERIFY PAYMENT --------------------
    @action(detail=True, methods=["post"], url_path="verify")
    @transaction.atomic
    def verify(self, request, pk=None):
        if request.user.role != "ACCOUNTS":
            return Response(
                {"detail": "Only Accounts can verify payments."},
                status=403
            )

        payment = self.get_object()

        if payment.verified:
            return Response({"detail": "Already verified"})

        # Mark verified
        payment.verified = True
        payment.save()

        # Generate receipt if not exists
        receipt = getattr(payment, "receipt", None)
        if receipt is None:
            receipt = FeeReceipt.objects.create(
                payment=payment,
                receipt_no=FeeReceipt.make_receipt_no(),
                verified_by=request.user
            )

        # Update StudentFee status
        sf = payment.student_fee
        sf.status = (
            StudentFee.Status.PAID
            if sf.balance_amount <= 0
            else StudentFee.Status.PARTIAL
        )
        sf.save()

        # Optional: send notification
        if getattr(sf.student, "user_id", None):
            AppNotification.objects.create(
                user_id=sf.student.user_id,
                title="Payment Verified",
                body=f"Payment of {payment.amount} verified. Receipt {receipt.receipt_no} issued."
            )

        return Response({"receipt_no": receipt.receipt_no})

    # -------------------- REJECT PAYMENT --------------------
    @action(detail=True, methods=["post"], url_path="reject")
    @transaction.atomic
    def reject(self, request, pk=None):
        if request.user.role != "ACCOUNTS":
            return Response(
                {"detail": "Only Accounts can reject payments."},
                status=403
            )

        payment = self.get_object()

        if payment.verified:
            return Response(
                {"detail": "Cannot reject a verified payment."},
                status=400
            )

        remark = request.data.get("remark", "").strip()
        if not remark:
            return Response(
                {"detail": "Remark is required when rejecting payment."},
                status=400
            )

        # Update rejection details
        payment.rejected = True
        payment.rejection_remark = remark
        payment.rejected_by = request.user
        payment.rejected_on = timezone.now()
        payment.save()

        # Update StudentFee status
        sf = payment.student_fee
        sf.status = StudentFee.Status.PENDING
        sf.save()

        # Notify student
        if getattr(sf.student, "user_id", None):
            AppNotification.objects.create(
                user_id=sf.student.user_id,
                title="Payment Rejected",
                body=f"Your payment of {payment.amount} was rejected. Reason: {remark}"
            )

        return Response(
            {
                "status": "rejected",
                "remark": remark,
                "message": "Payment rejected successfully.",
            },
            status=200
        )


# ---------- FeeReceipt ----------
class FeeReceiptViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = FeeReceipt.objects.select_related(
        "payment",
        "payment__student_fee",
        "payment_student_fee_student"
    )
    serializer_class = FeeReceiptSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        student_id = self.request.query_params.get("student_id")
        if student_id:
            qs = qs.filter(payment_student_fee_student_id=student_id)
        return qs