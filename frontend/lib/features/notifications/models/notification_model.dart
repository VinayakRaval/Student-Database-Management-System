class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime? createdAt;
  final int? announcementId;
  final String? announcementTitle;
  final String? announcementCategory;
  final String? announcementPriority;
  final String? senderLabel;
  final String? authorRole;
  final String? departmentName;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    this.createdAt,
    this.announcementId,
    this.announcementTitle,
    this.announcementCategory,
    this.announcementPriority,
    this.senderLabel,
    this.authorRole,
    this.departmentName,
  });

  NotificationItem copyWith({
    int? id,
    String? title,
    String? message,
    String? notificationType,
    bool? isRead,
    DateTime? createdAt,
    int? announcementId,
    String? announcementTitle,
    String? announcementCategory,
    String? announcementPriority,
    String? senderLabel,
    String? authorRole,
    String? departmentName,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      announcementId: announcementId ?? this.announcementId,
      announcementTitle: announcementTitle ?? this.announcementTitle,
      announcementCategory: announcementCategory ?? this.announcementCategory,
      announcementPriority: announcementPriority ?? this.announcementPriority,
      senderLabel: senderLabel ?? this.senderLabel,
      authorRole: authorRole ?? this.authorRole,
      departmentName: departmentName ?? this.departmentName,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'GENERAL',
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      announcementId: json['announcement'] != null ? int.tryParse(json['announcement'].toString()) : null,
      announcementTitle: json['announcement_title']?.toString(),
      announcementCategory: json['announcement_category']?.toString(),
      announcementPriority: json['announcement_priority']?.toString(),
      senderLabel: json['sender_label']?.toString(),
      authorRole: json['author_role']?.toString(),
      departmentName: json['department_name']?.toString(),
    );
  }
}
