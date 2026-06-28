class StudentFee {
  final int id;
  final String semester;
  final String academicYear;
  final String seatType;
  final double totalFee;
  final double paidAmount;
  final double balanceAmount;
  final String status; // 'pending', 'partial', 'paid'
  final String dueDate;
  final List<FeeComponent> components;

  StudentFee({
    required this.id,
    required this.semester,
    required this.academicYear,
    required this.seatType,
    required this.totalFee,
    required this.paidAmount,
    required this.balanceAmount,
    required this.status,
    required this.dueDate,
    this.components = const [],
  });

  factory StudentFee.fromJson(Map<String, dynamic> json) {
    return StudentFee(
      id: json['id'],
      // Backend serializers usually return strings for related fields
      semester: json['semester']?.toString() ?? 'N/A',
      academicYear: json['academic_year']?.toString() ?? 'N/A',
      seatType: json['seat_type']?.toString() ?? 'N/A',
      
      // Handle Decimals/Strings safely
      totalFee: double.tryParse(json['total_fee']?.toString() ?? '0') ?? 0.0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0,
      balanceAmount: double.tryParse(json['balance_amount']?.toString() ?? '0') ?? 0.0,
      
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'] ?? '',
      
      components: (json['components'] as List?)
          ?.map((e) => FeeComponent.fromJson(e))
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