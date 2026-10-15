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

    class Meta:
        model = FeeStructure
        fields = [
            "id", 
            "department", "department_name",    # ID + Name
            "academic_year", "academic_year_name", # ID + Name
            "semester", "semester_name",       # ID + Name
            "seat_type", "title", "description",
            "is_active", "approval_status", "approved_by", "approved_on", 
            "rejection_remark",
            "components", "total_amount",
            "created_at", "updated_at"
        ]

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
    semester = serializers.CharField(source='fee_structure.semester.sem_number', read_only=True)
    academic_year = serializers.CharField(source='fee_structure.academic_year.year_name', read_only=True)
    seat_type = serializers.CharField(source='fee_structure.seat_type', read_only=True)
    total_fee = serializers.DecimalField(source='fee_structure.total_amount', max_digits=12, decimal_places=2, read_only=True)
    paid_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    balance_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    components = FeeComponentSerializer(source='fee_structure.components', many=True, read_only=True)

    class Meta:
        model = StudentFee
        fields = [
            "id",
            "student",
            "fee_structure",
            "due_date",
            "status",
            "semester",
            "academic_year",
            "seat_type",
            "total_fee",
            "paid_amount",
            "balance_amount",
            "components",
        ]

class FeePaymentSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student_fee.student.name', read_only=True)
    student_usn = serializers.CharField(source='student_fee.student.usn', read_only=True)
    student_email = serializers.CharField(source='student_fee.student.email', read_only=True)
    department_name = serializers.CharField(source='student_fee.student.department.name', read_only=True)
    semester_name = serializers.SerializerMethodField()
    academic_year_name = serializers.CharField(source='student_fee.fee_structure.academic_year.year_name', read_only=True)
    receipt_no = serializers.CharField(source='receipt.receipt_no', read_only=True)

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

        if "student_fee" not in attrs and student_id and fee_structure_id:
            sf, _ = StudentFee.objects.get_or_create(
                student_id=student_id,
                fee_structure_id=fee_structure_id
            )
            attrs["student_fee"] = sf

        payment_method = initial.get("payment_method")
        if "mode" not in attrs:
            if payment_method:
                attrs["mode"] = payment_method.lower()
            else:
                attrs["mode"] = "upi"

        if "amount" not in attrs or not attrs["amount"]:
            sf = attrs.get("student_fee")
            if sf:
                attrs["amount"] = sf.total_amount
            else:
                attrs["amount"] = 0

        upi_transaction_id = initial.get("upi_transaction_id")
        if upi_transaction_id:
            if attrs.get("mode") == "bank":
                attrs["bank_reference_no"] = upi_transaction_id
            else:
                attrs["upi_txn_id"] = upi_transaction_id

        fee_receipt = initial.get("fee_receipt")
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

        return super().create(validated_data)


class FeeReceiptSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeeReceipt
        fields = "__all__"