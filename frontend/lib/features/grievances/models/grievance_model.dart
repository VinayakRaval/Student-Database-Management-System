class GrievanceCategoryModel {
  final int id;
  final String code;
  final String name;
  final String description;
  final String defaultTargetRole;
  final int slaDays;
  final bool isConfidentialByDefault;
  final bool isActive;

  GrievanceCategoryModel({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.defaultTargetRole = 'HOD',
    this.slaDays = 7,
    this.isConfidentialByDefault = false,
    this.isActive = true,
  });

  factory GrievanceCategoryModel.fromMap(Map<String, dynamic> map) {
    return GrievanceCategoryModel(
      id: map['id'] ?? 0,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      defaultTargetRole: map['default_target_role'] ?? 'HOD',
      slaDays: map['sla_days'] ?? 7,
      isConfidentialByDefault: map['is_confidential_by_default'] == true,
      isActive: map['is_active'] != false,
    );
  }
}

class GrievanceActivityModel {
  final int id;
  final int grievanceId;
  final int? actorId;
  final String actorName;
  final String actorRole;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String notes;
  final String? attachmentUrl;
  final DateTime createdAt;

  GrievanceActivityModel({
    required this.id,
    required this.grievanceId,
    this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    this.fromStatus,
    this.toStatus,
    required this.notes,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory GrievanceActivityModel.fromMap(Map<String, dynamic> map) {
    return GrievanceActivityModel(
      id: map['id'] ?? 0,
      grievanceId: map['grievance'] ?? 0,
      actorId: map['actor'],
      actorName: map['actor_name'] ?? 'System',
      actorRole: map['actor_role'] ?? '',
      action: map['action'] ?? '',
      fromStatus: map['from_status'],
      toStatus: map['to_status'],
      notes: map['notes'] ?? '',
      attachmentUrl: map['attachment_url'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class GrievanceUserPermissions {
  final bool canRespond;
  final bool canAssign;
  final bool canEscalate;
  final bool canResolve;
  final bool canReject;
  final bool canClose;
  final bool canRequestInfo;
  final bool canProvideInfo;
  final bool canRequestReopen;
  final bool canReopen;

  GrievanceUserPermissions({
    this.canRespond = false,
    this.canAssign = false,
    this.canEscalate = false,
    this.canResolve = false,
    this.canReject = false,
    this.canClose = false,
    this.canRequestInfo = false,
    this.canProvideInfo = false,
    this.canRequestReopen = false,
    this.canReopen = false,
  });

  factory GrievanceUserPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return GrievanceUserPermissions();
    return GrievanceUserPermissions(
      canRespond: map['can_respond'] == true,
      canAssign: map['can_assign'] == true,
      canEscalate: map['can_escalate'] == true,
      canResolve: map['can_resolve'] == true,
      canReject: map['can_reject'] == true,
      canClose: map['can_close'] == true,
      canRequestInfo: map['can_request_info'] == true,
      canProvideInfo: map['can_provide_info'] == true,
      canRequestReopen: map['can_request_reopen'] == true,
      canReopen: map['can_reopen'] == true,
    );
  }
}

class GrievanceModel {
  final int id;
  final String topic;
  final String description;
  final int? categoryId;
  final String categoryName;
  final String priority;
  final String status;
  final int? departmentId;
  final String? departmentName;
  final String complainantName;
  final String complainantRole;
  final String? complainantEmail;
  final String? studentUsn;
  final String targetRole;
  final int? targetUserId;
  final String assignedOfficerName;
  final String? attachmentUrl;
  final bool isConfidential;
  final String? response;
  final String? resolutionRemarks;
  final String? rejectionReason;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final DateTime? closedAt;
  final String? infoRequestedNotes;
  final String? infoProvidedNotes;
  final bool isEscalated;
  final String? escalatedToName;
  final DateTime? escalatedAt;
  final String? escalationReason;
  final bool reopenRequested;
  final String? reopenRequestReason;
  final DateTime? reopenRequestedAt;
  final bool isReopened;
  final DateTime? reopenedAt;
  final String? reopenedByName;
  final bool isOverdue;
  final int daysOpen;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GrievanceActivityModel> activities;
  final GrievanceUserPermissions userPermissions;

  GrievanceModel({
    required this.id,
    required this.topic,
    required this.description,
    this.categoryId,
    required this.categoryName,
    this.priority = 'MEDIUM',
    this.status = 'SUBMITTED',
    this.departmentId,
    this.departmentName,
    required this.complainantName,
    required this.complainantRole,
    this.complainantEmail,
    this.studentUsn,
    required this.targetRole,
    this.targetUserId,
    required this.assignedOfficerName,
    this.attachmentUrl,
    this.isConfidential = false,
    this.response,
    this.resolutionRemarks,
    this.rejectionReason,
    this.resolvedAt,
    this.resolvedByName,
    this.closedAt,
    this.infoRequestedNotes,
    this.infoProvidedNotes,
    this.isEscalated = false,
    this.escalatedToName,
    this.escalatedAt,
    this.escalationReason,
    this.reopenRequested = false,
    this.reopenRequestReason,
    this.reopenRequestedAt,
    this.isReopened = false,
    this.reopenedAt,
    this.reopenedByName,
    this.isOverdue = false,
    this.daysOpen = 0,
    required this.createdAt,
    required this.updatedAt,
    this.activities = const [],
    required this.userPermissions,
  });

  factory GrievanceModel.fromMap(Map<String, dynamic> map) {
    List<GrievanceActivityModel> acts = [];
    if (map['activities'] is List) {
      acts = (map['activities'] as List)
          .map((a) => GrievanceActivityModel.fromMap(a as Map<String, dynamic>))
          .toList();
    }

    return GrievanceModel(
      id: map['id'] ?? 0,
      topic: map['topic'] ?? '',
      description: map['description'] ?? '',
      categoryId: map['category'] is int ? map['category'] : null,
      categoryName: map['category_title'] ?? map['category_name'] ?? 'Academic',
      priority: (map['priority'] ?? 'MEDIUM').toString().toUpperCase(),
      status: (map['status'] ?? 'SUBMITTED').toString().toUpperCase(),
      departmentId: map['department'] is int ? map['department'] : null,
      departmentName: map['department_name'],
      complainantName: map['complainant_name'] ?? map['student_name'] ?? 'Complainant',
      complainantRole: (map['complainant_role'] ?? 'STUDENT').toString().toUpperCase(),
      complainantEmail: map['complainant_email'],
      studentUsn: map['student_usn'],
      targetRole: (map['target_role'] ?? 'HOD').toString().toUpperCase(),
      targetUserId: map['target_user'] is int ? map['target_user'] : null,
      assignedOfficerName: map['assigned_officer_name'] ?? map['target_name'] ?? 'Unassigned',
      attachmentUrl: map['attachment_url'],
      isConfidential: map['is_confidential'] == true,
      response: map['response'],
      resolutionRemarks: map['resolution_remarks'] ?? map['response'],
      rejectionReason: map['rejection_reason'],
      resolvedAt: map['resolved_at'] != null ? DateTime.tryParse(map['resolved_at']) : null,
      resolvedByName: map['resolved_by_name'],
      closedAt: map['closed_at'] != null ? DateTime.tryParse(map['closed_at']) : null,
      infoRequestedNotes: map['info_requested_notes'],
      infoProvidedNotes: map['info_provided_notes'],
      isEscalated: map['is_escalated'] == true || map['status'] == 'ESCALATED',
      escalatedToName: map['escalated_to_name'],
      escalatedAt: map['escalated_at'] != null ? DateTime.tryParse(map['escalated_at']) : null,
      escalationReason: map['escalation_reason'],
      reopenRequested: map['reopen_requested'] == true,
      reopenRequestReason: map['reopen_request_reason'],
      reopenRequestedAt: map['reopen_requested_at'] != null ? DateTime.tryParse(map['reopen_requested_at']) : null,
      isReopened: map['is_reopened'] == true || map['status'] == 'REOPENED',
      reopenedAt: map['reopened_at'] != null ? DateTime.tryParse(map['reopened_at']) : null,
      reopenedByName: map['reopened_by_name'],
      isOverdue: map['is_overdue'] == true,
      daysOpen: map['days_open'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) ?? DateTime.now() : DateTime.now(),
      activities: acts,
      userPermissions: GrievanceUserPermissions.fromMap(map['user_permissions'] as Map<String, dynamic>?),
    );
  }
}

class GrievanceStatsModel {
  final int total;
  final int submitted;
  final int underReview;
  final int inProgress;
  final int awaitingInfo;
  final int resolved;
  final int closed;
  final int rejected;
  final int escalated;
  final int reopened;
  final int overdue;
  final Map<String, int> byPriority;
  final List<Map<String, dynamic>> byCategory;
  final List<Map<String, dynamic>> byDepartment;

  GrievanceStatsModel({
    this.total = 0,
    this.submitted = 0,
    this.underReview = 0,
    this.inProgress = 0,
    this.awaitingInfo = 0,
    this.resolved = 0,
    this.closed = 0,
    this.rejected = 0,
    this.escalated = 0,
    this.reopened = 0,
    this.overdue = 0,
    this.byPriority = const {},
    this.byCategory = const [],
    this.byDepartment = const [],
  });

  factory GrievanceStatsModel.fromMap(Map<String, dynamic> map) {
    Map<String, int> prioMap = {};
    if (map['by_priority'] is Map) {
      (map['by_priority'] as Map).forEach((k, v) {
        prioMap[k.toString()] = v is int ? v : int.tryParse(v.toString()) ?? 0;
      });
    }

    List<Map<String, dynamic>> cats = [];
    if (map['by_category'] is List) {
      cats = List<Map<String, dynamic>>.from(map['by_category']);
    }

    List<Map<String, dynamic>> depts = [];
    if (map['by_department'] is List) {
      depts = List<Map<String, dynamic>>.from(map['by_department']);
    }

    return GrievanceStatsModel(
      total: map['total'] ?? 0,
      submitted: map['submitted'] ?? 0,
      underReview: map['under_review'] ?? 0,
      inProgress: map['in_progress'] ?? 0,
      awaitingInfo: map['awaiting_info'] ?? 0,
      resolved: map['resolved'] ?? 0,
      closed: map['closed'] ?? 0,
      rejected: map['rejected'] ?? 0,
      escalated: map['escalated'] ?? 0,
      reopened: map['reopened'] ?? 0,
      overdue: map['overdue'] ?? 0,
      byPriority: prioMap,
      byCategory: cats,
      byDepartment: depts,
    );
  }
}

class OfficerModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? department;

  OfficerModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.department,
  });

  factory OfficerModel.fromMap(Map<String, dynamic> map) {
    return OfficerModel(
      id: map['id'] ?? 0,
      name: map['name'] ?? map['email'] ?? 'Officer',
      email: map['email'] ?? '',
      role: (map['role'] ?? '').toString().toUpperCase(),
      department: map['department'],
    );
  }
}
