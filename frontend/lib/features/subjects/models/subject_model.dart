class SubjectAddModel {
  final int schemaId;
  final int departmentId;
  final int semesterId;
  final String subjectName;
  final String subjectCode;
  final bool isElective;

  SubjectAddModel({
    required this.schemaId,
    required this.departmentId,
    required this.semesterId,
    required this.subjectName,
    required this.subjectCode,
    this.isElective = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'schema': schemaId,
      'department': departmentId,
      'semester': semesterId,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'is_elective': isElective,
    };
  }
}

// Helper for Dropdowns
class SubjectOption {
  final int id;
  final String name;

  SubjectOption({required this.id, required this.name});

  factory SubjectOption.fromMap(Map<String, dynamic> map) {
    // API returns different keys for name (name, sem_number, year_name)
    return SubjectOption(
      id: map['id'],
      name: map['name'] ?? map['sem_number']?.toString() ?? '',
    );
  }
}