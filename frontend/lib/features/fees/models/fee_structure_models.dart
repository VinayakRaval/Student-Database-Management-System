class FeeDropdownItem {
  final int id;
  final String name;

  FeeDropdownItem({required this.id, required this.name});

  factory FeeDropdownItem.fromJson(Map<String, dynamic> json) {
    // 1. Safely parse ID (handle String or Int)
    final int parsedId = int.tryParse(json['id'].toString()) ?? 0;

    // 2. Safely parse Name (Check all possible keys from your backend)
    String parsedName = "Unknown";

    if (json.containsKey('name')) {
      parsedName = json['name'].toString(); // Departments
    } else if (json.containsKey('year_name')) {
      parsedName = json['year_name'].toString(); // Academic Years
    } else if (json.containsKey('sem_number')) {
      parsedName = "Semester ${json['sem_number']}"; // Semesters
    }

    return FeeDropdownItem(id: parsedId, name: parsedName);
  }
}

class FeeComponentInput {
  String name;
  double amount;

  FeeComponentInput({this.name = '', this.amount = 0.0});

  Map<String, dynamic> toJson() => {
    "name": name,
    "amount": amount,
  };
}

class FeeStructure {
  final int id;
  final int? departmentId;
  final String department;
  final int? academicYearId;
  final String academicYear;
  final int? semesterId;
  final String semester;
  final String seatType;
  final String? title;
  final String? description;
  final double totalAmount;
  final String status;
  final String? remarks;
  final String? bookletNo;
  final String? receiptNo;
  final String? receiptDate;
  final List<FeeComponentInput> components;

  FeeStructure({
    required this.id,
    this.departmentId,
    required this.department,
    this.academicYearId,
    required this.academicYear,
    this.semesterId,
    required this.semester,
    required this.seatType,
    this.title,
    this.description,
    required this.totalAmount,
    required this.status,
    this.remarks,
    this.bookletNo,
    this.receiptNo,
    this.receiptDate,
    this.components = const [],
  });

  String get semesterDisplayName {
    final s = semester.trim();
    if (s.toLowerCase().startsWith('semester') || s.toLowerCase().startsWith('sem')) {
      return s;
    }
    return 'Semester $s';
  }

  factory FeeStructure.fromJson(Map<String, dynamic> json) {
    return FeeStructure(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      departmentId: json['department'] is int
          ? json['department']
          : int.tryParse(json['department']?.toString() ?? ''),
      department: json['department_name'] ?? json['department']?.toString() ?? 'Unknown Dept',
      academicYearId: json['academic_year'] is int
          ? json['academic_year']
          : int.tryParse(json['academic_year']?.toString() ?? ''),
      academicYear: json['academic_year_name'] ?? json['academic_year']?.toString() ?? '',
      semesterId: json['semester'] is int
          ? json['semester']
          : int.tryParse(json['semester']?.toString() ?? ''),
      semester: json['semester_name'] ?? (json['semester'] != null ? "Semester ${json['semester']}" : 'N/A'),
      seatType: json['seat_type']?.toString().toUpperCase() ?? 'N/A',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: json['approval_status'] ?? 'pending',
      remarks: json['rejection_remark'] ?? json['remark'],
      bookletNo: json['booklet_no']?.toString(),
      receiptNo: json['formatted_receipt_no']?.toString(),
      receiptDate: json['receipt_date']?.toString(),
      components: (json['components'] as List?)
          ?.map((e) => FeeComponentInput(
                name: e['name']?.toString() ?? '',
                amount: double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0,
              ))
          .toList() ?? [],
    );
  }
}