class SubjectAddModel {
  final int schemaId;
  final int departmentId;
  final int semesterId;
  final int? academicYearId;
  final int? offeringDepartmentId;
  final String subjectName;
  final String subjectCode;
  final bool isElective;
  final bool hasTheory;
  final bool hasLab;
  final String subjectType;
  final int credits;
  final int theoryHours;
  final int tutorialHours;
  final int practicalHours;
  final int practicalSessions;
  final int practicalDurationPerSession;
  final int totalTeachingHours;

  SubjectAddModel({
    required this.schemaId,
    required this.departmentId,
    required this.semesterId,
    this.academicYearId,
    this.offeringDepartmentId,
    required this.subjectName,
    required this.subjectCode,
    this.isElective = false,
    this.hasTheory = true,
    this.hasLab = false,
    this.subjectType = "THEORY",
    this.credits = 4,
    this.theoryHours = 3,
    this.tutorialHours = 0,
    this.practicalHours = 0,
    this.practicalSessions = 0,
    this.practicalDurationPerSession = 0,
    this.totalTeachingHours = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'schema': schemaId,
      'department': departmentId,
      'semester': semesterId,
      if (academicYearId != null) 'academic_year': academicYearId,
      if (offeringDepartmentId != null) 'offering_department': offeringDepartmentId,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'is_elective': isElective,
      'has_theory': hasTheory,
      'has_lab': hasLab,
      'subject_type': subjectType,
      'credits': credits,
      'theory_hours': theoryHours,
      'tutorial_hours': tutorialHours,
      'practical_hours': practicalHours,
      'practical_sessions': practicalSessions,
      'practical_duration_per_session': practicalDurationPerSession,
      'total_teaching_hours': totalTeachingHours,
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