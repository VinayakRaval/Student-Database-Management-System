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
  final String department;
  final String academicYear;
  final String semester;
  final String seatType;
  final double totalAmount;
  final String status;
  final String? remarks; // <--- NEW FIELD
  final List<FeeComponentInput> components;

  FeeStructure({
    required this.id,
    required this.department,
    required this.academicYear,
    required this.semester,
    required this.seatType,
    required this.totalAmount,
    required this.status,
    this.remarks, // <--- Add to constructor
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
      department: json['department_name'] ?? json['department']?.toString() ?? 'Unknown Dept',
      academicYear: json['academic_year_name'] ?? json['academic_year']?.toString() ?? '',
      semester: json['semester_name'] ?? (json['semester'] != null ? "Semester ${json['semester']}" : 'N/A'),
      seatType: json['seat_type']?.toString().toUpperCase() ?? 'N/A',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: json['approval_status'] ?? 'pending',
      remarks: json['rejection_remark'] ?? json['remark'],
      components: (json['components'] as List?)
          ?.map((e) => FeeComponentInput(
                name: e['name']?.toString() ?? '',
                amount: double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0,
              ))
          .toList() ?? [],
    );
  }
}