class CorrectionHistoryItem {
  final int id;
  final String action;
  final String fromStatus;
  final String toStatus;
  final String comments;
  final String timestamp;
  final String actorName;
  final String actorEmail;

  CorrectionHistoryItem({
    required this.id,
    required this.action,
    required this.fromStatus,
    required this.toStatus,
    required this.comments,
    required this.timestamp,
    required this.actorName,
    required this.actorEmail,
  });

  factory CorrectionHistoryItem.fromMap(Map<String, dynamic> map) {
    return CorrectionHistoryItem(
      id: map['id'] ?? 0,
      action: map['action'] ?? '',
      fromStatus: map['from_status'] ?? '',
      toStatus: map['to_status'] ?? '',
      comments: map['comments'] ?? '',
      timestamp: map['timestamp'] ?? '',
      actorName: map['actor_name'] ?? 'System',
      actorEmail: map['actor_email'] ?? '',
    );
  }
}

class CorrectionRequestItem {
  final int id;
  final String requestId;
  final int studentId;
  final String studentName;
  final String studentUsn;
  final String studentDepartmentName;
  final String category;
  final String categoryDisplay;
  final String targetRecordRef;
  final String currentValue;
  final String requestedValue;
  final String description;
  final String reason;
  final String? evidenceFile;
  final String status;
  final String statusDisplay;
  final String assignedRole;
  final String? reviewerComments;
  final String? rejectionReason;
  final String? resolutionNotes;
  final String createdAt;
  final String updatedAt;
  final String? resolvedAt;
  final List<CorrectionHistoryItem> history;

  CorrectionRequestItem({
    required this.id,
    required this.requestId,
    required this.studentId,
    required this.studentName,
    required this.studentUsn,
    required this.studentDepartmentName,
    required this.category,
    required this.categoryDisplay,
    required this.targetRecordRef,
    required this.currentValue,
    required this.requestedValue,
    required this.description,
    required this.reason,
    this.evidenceFile,
    required this.status,
    required this.statusDisplay,
    required this.assignedRole,
    this.reviewerComments,
    this.rejectionReason,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.history = const [],
  });

  factory CorrectionRequestItem.fromMap(Map<String, dynamic> map) {
    List<CorrectionHistoryItem> histList = [];
    if (map['history'] is List) {
      histList = (map['history'] as List)
          .map((h) => CorrectionHistoryItem.fromMap(h))
          .toList();
    }

    return CorrectionRequestItem(
      id: map['id'] ?? 0,
      requestId: map['request_id'] ?? '',
      studentId: map['student'] is int ? map['student'] : (map['student']?['id'] ?? 0),
      studentName: map['student_name'] ?? '',
      studentUsn: map['student_usn'] ?? '',
      studentDepartmentName: map['student_department_name'] ?? '',
      category: map['category'] ?? '',
      categoryDisplay: map['category_display'] ?? map['category'] ?? '',
      targetRecordRef: map['target_record_ref'] ?? '',
      currentValue: map['current_value'] ?? '',
      requestedValue: map['requested_value'] ?? '',
      description: map['description'] ?? '',
      reason: map['reason'] ?? '',
      evidenceFile: map['evidence_file'],
      status: (map['status'] ?? 'SUBMITTED').toString().toUpperCase(),
      statusDisplay: map['status_display'] ?? map['status'] ?? 'Submitted',
      assignedRole: map['assigned_role'] ?? '',
      reviewerComments: map['reviewer_comments'],
      rejectionReason: map['rejection_reason'],
      resolutionNotes: map['resolution_notes'],
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      resolvedAt: map['resolved_at'],
      history: histList,
    );
  }
}
