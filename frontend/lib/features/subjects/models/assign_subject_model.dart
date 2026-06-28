class SubjectAssignmentRequest {
  final int departmentId;
  final List<AssignmentItem> assignments;

  SubjectAssignmentRequest({
    required this.departmentId,
    required this.assignments,
  });

  Map<String, dynamic> toMap() {
    return {
      'department_id': departmentId,
      'assignments': assignments.map((x) => x.toMap()).toList(),
    };
  }
}

class AssignmentItem {
  final String subjectCode;
  final int facultyId;
  final int semesterId;
  final int academicYearId;

  AssignmentItem({
    required this.subjectCode,
    required this.facultyId,
    required this.semesterId,
    required this.academicYearId,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject_code': subjectCode,
      'faculty_id': facultyId,
      'semester': semesterId,
      'academic_year': academicYearId,
    };
  }
}

// Helper for Dropdown Selections
class AssignOption {
  final int id;
  final String name;
  final String? code; // Extra field for Subject Code

  AssignOption({required this.id, required this.name, this.code});

  factory AssignOption.fromMap(Map<String, dynamic> map) {
    return AssignOption(
      id: map['id'],
      // Handle various name keys from different APIs
      name: map['name'] ?? map['subject_name'] ?? map['year_name'] ?? map['sem_number']?.toString() ?? '',
      code: map['code'] ?? map['subject_code'],
    );
  }
}