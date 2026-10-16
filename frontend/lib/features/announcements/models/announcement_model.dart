class AnnouncementItem {
  final int id;
  final String title;
  final String content;
  final String category;
  final String priority;
  final String? imageUrl;
  final String? attachmentUrl;
  final String? authorName;
  final String? departmentName;
  final int? departmentId;
  final List<String> targetRoles;
  final String? semesterName;
  final int? semesterId;
  final DateTime? publishDate;
  final DateTime? expiryDate;
  final bool isPublished;
  final DateTime? createdAt;
  final String? targetAudience;
  final int? academicYearId;
  final String? academicYearName;
  final bool notifyUsers;
  final String? status;
  final String? statusLabel;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.priority,
    this.imageUrl,
    this.attachmentUrl,
    this.authorName,
    this.departmentName,
    this.departmentId,
    this.targetRoles = const [],
    this.semesterName,
    this.semesterId,
    this.publishDate,
    this.expiryDate,
    this.isPublished = true,
    this.createdAt,
    this.targetAudience = 'ALL',
    this.academicYearId,
    this.academicYearName,
    this.notifyUsers = false,
    this.status = 'PUBLISHED',
    this.statusLabel = 'Published',
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    final rolesList = json['target_roles'] is List
        ? (json['target_roles'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return AnnouncementItem(
      id: json['id'] as int,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'GENERAL',
      priority: json['priority'] ?? 'NORMAL',
      imageUrl: json['image_url'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      authorName: json['author_name'] as String?,
      departmentName: json['department_name'] as String?,
      departmentId: json['department'] as int?,
      targetRoles: rolesList,
      semesterName: json['semester_name'] as String?,
      semesterId: json['target_semester'] as int?,
      publishDate: json['publish_date'] != null ? DateTime.tryParse(json['publish_date']) : null,
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date']) : null,
      isPublished: json['is_published'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      targetAudience: json['target_audience'] as String? ?? 'ALL',
      academicYearId: json['academic_year'] as int?,
      academicYearName: json['academic_year_name'] as String?,
      notifyUsers: json['notify_users'] ?? false,
      status: json['status'] as String? ?? 'PUBLISHED',
      statusLabel: json['status_label'] as String? ?? 'Published',
    );
  }
}
