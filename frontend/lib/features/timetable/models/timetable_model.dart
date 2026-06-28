class TimeTable {
  final int id;
  final int departmentId;
  final String departmentName;
  final int semesterId;
  final int semesterNo;
  final int academicYearId;
  final String academicYearLabel;
  final int version;
  final String status;
  final bool isActive;
  final String? remarks;
  final List<TimeTableSlot> slots;

  TimeTable({
    required this.id,
    required this.departmentId,
    required this.departmentName,
    required this.semesterId,
    required this.semesterNo,
    required this.academicYearId,
    required this.academicYearLabel,
    required this.version,
    required this.status,
    required this.isActive,
    this.remarks,
    this.slots = const [],
  });

  factory TimeTable.fromMap(Map<String, dynamic> map) {
    return TimeTable(
      id: map['id'],
      departmentId: map['department'],
      departmentName: map['department_name'] ?? '',
      semesterId: map['semester'],
      semesterNo: map['semester_no'] ?? 0,
      academicYearId: map['academic_year'],
      academicYearLabel: map['academic_year_label'] ?? '',
      version: map['version'] ?? 1,
      status: map['status'] ?? 'Draft',
      isActive: map['is_active'] ?? false,
      remarks: map['remarks'],
      slots: (map['slots'] as List? ?? []).map((e) => TimeTableSlot.fromMap(e)).toList(),
    );
  }
}

class TimeTableSlot {
  final int? id;
  final String day;
  final String startTime;
  final String endTime;
  final int assignmentId;
  
  // Display Fields
  final String? subjectCode; // Added this field
  final String? subjectName;
  final String? facultyName;

  TimeTableSlot({
    this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.assignmentId,
    this.subjectCode,
    this.subjectName,
    this.facultyName,
  });

  factory TimeTableSlot.fromMap(Map<String, dynamic> map) {
    final info = map['assignment_info'] ?? {};
    return TimeTableSlot(
      id: map['id'],
      day: map['day'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      assignmentId: map['assignment'],
      subjectCode: info['subject_code'] ?? '', // Extract code
      subjectName: info['subject_name'] ?? 'Unknown Subject',
      facultyName: info['faculty_name'] ?? 'Unknown Faculty',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'start_time': startTime,
      'end_time': endTime,
      'assignment': assignmentId,
    };
  }
}

// AssignmentOption helper remains same...
class AssignmentOption {
  final int id;
  final String subjectName;
  final String facultyName;

  AssignmentOption({required this.id, required this.subjectName, required this.facultyName});

  factory AssignmentOption.fromMap(Map<String, dynamic> map) {
    return AssignmentOption(
      id: map['id'],
      subjectName: map['subject_name'] ?? '',
      facultyName: map['faculty_name'] ?? '',
    );
  }
}