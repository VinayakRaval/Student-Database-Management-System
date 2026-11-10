class AttendanceSessionItem {
  final String date;
  final String status;
  final int sessionCount;
  final String? startTime;
  final String? endTime;
  final String? timing;
  final bool isExtraClass;

  AttendanceSessionItem({
    required this.date,
    required this.status,
    required this.sessionCount,
    this.startTime,
    this.endTime,
    this.timing,
    this.isExtraClass = false,
  });

  factory AttendanceSessionItem.fromJson(Map<String, dynamic> json) {
    final st = json['start_time']?.toString();
    final et = json['end_time']?.toString();
    String? t = json['timing']?.toString();
    if ((t == null || t.isEmpty) && st != null && et != null) {
      t = "$st - $et";
    }
    return AttendanceSessionItem(
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Present',
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 1,
      startTime: st,
      endTime: et,
      timing: t,
      isExtraClass: json['is_extra_class'] == true,
    );
  }
}

class AttendanceStatsModel {
  final int? subjectId;
  final String subjectName;
  final String subjectCode;
  final int totalClasses;
  final int attendedClasses;
  final double percentage;
  final String statusLabel;
  final List<AttendanceSessionItem> sessions;

  AttendanceStatsModel({
    this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.totalClasses,
    required this.attendedClasses,
    required this.percentage,
    this.statusLabel = '',
    this.sessions = const [],
  });

  factory AttendanceStatsModel.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'] is List ? (json['sessions'] as List) : [];
    return AttendanceStatsModel(
      subjectId: json['subject_id'] as int?,
      subjectName: json['subject_name']?.toString() ?? 'Subject',
      subjectCode: json['subject_code']?.toString() ?? '',
      totalClasses: (json['total_classes'] as num?)?.toInt() ?? 0,
      attendedClasses: (json['attended_classes'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      statusLabel: json['status_label']?.toString() ?? '',
      sessions: rawSessions
          .map((e) => AttendanceSessionItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}