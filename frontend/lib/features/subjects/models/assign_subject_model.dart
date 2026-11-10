class SubjectAssignmentRequest {
  final int departmentId;
  final List<AssignmentItem> assignments;
  final bool updateExisting;

  SubjectAssignmentRequest({
    required this.departmentId,
    required this.assignments,
    this.updateExisting = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'department_id': departmentId,
      'assignments': assignments.map((x) => x.toMap()).toList(),
      'update_existing': updateExisting,
    };
  }
}

class ExistingAssignment {
  final int id;
  final int subjectId;
  final String subjectName;
  final String subjectCode;
  final int facultyId;
  final String professorName;
  final String department;
  final int? departmentId;
  final String semester;
  final int? semesterId;
  final int? academicYearId;

  ExistingAssignment({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.facultyId,
    required this.professorName,
    required this.department,
    this.departmentId,
    required this.semester,
    this.semesterId,
    this.academicYearId,
  });

  factory ExistingAssignment.fromMap(Map<String, dynamic> map) {
    return ExistingAssignment(
      id: map['id'] ?? 0,
      subjectId: map['subject_id'] ?? 0,
      subjectName: map['subject_name'] ?? '',
      subjectCode: map['subject_code'] ?? '',
      facultyId: map['faculty_id'] ?? 0,
      professorName: map['professor_name'] ?? '',
      department: map['department'] ?? '',
      departmentId: map['department_id'],
      semester: map['semester']?.toString() ?? '',
      semesterId: map['semester_id'],
      academicYearId: map['academic_year_id'],
    );
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
  final String? departmentName; // Extra field for Department Name (Offering Dept for electives)
  final int? departmentId; // Extra field for Offering Department ID
  final String? homeDepartmentName;
  final int? homeDepartmentId;
  final bool isElective;

  AssignOption({
    required this.id, 
    required this.name, 
    this.code, 
    this.departmentName,
    this.departmentId,
    this.homeDepartmentName,
    this.homeDepartmentId,
    this.isElective = false,
  });

  factory AssignOption.fromMap(Map<String, dynamic> map) {
    int? parsedDeptId;
    if (map['department_id'] is int) {
      parsedDeptId = map['department_id'];
    } else if (map['department'] is int) {
      parsedDeptId = map['department'];
    } else if (map['department'] is Map) {
      parsedDeptId = map['department']['id'];
    } else {
      parsedDeptId = int.tryParse(map['department_id']?.toString() ?? map['department']?.toString() ?? '');
    }

    final bool isElec = map['is_elective'] == true;
    int? offeringDeptId;
    if (map['offering_department_id'] != null) {
      offeringDeptId = map['offering_department_id'] is int 
          ? map['offering_department_id'] 
          : int.tryParse(map['offering_department_id'].toString());
    } else if (map['offering_department'] is Map) {
      offeringDeptId = map['offering_department']['id'];
    } else if (map['offering_department'] is int) {
      offeringDeptId = map['offering_department'];
    }

    String? offeringDeptName = map['offering_department_name']?.toString() ?? 
        (map['offering_department'] is Map ? map['offering_department']['name']?.toString() : null);

    final String? rawDeptName = map['department_name']?.toString() ?? 
        (map['department'] is Map ? map['department']['name']?.toString() : map['department']?.toString());

    return AssignOption(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      name: map['name'] ?? map['subject_name'] ?? map['year_name'] ?? map['sem_number']?.toString() ?? '',
      code: map['code'] ?? map['subject_code'],
      departmentName: (isElec && offeringDeptName != null && offeringDeptName.isNotEmpty) 
          ? offeringDeptName 
          : rawDeptName,
      departmentId: (isElec && offeringDeptId != null) 
          ? offeringDeptId 
          : parsedDeptId,
      homeDepartmentName: rawDeptName,
      homeDepartmentId: parsedDeptId,
      isElective: isElec,
    );
  }
}