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
    class Meta:
        model = FeePayment
        fields = "__all__"
        read_only_fields = ["entered_by", "verified", "paid_on"]


class FeeReceiptSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeeReceipt
        fields = "__all__"