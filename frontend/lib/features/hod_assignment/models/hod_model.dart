class HODAssignment {
  final int id;
  final int facultyId;
  final String facultyName;
  final int departmentId;
  final String departmentName;
  final String assignedDate;
  final String? endDate; // Nullable for Current HODs

  HODAssignment({
    required this.id,
    required this.facultyId,
    required this.facultyName,
    required this.departmentId,
    required this.departmentName,
    required this.assignedDate,
    this.endDate,
  });

  factory HODAssignment.fromMap(Map<String, dynamic> map) {
    return HODAssignment(
      id: map['id'],
      facultyId: map['faculty'], 
      facultyName: map['faculty_name'] ?? 'Unknown',
      departmentId: map['department'], 
      departmentName: map['department_name'] ?? 'Unknown',
      assignedDate: map['assigned_date'] ?? '',
      endDate: map['end_date'],
    );
  }
}