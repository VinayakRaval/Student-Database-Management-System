import '../../../../core/constants/app_constants.dart';

class TimeTable {
  final int id;
  final int departmentId;
  final String departmentName;
  final int semesterId;
  final int semesterNo;
  final int academicYearId;
  final String academicYearLabel;
  final String? effectiveDate;
  final String? effectiveDateFormatted;
  final String institutionName;
  final String semesterType;
  final String formattedTitle;
  final int version;
  final String status;
  final bool isActive;
  final String? remarks;
  final int? classTeacherId;
  final String? classTeacherName;
  final String? classTeacherEmployeeId;
  final Map<String, dynamic>? classTeacherDetails;
  final List<TimeTableSlot> slots;
  final List<Map<String, dynamic>> subjectDetails;
  final Map<String, dynamic>? teachingHoursSummary;

  TimeTable({
    required this.id,
    required this.departmentId,
    required this.departmentName,
    required this.semesterId,
    required this.semesterNo,
    required this.academicYearId,
    required this.academicYearLabel,
    this.effectiveDate,
    this.effectiveDateFormatted,
    this.institutionName = CollegeConfig.institutionName,
    required this.semesterType,
    required this.formattedTitle,
    required this.version,
    required this.status,
    required this.isActive,
    this.remarks,
    this.classTeacherId,
    this.classTeacherName,
    this.classTeacherEmployeeId,
    this.classTeacherDetails,
    this.slots = const [],
    this.subjectDetails = const [],
    this.teachingHoursSummary,
  });

  static String getOrdinalSuffix(int sem) {
    if (sem >= 11 && sem <= 13) {
      return '${sem}th';
    }
    switch (sem % 10) {
      case 1:
        return '${sem}st';
      case 2:
        return '${sem}nd';
      case 3:
        return '${sem}rd';
      default:
        return '${sem}th';
    }
  }

  static String getSemesterType(int sem) {
    return sem % 2 != 0 ? 'ODD SEM' : 'EVEN SEM';
  }

  static String formatAcademicYear(String ay) {
    final clean = ay.trim();
    final reg = RegExp(r'^(\d{4})-(\d{4})$');
    final match = reg.firstMatch(clean);
    if (match != null) {
      final y1 = match.group(1)!;
      final y2 = match.group(2)!;
      return '$y1-${y2.substring(2)}';
    }
    return clean;
  }

  static String buildTitle(int sem, String academicYear) {
    final ord = getOrdinalSuffix(sem);
    final type = getSemesterType(sem);
    final formattedAy = formatAcademicYear(academicYear);
    return '$ord Sem Time Table Academic Year $formattedAy ($type)';
  }

  static String formatTime12(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '';
    try {
      final parts = timeStr.trim().split(':');
      if (parts.isEmpty) return timeStr;
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      final period = hour >= 12 ? 'PM' : 'AM';
      final h = hour % 12 == 0 ? 12 : hour % 12;
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m $period';
    } catch (_) {
      return timeStr;
    }
  }

  static String formatTimeRange12(String? start, String? end) {
    if (start == null && end == null) return '';
    if (start != null && end == null) return formatTime12(start);
    if (start == null && end != null) return formatTime12(end);
    return '${formatTime12(start)} – ${formatTime12(end)}';
  }

  factory TimeTable.fromMap(Map<String, dynamic> map) {
    final semNo = map['semester_no'] is int ? map['semester_no'] as int : int.tryParse(map['semester_no']?.toString() ?? '1') ?? 1;
    final ayLabel = map['academic_year_label']?.toString() ?? '';
    final defaultTitle = buildTitle(semNo, ayLabel);
    final defaultType = getSemesterType(semNo);

    return TimeTable(
      id: map['id'],
      departmentId: map['department'],
      departmentName: map['department_name'] ?? '',
      semesterId: map['semester'],
      semesterNo: semNo,
      academicYearId: map['academic_year'],
      academicYearLabel: ayLabel,
      effectiveDate: map['effective_date']?.toString(),
      effectiveDateFormatted: map['effective_date_formatted']?.toString(),
      institutionName: map['institution_name']?.toString() ?? CollegeConfig.institutionName,
      semesterType: map['semester_type']?.toString() ?? defaultType,
      formattedTitle: map['formatted_title']?.toString() ?? defaultTitle,
      version: map['version'] ?? 1,
      status: map['status'] ?? 'Draft',
      isActive: map['is_active'] ?? false,
      remarks: map['remarks'],
      classTeacherId: map['class_teacher_id'] is int
          ? map['class_teacher_id'] as int
          : (map['class_teacher'] is int ? map['class_teacher'] as int : null),
      classTeacherName: map['class_teacher_name']?.toString() ??
          (map['class_teacher_details'] is Map ? map['class_teacher_details']['name']?.toString() : null),
      classTeacherEmployeeId: map['class_teacher_employee_id']?.toString() ??
          (map['class_teacher_details'] is Map ? map['class_teacher_details']['faculty_id']?.toString() : null),
      classTeacherDetails: map['class_teacher_details'] is Map ? Map<String, dynamic>.from(map['class_teacher_details'] as Map) : null,
      slots: (map['slots'] as List? ?? []).map((e) => TimeTableSlot.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      subjectDetails: (map['subject_details'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      teachingHoursSummary: map['teaching_hours_summary'] is Map ? Map<String, dynamic>.from(map['teaching_hours_summary'] as Map) : null,
    );
  }
}

class TimeTableSlotBatch {
  final int? id;
  final String batchName;
  final int assignmentId;
  final String labRoom;
  final String? startTime;
  final String? endTime;
  final bool allowCoTeaching;
  final String? subjectCode;
  final String? subjectName;
  final String? facultyName;
  final String? facultyEmployeeId;
  final String? subjectDepartment;
  final String? studentDepartment;
  final String? semester;
  final int credits;
  final int theoryHours;
  final int tutorialHours;
  final int practicalHours;
  final String practicalDisplay;
  final int totalTeachingHours;

  TimeTableSlotBatch({
    this.id,
    required this.batchName,
    required this.assignmentId,
    this.labRoom = '',
    this.startTime,
    this.endTime,
    this.allowCoTeaching = false,
    this.subjectCode,
    this.subjectName,
    this.facultyName,
    this.facultyEmployeeId,
    this.subjectDepartment,
    this.studentDepartment,
    this.semester,
    this.credits = 4,
    this.theoryHours = 3,
    this.tutorialHours = 0,
    this.practicalHours = 0,
    this.practicalDisplay = '0',
    this.totalTeachingHours = 3,
  });

  factory TimeTableSlotBatch.fromMap(Map<String, dynamic> map) {
    final info = map['assignment_info'] is Map ? map['assignment_info'] as Map<String, dynamic> : {};
    return TimeTableSlotBatch(
      id: map['id'],
      batchName: map['batch_name']?.toString() ?? '',
      assignmentId: map['assignment'] is int ? map['assignment'] : int.tryParse(map['assignment']?.toString() ?? '0') ?? 0,
      labRoom: map['lab_room']?.toString() ?? '',
      startTime: map['start_time']?.toString() ?? map['effective_start_time']?.toString(),
      endTime: map['end_time']?.toString() ?? map['effective_end_time']?.toString(),
      allowCoTeaching: map['allow_co_teaching'] == true,
      subjectCode: (info['subject_code'] ?? map['subject_code'])?.toString() ?? '',
      subjectName: info['subject_name']?.toString() ?? 'Unknown Subject',
      facultyName: info['faculty_name']?.toString() ?? 'Unknown Faculty',
      facultyEmployeeId: (info['faculty_employee_id'] ?? map['faculty_employee_id'])?.toString() ?? '',
      subjectDepartment: (info['subject_department'] ?? map['branch_name'] ?? map['department_name'])?.toString(),
      studentDepartment: info['student_department']?.toString(),
      semester: (info['semester'] ?? map['semester'])?.toString(),
      credits: info['credits'] is int ? info['credits'] : (int.tryParse(info['credits']?.toString() ?? '4') ?? 4),
      theoryHours: info['theory_hours'] is int ? info['theory_hours'] : (int.tryParse(info['theory_hours']?.toString() ?? '3') ?? 3),
      tutorialHours: info['tutorial_hours'] is int ? info['tutorial_hours'] : (int.tryParse(info['tutorial_hours']?.toString() ?? '0') ?? 0),
      practicalHours: info['practical_hours'] is int ? info['practical_hours'] : (int.tryParse(info['practical_hours']?.toString() ?? '0') ?? 0),
      practicalDisplay: info['practical_display']?.toString() ?? (info['practical_hours']?.toString() ?? '0'),
      totalTeachingHours: info['total_teaching_hours'] is int ? info['total_teaching_hours'] : (int.tryParse(info['total_teaching_hours']?.toString() ?? '3') ?? 3),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'batch_name': batchName,
      'assignment': assignmentId,
      'lab_room': labRoom,
      if (startTime != null && startTime!.isNotEmpty) 'start_time': startTime,
      if (endTime != null && endTime!.isNotEmpty) 'end_time': endTime,
      'allow_co_teaching': allowCoTeaching,
    };
  }
}

class TimeTableSlot {
  final int? id;
  final String day;
  final String startTime;
  final String endTime;
  final int? assignmentId;
  final bool isBatchWise;
  final String? batchName;
  final String labRoom;
  final bool allowCoTeaching;
  final List<TimeTableSlotBatch> batches;
  
  // Display Fields
  final String? subjectCode;
  final String? subjectName;
  final String? facultyName;
  final String? facultyEmployeeId;
  final String? subjectDepartment;
  final String? studentDepartment;
  final String? semester;
  final int credits;
  final int theoryHours;
  final int tutorialHours;
  final int practicalHours;
  final String practicalDisplay;
  final int totalTeachingHours;

  TimeTableSlot({
    this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.assignmentId,
    this.isBatchWise = false,
    this.batchName,
    this.labRoom = '',
    this.allowCoTeaching = false,
    this.batches = const [],
    this.subjectCode,
    this.subjectName,
    this.facultyName,
    this.facultyEmployeeId,
    this.subjectDepartment,
    this.studentDepartment,
    this.semester,
    this.credits = 4,
    this.theoryHours = 3,
    this.tutorialHours = 0,
    this.practicalHours = 0,
    this.practicalDisplay = '0',
    this.totalTeachingHours = 3,
  });

  factory TimeTableSlot.fromMap(Map<String, dynamic> map) {
    final info = map['assignment_info'] is Map ? map['assignment_info'] as Map<String, dynamic> : {};
    final rawBatches = map['batches'] as List? ?? [];
    final parsedBatches = rawBatches.map((e) => TimeTableSlotBatch.fromMap(Map<String, dynamic>.from(e as Map))).toList();

    return TimeTableSlot(
      id: map['id'],
      day: map['day'] ?? 'MON',
      startTime: map['start_time'] ?? '',
      endTime: map['end_time'] ?? '',
      assignmentId: map['assignment'],
      isBatchWise: map['is_batch_wise'] == true || parsedBatches.isNotEmpty,
      batchName: map['batch_name'],
      labRoom: map['lab_room']?.toString() ?? '',
      allowCoTeaching: map['allow_co_teaching'] == true,
      batches: parsedBatches,
      subjectCode: (info['subject_code'] ?? map['subject_code'])?.toString() ?? '',
      subjectName: (info['subject_name'] ?? map['subject_name'])?.toString() ?? (parsedBatches.isNotEmpty ? parsedBatches.map((b) => b.subjectName).join(', ') : 'Unknown Subject'),
      facultyName: (info['faculty_name'] ?? map['faculty_name'])?.toString() ?? (parsedBatches.isNotEmpty ? parsedBatches.map((b) => '${b.batchName}: ${b.facultyName}').join(', ') : 'Unknown Faculty'),
      facultyEmployeeId: (info['faculty_employee_id'] ?? map['faculty_employee_id'])?.toString() ?? '',
      subjectDepartment: (info['subject_department'] ?? map['branch_name'] ?? map['department_name'])?.toString(),
      studentDepartment: info['student_department']?.toString(),
      semester: (map['semester'] ?? info['semester'])?.toString(),
      credits: info['credits'] is int ? info['credits'] : (int.tryParse(info['credits']?.toString() ?? '4') ?? 4),
      theoryHours: info['theory_hours'] is int ? info['theory_hours'] : (int.tryParse(info['theory_hours']?.toString() ?? '3') ?? 3),
      tutorialHours: info['tutorial_hours'] is int ? info['tutorial_hours'] : (int.tryParse(info['tutorial_hours']?.toString() ?? '0') ?? 0),
      practicalHours: info['practical_hours'] is int ? info['practical_hours'] : (int.tryParse(info['practical_hours']?.toString() ?? '0') ?? 0),
      practicalDisplay: info['practical_display']?.toString() ?? (info['practical_hours']?.toString() ?? '0'),
      totalTeachingHours: info['total_teaching_hours'] is int ? info['total_teaching_hours'] : (int.tryParse(info['total_teaching_hours']?.toString() ?? '3') ?? 3),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'start_time': startTime,
      'end_time': endTime,
      if (assignmentId != null) 'assignment': assignmentId,
      'is_batch_wise': isBatchWise,
      if (batchName != null) 'batch_name': batchName,
      'lab_room': labRoom,
      'allow_co_teaching': allowCoTeaching,
      'batches': batches.map((b) => b.toMap()).toList(),
    };
  }
}

class AssignmentOption {
  final int id;
  final String subjectName;
  final String facultyName;
  final String? facultyEmployeeId;
  final String? facultyRole;
  final String? subjectCode;
  final String? subjectDepartment;
  final bool hasLab;
  final bool hasTheory;
  final String subjectType;

  AssignmentOption({
    required this.id,
    required this.subjectName,
    required this.facultyName,
    this.facultyEmployeeId,
    this.facultyRole,
    this.subjectCode,
    this.subjectDepartment,
    this.hasLab = false,
    this.hasTheory = true,
    this.subjectType = 'THEORY',
  });

  bool get isLab => hasLab || subjectType == 'LAB' || subjectType == 'BOTH';

  String get facultyDisplay {
    if (facultyName.trim().isEmpty || facultyName == 'No faculty assigned') {
      return 'No faculty assigned';
    }
    final empTag = (facultyEmployeeId != null && facultyEmployeeId!.isNotEmpty) ? ' (ID: $facultyEmployeeId)' : '';
    return '$facultyName$empTag';
  }

  factory AssignmentOption.fromMap(Map<String, dynamic> map) {
    return AssignmentOption(
      id: map['id'],
      subjectName: map['subject_name'] ?? '',
      facultyName: map['faculty_name'] ?? '',
      facultyEmployeeId: map['faculty_employee_id']?.toString(),
      facultyRole: map['faculty_role']?.toString(),
      subjectCode: map['subject_code']?.toString(),
      subjectDepartment: map['subject_department']?.toString(),
      hasLab: map['has_lab'] == true,
      hasTheory: map['has_theory'] ?? true,
      subjectType: map['subject_type']?.toString() ?? 'THEORY',
    );
  }
}
