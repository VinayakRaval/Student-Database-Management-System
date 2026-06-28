from django.contrib import admin
from .models import FeeStructure, FeeComponent, StudentFee, FeePayment, FeeReceipt
# ---------- Fee Structure ----------
class FeeComponentInline(admin.TabularInline):
    model = FeeComponent
    extra = 1
    readonly_fields = ("created_at", "updated_at")


@admin.register(FeeStructure)
class FeeStructureAdmin(admin.ModelAdmin):
    list_display = ("id", "department", "academic_year", "semester", "seat_type", "title",
                    "is_active", "approval_status", "approved_by", "approved_on", "created_at")
    list_filter = ("department", "semester", "seat_type", "approval_status", "academic_year")
    search_fields = ("title", "department__name")
    inlines = [FeeComponentInline]
    readonly_fields = ("approved_by", "approved_on", "created_at", "updated_at")


# ---------- Student Fee ----------
@admin.register(StudentFee)
class StudentFeeAdmin(admin.ModelAdmin):
    list_display = ("id", "student", "fee_structure", "status", "total_amount",
                    "paid_amount", "balance_amount", "created_at")
    search_fields = ("student__name", "fee_structure__title")
    readonly_fields = ("total_amount", "paid_amount", "balance_amount", "created_at", "updated_at")


# ---------- Fee Payment ----------
@admin.register(FeePayment)
class FeePaymentAdmin(admin.ModelAdmin):
    list_display = ("id", "student_fee", "amount", "mode", "verified", "paid_on", "entered_by")
    list_filter = ("mode", "verified")
    search_fields = ("student_fee__student__name", "student_fee__fee_structure__title", "upi_txn_id")
    readonly_fields = ("paid_on", "entered_by", "created_at", "updated_at")


# ---------- Fee Receipt ----------
@admin.register(FeeReceipt)
class FeeReceiptAdmin(admin.ModelAdmin):
    list_display = ("id", "receipt_no", "payment", "verified_by", "issued_on")
    search_fields = ("receipt_no", "payment__student_fee__student__name")
    readonly_fields = ("receipt_no", "issued_on", "created_at", "updated_at")

