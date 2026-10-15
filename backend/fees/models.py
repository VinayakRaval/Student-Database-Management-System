from django.db import models
from django.utils import timezone
from django.conf import settings
from academics.models import Department, Semester, AcademicYear
from students.models import Student

User = settings.AUTH_USER_MODEL

# ---------- Utilities ----------
def payment_upload_path(instance, filename):
    return f"fees/studentfee_{instance.student_fee_id}/{filename}"


class TimeStamped(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


# ---------- Fee Structure ----------
class FeeStructure(TimeStamped):
    class SeatType(models.TextChoices):
        GM = "gm", "GM"
        SNQ = "snq", "SNQ"
        LATERAL = "lateral", "Lateral"
        LATERAL_OLD = "Lateral", "Lateral (Legacy)"
        MANAGEMENT = "management", "Management"
        NRI = "nri", "NRI"
        GENERAL_MERIT = "general_merit", "General Merit"

    class ApprovalStatus(models.TextChoices):
        PENDING = "pending", "Pending Principal Approval"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    department = models.ForeignKey(Department, on_delete=models.PROTECT, related_name="fee_structures")
    academic_year = models.ForeignKey(AcademicYear, on_delete=models.SET_NULL, null=True, blank=True)
    semester = models.ForeignKey(Semester, on_delete=models.PROTECT, related_name="fee_structures")
    seat_type = models.CharField(max_length=16, choices=SeatType.choices)
    title = models.CharField(max_length=120, default="Standard Fee Structure")
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=False)
    approval_status = models.CharField(max_length=12, choices=ApprovalStatus.choices, default=ApprovalStatus.PENDING)
    approved_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True,
                                     related_name="approved_fee_structures")
    approved_on = models.DateTimeField(null=True, blank=True)
    rejection_remark = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'fee_structure'
        unique_together = ("department", "academic_year", "semester", "seat_type", "title")
        ordering = ["department__name", "academic_year", "semester__id", "seat_type", "title"]

    def __str__(self):
        return f"{self.department.name} | {self.academic_year} | Sem {self.semester} | {self.seat_type.upper()} | {self.title}"

    @property
    def total_amount(self):
        agg = self.components.aggregate(s=models.Sum("amount"))
        return agg["s"] or 0


class FeeComponent(TimeStamped):
    fee_structure = models.ForeignKey(FeeStructure, on_delete=models.CASCADE, related_name="components")
    name = models.CharField(max_length=80)
    amount = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        db_table = 'fee_component'
        unique_together = ("fee_structure", "name")
        ordering = ["name"]

    def __str__(self):
        return f"{self.name} — {self.amount}"


# ---------- Student Fee ----------
class StudentFee(TimeStamped):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PARTIAL = "partial", "Partial"
        PAID = "paid", "Paid"

    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="student_fees")
    fee_structure = models.ForeignKey(FeeStructure, on_delete=models.PROTECT, related_name="student_fees")
    due_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.PENDING)

    class Meta:
        db_table = 'student_fee'
        unique_together = ("student", "fee_structure")
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.student} | {self.fee_structure}"

    @property
    def total_amount(self):
        return self.fee_structure.total_amount

    @property
    def paid_amount(self):
        agg = self.payments.filter(verified=True).aggregate(s=models.Sum("amount"))
        return agg["s"] or 0

    @property
    def balance_amount(self):
        return self.total_amount - self.paid_amount


# ---------- Payments ----------
class PaymentMode(models.TextChoices):
    UPI = "upi", "UPI"
    BANK = "bank", "Bank Transfer"


class FeePayment(TimeStamped):
    student_fee = models.ForeignKey(
        StudentFee,
        on_delete=models.CASCADE,
        related_name="payments"
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    mode = models.CharField(max_length=12, choices=PaymentMode.choices)
    paid_on = models.DateTimeField(auto_now_add=True)

    # UPI fields
    upi_txn_id = models.CharField(max_length=64, blank=True, null=True)
    upi_screenshot = models.FileField(
        upload_to=payment_upload_path,
        blank=True,
        null=True
    )

    # Bank fields
    bank_reference_no = models.CharField(max_length=64, blank=True, null=True)
    bank_statement_file = models.FileField(
        upload_to=payment_upload_path,
        blank=True,
        null=True
    )

    entered_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    verified = models.BooleanField(default=False)
    remark = models.TextField(blank=True, null=True)

    def clean(self):
        from django.core.exceptions import ValidationError

        if self.mode == PaymentMode.UPI and not (
            self.upi_txn_id and self.upi_screenshot
        ):
            raise ValidationError({
                "upi_txn_id": "UPI transaction ID and screenshot are required for UPI payments."
            })

        if self.mode == PaymentMode.BANK and not (
            self.bank_reference_no or self.bank_statement_file
        ):
            raise ValidationError({
                "bank_reference_no": "Bank reference number or statement file is required for bank payments."
            })

    def __str__(self):
        status_flag = "VERIFIED" if self.verified else "PENDING"
        return f"Payment {self.id} | {self.amount} | {self.get_mode_display()} | {status_flag}"

# ---------- Receipts ----------

    class Meta:
        db_table = 'fee_payment'
class FeeReceipt(TimeStamped):
    payment = models.OneToOneField(FeePayment, on_delete=models.PROTECT, related_name="receipt")
    receipt_no = models.CharField(max_length=40, unique=True)
    issued_on = models.DateTimeField(auto_now_add=True)
    verified_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)

    def __str__(self):
        return self.receipt_no

    @staticmethod
    def make_receipt_no(prefix="REC"):
        ts = timezone.now().strftime("%Y%m%d%H%M%S%f")
        return f"{prefix}-{ts}"



    class Meta:
        db_table = 'fee_receipt'
