from rest_framework import serializers
from .models import FeeStructure, FeeComponent, StudentFee, FeePayment, FeeReceipt

class FeeComponentSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeeComponent
        fields = ["id", "name", "amount", "created_at", "updated_at"]


class FeeStructureSerializer(serializers.ModelSerializer):
    components = FeeComponentSerializer(many=True)
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    # --- NEW: Fetch Readable Names for Display ---
    department_name = serializers.CharField(source='department.name', read_only=True)
    academic_year_name = serializers.CharField(source='academic_year.year_name', read_only=True)
    semester_name = serializers.SerializerMethodField()
    booklet_no = serializers.SerializerMethodField()
    formatted_receipt_no = serializers.SerializerMethodField()
    receipt_date = serializers.SerializerMethodField()

    created_by_name = serializers.SerializerMethodField()
    approved_by_name = serializers.SerializerMethodField()

    def get_created_by_name(self, obj):
        if obj.created_by:
            return getattr(obj.created_by, 'email', None) or getattr(obj.created_by, 'user_id', None) or 'Accounts'
        return None

    def get_approved_by_name(self, obj):
        if obj.approved_by:
            return getattr(obj.approved_by, 'email', None) or getattr(obj.approved_by, 'user_id', None) or 'Principal'
        return None

    class Meta:
        model = FeeStructure
        fields = [
            "id", 
            "department", "department_name",    # ID + Name
            "academic_year", "academic_year_name", # ID + Name
            "semester", "semester_name",       # ID + Name
            "seat_type", "title", "description",
            "is_active", "approval_status", "approved_by", "approved_by_name", "approved_on", 
            "created_by", "created_by_name",
            "rejection_remark",
            "components", "total_amount",
            "booklet_no", "formatted_receipt_no", "receipt_date",
            "created_at", "updated_at"
        ]

    def get_booklet_no(self, obj):
        return f"{10495000 + obj.id}"

    def get_formatted_receipt_no(self, obj):
        return f"{821000 + obj.id:07d}"

    def get_receipt_date(self, obj):
        date_val = obj.approved_on or obj.created_at
        return date_val.strftime("%d/%m/%Y") if date_val else "01/01/2026"

    def get_semester_name(self, obj):
        if obj.semester:
            return f"Semester {obj.semester.sem_number}"
        return "N/A"

    def create(self, validated_data):
        comps = validated_data.pop("components", [])
        fs = FeeStructure.objects.create(**validated_data)
        for c in comps:
            FeeComponent.objects.create(fee_structure=fs, **c)
        return fs

    def update(self, instance, validated_data):
        comps = validated_data.pop("components", None)
        for attr, val in validated_data.items():
            setattr(instance, attr, val)
        # If structure was rejected, reset to pending upon re-submission/edit
        if instance.approval_status == "rejected":
            instance.approval_status = "pending"
            instance.rejection_remark = None
        instance.save()
        if comps is not None:
            instance.components.all().delete()
            for c in comps:
                FeeComponent.objects.create(fee_structure=instance, **c)
        return instance

class StudentFeeSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_usn = serializers.CharField(source='student.usn', read_only=True)
    department_name = serializers.CharField(source='student.department.name', read_only=True)
    department_code = serializers.SerializerMethodField()
    semester = serializers.CharField(source='fee_structure.semester.sem_number', read_only=True)
    academic_year = serializers.CharField(source='fee_structure.academic_year.year_name', read_only=True)
    seat_type = serializers.CharField(source='fee_structure.seat_type', read_only=True)
    total_fee = serializers.DecimalField(source='fee_structure.total_amount', max_digits=12, decimal_places=2, read_only=True)
    paid_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    balance_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    components = FeeComponentSerializer(source='fee_structure.components', many=True, read_only=True)
    receipt_id = serializers.SerializerMethodField()
    receipt_no = serializers.SerializerMethodField()
    receipt_date = serializers.SerializerMethodField()
    booklet_no = serializers.SerializerMethodField()
    formatted_receipt_no = serializers.SerializerMethodField()

    concession_approved_by_name = serializers.SerializerMethodField()

    def get_concession_approved_by_name(self, obj):
        if obj.concession_approved_by:
            return getattr(obj.concession_approved_by, 'email', None) or getattr(obj.concession_approved_by, 'user_id', None) or 'Accounts'
        return None
    net_payable = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    payments = serializers.SerializerMethodField()

    class Meta:
        model = StudentFee
        fields = [
            "id",
            "student",
            "student_name",
            "student_usn",
            "department_name",
            "department_code",
            "fee_structure",
            "due_date",
            "status",
            "semester",
            "academic_year",
            "seat_type",
            "total_fee",
            "concession_amount",
            "concession_reason",
            "concession_approved_by_name",
            "concession_approved_on",
            "net_payable",
            "paid_amount",
            "balance_amount",
            "components",
            "receipt_id",
            "receipt_no",
            "receipt_date",
            "booklet_no",
            "formatted_receipt_no",
            "payments",
        ]

    def get_department_code(self, obj):
        try:
            dept = obj.student.department
            if dept and dept.name:
                words = dept.name.split()
                if len(words) > 1:
                    return "".join(w[0].upper() for w in words if w.lower() not in ['and', '&', 'of', 'in'])
                return dept.name[:4].upper()
        except Exception:
            pass
        return "CSE"

    def get_receipt_id(self, obj):
        payment = obj.payments.filter(verified=True).order_by('-id').first() or obj.payments.order_by('-id').first()
        if payment and hasattr(payment, 'receipt'):
            return payment.receipt.id
        return None

    def get_receipt_no(self, obj):
        payment = obj.payments.filter(verified=True).order_by('-id').first() or obj.payments.order_by('-id').first()
        if payment and hasattr(payment, 'receipt'):
            return payment.receipt.receipt_no
        return f"REC-{obj.id:06d}" if obj.paid_amount > 0 else None

    def get_receipt_date(self, obj):
        payment = obj.payments.filter(verified=True).order_by('-id').first() or obj.payments.order_by('-id').first()
        if payment:
            date_val = payment.receipt.issued_on if hasattr(payment, 'receipt') else payment.paid_on
            return date_val.strftime("%d/%m/%Y")
        from django.utils import timezone
        return timezone.now().strftime("%d/%m/%Y") if obj.paid_amount > 0 else None

    def get_booklet_no(self, obj):
        payment = obj.payments.filter(verified=True).order_by('-id').first() or obj.payments.order_by('-id').first()
        return f"{10495000 + (payment.id if payment else obj.id)}"

    def get_formatted_receipt_no(self, obj):
        payment = obj.payments.filter(verified=True).order_by('-id').first() or obj.payments.order_by('-id').first()
        return f"{821000 + (payment.id if payment else obj.id):07d}"

    def get_payments(self, obj):
        result = []
        request = self.context.get('request')
        for p in obj.payments.all().order_by('-paid_on', '-id'):
            rec_no = None
            if hasattr(p, 'receipt'):
                rec_no = p.receipt.receipt_no
            file_obj = p.upi_screenshot or p.bank_statement_file
            p_url = None
            if file_obj:
                try:
                    if request:
                        p_url = request.build_absolute_uri(file_obj.url)
                    else:
                        p_url = file_obj.url
                except Exception:
                    p_url = str(file_obj)

            if p.is_reversed:
                v_status = "REVERSED"
            elif p.verified:
                v_status = "VERIFIED"
            elif p.remark and "rejected" in p.remark.lower():
                v_status = "REJECTED"
            else:
                v_status = "PENDING"

            result.append({
                "id": p.id,
                "amount": float(p.amount),
                "mode": p.mode,
                "mode_display": p.get_mode_display(),
                "paid_on": p.paid_on.strftime("%Y-%m-%d %H:%M") if p.paid_on else None,
                "verified": p.verified,
                "is_reversed": p.is_reversed,
                "verification_status": v_status,
                "reference_no": p.reference_no or p.upi_txn_id or p.bank_reference_no or "",
                "receipt_no": rec_no,
                "remark": p.remark,
                "reversal_reason": p.reversal_reason,
                "proof_url": p_url,
            })
        return result

class FeePaymentSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student_fee.student.name', read_only=True)
    student_usn = serializers.CharField(source='student_fee.student.usn', read_only=True)
    student_email = serializers.CharField(source='student_fee.student.email', read_only=True)
    department_name = serializers.CharField(source='student_fee.student.department.name', read_only=True)
    semester_name = serializers.SerializerMethodField()
    academic_year_name = serializers.CharField(source='student_fee.fee_structure.academic_year.year_name', read_only=True)
    receipt_no = serializers.CharField(source='receipt.receipt_no', read_only=True)
    entered_by_name = serializers.SerializerMethodField()
    reversed_by_name = serializers.SerializerMethodField()
    mode_display = serializers.CharField(source='get_mode_display', read_only=True)
    payment_status = serializers.SerializerMethodField()
    verification_status = serializers.SerializerMethodField()
    booklet_no = serializers.SerializerMethodField()
    formatted_receipt_no = serializers.SerializerMethodField()
    components = serializers.SerializerMethodField()
    proof_url = serializers.SerializerMethodField()

    def get_entered_by_name(self, obj):
        if obj.entered_by:
            return getattr(obj.entered_by, 'email', None) or getattr(obj.entered_by, 'user_id', None) or 'Accounts'
        return 'Online Student'

    def get_reversed_by_name(self, obj):
        if obj.reversed_by:
            return getattr(obj.reversed_by, 'email', None) or getattr(obj.reversed_by, 'user_id', None) or 'Accounts'
        return None

    def get_payment_status(self, obj):
        if obj.is_reversed:
            return "REVERSED"
        if obj.verified:
            return "SUCCESSFUL"
        if obj.remark and "rejected" in obj.remark.lower():
            return "FAILED"
        return "PENDING"

    def get_verification_status(self, obj):
        if obj.is_reversed:
            return "REVERSED"
        if obj.verified:
            return "VERIFIED"
        if obj.remark and "rejected" in obj.remark.lower():
            return "REJECTED"
        return "PENDING"

    def get_proof_url(self, obj):
        request = self.context.get('request')
        file_obj = obj.upi_screenshot or obj.bank_statement_file
        if file_obj:
            try:
                if request:
                    return request.build_absolute_uri(file_obj.url)
                return file_obj.url
            except Exception:
                pass
        return None

    def get_booklet_no(self, obj):
        return f"{10495000 + obj.id}"

    def get_formatted_receipt_no(self, obj):
        return f"{821000 + obj.id:07d}"

    def get_components(self, obj):
        try:
            if obj.student_fee and obj.student_fee.fee_structure:
                return FeeComponentSerializer(obj.student_fee.fee_structure.components.all(), many=True).data
        except Exception:
            pass
        return []

    # Optional input fields for registration flow or alternative clients
    student_id = serializers.IntegerField(write_only=True, required=False)
    fee_structure_id = serializers.IntegerField(write_only=True, required=False)
    payment_method = serializers.CharField(write_only=True, required=False)
    upi_transaction_id = serializers.CharField(write_only=True, required=False)
    fee_receipt = serializers.FileField(write_only=True, required=False)

    class Meta:
        model = FeePayment
        fields = "__all__"
        read_only_fields = ["entered_by", "verified", "paid_on"]
        extra_kwargs = {
            "student_fee": {"required": False},
            "amount": {"required": False},
            "mode": {"required": False},
        }

    def get_semester_name(self, obj):
        try:
            if obj.student_fee and obj.student_fee.fee_structure and obj.student_fee.fee_structure.semester:
                return f"Semester {obj.student_fee.fee_structure.semester.sem_number}"
        except Exception:
            pass
        return "N/A"

    def validate(self, attrs):
        initial = getattr(self, "initial_data", {})
        student_id = initial.get("student_id")
        fee_structure_id = initial.get("fee_structure_id")
        sf_id = initial.get("student_fee") or initial.get("student_fee_id")

        if "student_fee" not in attrs:
            if sf_id:
                try:
                    attrs["student_fee"] = StudentFee.objects.get(id=sf_id)
                except Exception:
                    pass
            elif student_id and fee_structure_id:
                sf, _ = StudentFee.objects.get_or_create(
                    student_id=student_id,
                    fee_structure_id=fee_structure_id
                )
                attrs["student_fee"] = sf

        payment_method = initial.get("payment_method") or initial.get("mode")
        if "mode" not in attrs:
            if payment_method:
                attrs["mode"] = str(payment_method).lower()
            else:
                attrs["mode"] = "upi"

        if "amount" not in attrs or not attrs["amount"]:
            sf = attrs.get("student_fee")
            req_amount = initial.get("amount")
            if req_amount:
                try:
                    attrs["amount"] = float(req_amount)
                except Exception:
                    attrs["amount"] = sf.balance_amount if sf else 0
            elif sf:
                attrs["amount"] = sf.balance_amount if sf.balance_amount > 0 else sf.total_amount
            else:
                attrs["amount"] = 0

        ref_no = initial.get("reference_no") or initial.get("upi_transaction_id") or initial.get("bank_reference_no") or initial.get("txn_id")
        if ref_no:
            attrs["reference_no"] = str(ref_no).strip()
            if attrs.get("mode") == "bank":
                attrs["bank_reference_no"] = str(ref_no).strip()
            else:
                attrs["upi_txn_id"] = str(ref_no).strip()

        fee_receipt = initial.get("fee_receipt") or initial.get("proof_image") or initial.get("upi_screenshot") or initial.get("bank_statement_file")
        if fee_receipt:
            if attrs.get("mode") == "bank":
                attrs["bank_statement_file"] = fee_receipt
            else:
                attrs["upi_screenshot"] = fee_receipt

        return attrs

    def create(self, validated_data):
        # Pop extra write-only helper fields if present
        validated_data.pop("student_id", None)
        validated_data.pop("fee_structure_id", None)
        validated_data.pop("payment_method", None)
        validated_data.pop("upi_transaction_id", None)
        validated_data.pop("fee_receipt", None)
        validated_data.pop("student_fee_id", None)
        validated_data.pop("proof_image", None)
        validated_data.pop("txn_id", None)

        return super().create(validated_data)


class FeeReceiptSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='payment.student_fee.student.name', read_only=True)
    student_usn = serializers.CharField(source='payment.student_fee.student.usn', read_only=True)
    department_name = serializers.CharField(source='payment.student_fee.student.department.name', read_only=True)
    department_code = serializers.SerializerMethodField()
    semester = serializers.CharField(source='payment.student_fee.fee_structure.semester.sem_number', read_only=True)
    academic_year = serializers.CharField(source='payment.student_fee.fee_structure.academic_year.year_name', read_only=True)
    seat_type = serializers.CharField(source='payment.student_fee.fee_structure.seat_type', read_only=True)
    total_amount = serializers.DecimalField(source='payment.amount', max_digits=12, decimal_places=2, read_only=True)
    structure_total = serializers.DecimalField(source='payment.student_fee.fee_structure.total_amount', max_digits=12, decimal_places=2, read_only=True)
    components = FeeComponentSerializer(source='payment.student_fee.fee_structure.components', many=True, read_only=True)
    booklet_no = serializers.SerializerMethodField()
    receipt_date = serializers.SerializerMethodField()
    formatted_receipt_no = serializers.SerializerMethodField()
    verified_by_name = serializers.CharField(source='verified_by.get_full_name', read_only=True)

    class Meta:
        model = FeeReceipt
        fields = [
            "id", "payment", "receipt_no", "issued_on", "verified_by", "verified_by_name",
            "student_name", "student_usn", "department_name", "department_code",
            "semester", "academic_year", "seat_type", "total_amount", "structure_total",
            "components", "booklet_no", "receipt_date", "formatted_receipt_no"
        ]

    def get_department_code(self, obj):
        try:
            dept = obj.payment.student_fee.student.department
            if dept and dept.name:
                words = dept.name.split()
                if len(words) > 1:
                    return "".join(w[0].upper() for w in words if w.lower() not in ['and', '&', 'of', 'in'])
                return dept.name[:4].upper()
        except Exception:
            pass
        return "CSE"

    def get_booklet_no(self, obj):
        return f"{10495000 + obj.id}"

    def get_receipt_date(self, obj):
        date_val = obj.issued_on or obj.payment.paid_on
        return date_val.strftime("%d/%m/%Y") if date_val else "01/01/2026"

    def get_formatted_receipt_no(self, obj):
        return f"{821000 + obj.id:07d}"