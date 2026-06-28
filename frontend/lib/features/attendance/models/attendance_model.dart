class StudentAttendanceModel {
  final int id;
  final String name;
  final String usn;
  bool isPresent; // Mutable state for the UI checkbox

  StudentAttendanceModel({
    required this.id,
    required this.name,
    required this.usn,
    this.isPresent = true, // Default to Present
  });

  // Factory to parse the API response from 'fetch_students_for_slot'
  factory StudentAttendanceModel.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceModel(
      id: json['id'],
      name: json['name'],
      usn: json['usn'] ?? 'N/A',
      isPresent: true,
    );
  }

  // Helper to create a copy (useful if you enforce immutability strictly)
  StudentAttendanceModel copyWith({bool? isPresent}) {
    return StudentAttendanceModel(
      id: id,
      name: name,
      usn: usn,
      isPresent: isPresent ?? this.isPresent,
    );
  }
}