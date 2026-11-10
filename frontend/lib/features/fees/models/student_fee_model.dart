class StudentFee {
  final int id;
  final String studentName;
  final String studentUsn;
  final String departmentName;
  final String departmentCode;
  final String semester;
  final String academicYear;
  final String seatType;
  final double totalFee;
  final double concessionAmount;
  final String? concessionReason;
  final String? concessionApprovedByName;
  final String? concessionApprovedOn;
  final double netPayable;
  final double paidAmount;
  final double balanceAmount;
  final String status; // 'pending', 'partial', 'paid'
  final String dueDate;
  final int? receiptId;
  final String? receiptNo;
  final String? receiptDate;
  final String? bookletNo;
  final String? formattedReceiptNo;
  final List<FeeComponent> components;
  final List<PaymentRecord> payments;

  StudentFee({
    required this.id,
    this.studentName = '',
    this.studentUsn = '',
    this.departmentName = 'Computer Science and Engineering',
    this.departmentCode = 'CSE',
    required this.semester,
    required this.academicYear,
    required this.seatType,
    required this.totalFee,
    this.concessionAmount = 0.0,
    this.concessionReason,
    this.concessionApprovedByName,
    this.concessionApprovedOn,
    this.netPayable = 0.0,
    required this.paidAmount,
    required this.balanceAmount,
    required this.status,
    required this.dueDate,
    this.receiptId,
    this.receiptNo,
    this.receiptDate,
    this.bookletNo,
    this.formattedReceiptNo,
    this.components = const [],
    this.payments = const [],
  });

  factory StudentFee.fromJson(Map<String, dynamic> json) {
    final tot = double.tryParse(json['total_fee']?.toString() ?? '0') ?? 0.0;
    final conc = double.tryParse(json['concession_amount']?.toString() ?? '0') ?? 0.0;
    final net = double.tryParse(json['net_payable']?.toString() ?? '') ?? (tot - conc > 0 ? tot - conc : 0.0);

    return StudentFee(
      id: json['id'] ?? 0,
      studentName: json['student_name']?.toString() ?? '',
      studentUsn: json['student_usn']?.toString() ?? '',
      departmentName: json['department_name']?.toString() ?? 'Computer Science and Engineering',
      departmentCode: json['department_code']?.toString() ?? 'CSE',
      semester: json['semester']?.toString() ?? 'N/A',
      academicYear: json['academic_year']?.toString() ?? 'N/A',
      seatType: json['seat_type']?.toString() ?? 'N/A',
      totalFee: tot,
      concessionAmount: conc,
      concessionReason: json['concession_reason']?.toString(),
      concessionApprovedByName: json['concession_approved_by_name']?.toString(),
      concessionApprovedOn: json['concession_approved_on']?.toString(),
      netPayable: net,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0,
      balanceAmount: double.tryParse(json['balance_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'] ?? '',
      receiptId: json['receipt_id'] is int ? json['receipt_id'] : int.tryParse(json['receipt_id']?.toString() ?? ''),
      receiptNo: json['receipt_no']?.toString(),
      receiptDate: json['receipt_date']?.toString(),
      bookletNo: json['booklet_no']?.toString(),
      formattedReceiptNo: json['formatted_receipt_no']?.toString(),
      components: (json['components'] as List?)
          ?.map((e) => FeeComponent.fromJson(e))
          .toList() ?? [],
      payments: (json['payments'] as List?)
          ?.map((e) => PaymentRecord.fromJson(e))
          .toList() ?? [],
    );
  }
}

class FeeComponent {
  final String name;
  final double amount;

  FeeComponent({required this.name, required this.amount});

  factory FeeComponent.fromJson(Map<String, dynamic> json) {
    return FeeComponent(
      name: json['name'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
    );
  }
}

class PaymentRecord {
  final int id;
  final double amount;
  final String mode;
  final String modeDisplay;
  final String? paidOn;
  final bool verified;
  final bool isReversed;
  final String verificationStatus;
  final String referenceNo;
  final String? receiptNo;
  final String? remark;
  final String? reversalReason;
  final String? proofUrl;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.mode,
    required this.modeDisplay,
    this.paidOn,
    required this.verified,
    required this.isReversed,
    this.verificationStatus = 'PENDING',
    required this.referenceNo,
    this.receiptNo,
    this.remark,
    this.reversalReason,
    this.proofUrl,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final isRev = json['is_reversed'] == true;
    final isVer = json['verified'] == true;
    final rem = json['remark']?.toString();
    String vStatus = json['verification_status']?.toString() ?? '';
    if (vStatus.isEmpty) {
      if (isRev) {
        vStatus = 'REVERSED';
      } else if (isVer) {
        vStatus = 'VERIFIED';
      } else if (rem != null && rem.toLowerCase().contains('reject')) {
        vStatus = 'REJECTED';
      } else {
        vStatus = 'PENDING';
      }
    }

    return PaymentRecord(
      id: json['id'] ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      mode: json['mode']?.toString() ?? 'cash',
      modeDisplay: json['mode_display']?.toString() ?? 'Cash',
      paidOn: json['paid_on']?.toString(),
      verified: isVer,
      isReversed: isRev,
      verificationStatus: vStatus,
      referenceNo: json['reference_no']?.toString() ?? '',
      receiptNo: json['receipt_no']?.toString(),
      remark: rem,
      reversalReason: json['reversal_reason']?.toString(),
      proofUrl: json['proof_url']?.toString(),
    );
  }
}