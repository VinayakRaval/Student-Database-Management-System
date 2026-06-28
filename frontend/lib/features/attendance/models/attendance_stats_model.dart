class AttendanceStatsModel {
  final String subjectName;
  final String subjectCode;
  final int totalClasses;
  final int attendedClasses;
  final double percentage;

  AttendanceStatsModel({
    required this.subjectName,
    required this.subjectCode,
    required this.totalClasses,
    required this.attendedClasses,
    required this.percentage,
  });

  factory AttendanceStatsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStatsModel(
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      totalClasses: json['total_classes'],
      attendedClasses: json['attended_classes'],
      // Ensure we handle both int (e.g. 90) and double (e.g. 90.5) from JSON
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}