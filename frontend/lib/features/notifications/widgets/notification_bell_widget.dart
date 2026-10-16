import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationBellWidget extends StatefulWidget {
  final Color iconColor;
  const NotificationBellWidget({super.key, this.iconColor = const Color(0xFF13246E)});

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget> {
  int _unreadCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    _timer = Timer.periodic(const Duration(seconds: 40), (_) {
      if (mounted) _fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/announcements/notifications/unread_count/');
      int count = 0;
      if (res.data is Map && res.data['unread_count'] != null) {
        count = (res.data['unread_count'] as num).toInt();
      }

      // Also check active announcements count if needed
      try {
        final annRes = await dio.get('/announcements/');
        final dynamic raw = annRes.data;
        final List list = raw is List ? raw : (raw is Map && raw['results'] is List ? raw['results'] : []);
        if (count == 0 && list.isNotEmpty) {
          count = list.length;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (_) {}
  }

  void _showNotificationPanel() {
    final size = MediaQuery.of(context).size;
    if (size.width < 700) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SizedBox(
          height: size.height * 0.85,
          child: NotificationPanelSheet(
            isDesktopPopup: false,
            onUnreadChanged: (newCount) {
              if (mounted) setState(() => _unreadCount = newCount);
            },
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black12,
        builder: (ctx) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: kToolbarHeight + 8,
              right: 20,
              width: 440,
              height: 520,
              child: Material(
                elevation: 16,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: NotificationPanelSheet(
                    isDesktopPopup: true,
                    onUnreadChanged: (newCount) {
                      if (mounted) setState(() => _unreadCount = newCount);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: widget.iconColor, size: 24),
          tooltip: "Notifications & Announcements",
          onPressed: _showNotificationPanel,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationPanelSheet extends StatefulWidget {
  final bool isDesktopPopup;
  final ValueChanged<int>? onUnreadChanged;

  const NotificationPanelSheet({
    super.key,
    this.isDesktopPopup = false,
    this.onUnreadChanged,
  });

  @override
  State<NotificationPanelSheet> createState() => _NotificationPanelSheetState();
}

class _NotificationPanelSheetState extends State<NotificationPanelSheet> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'ALL'; // ALL, UNREAD

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      // 1. Fetch user notifications
      final resNotif = await dio.get('/announcements/notifications/');
      final dynamic rawNotif = resNotif.data;
      final List listNotif = rawNotif is List ? rawNotif : (rawNotif is Map && rawNotif['results'] is List ? rawNotif['results'] : []);

      final loaded = listNotif
          .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // 2. Fetch announcements (role-filtered by backend: Principal + HOD)
      try {
        final resAnn = await dio.get('/announcements/');
        final dynamic rawAnn = resAnn.data;
        final List listAnn = rawAnn is List ? rawAnn : (rawAnn is Map && rawAnn['results'] is List ? rawAnn['results'] : []);

        for (final ann in listAnn) {
          final m = Map<String, dynamic>.from(ann as Map);
          final int annId = (m['id'] is num) ? (m['id'] as num).toInt() : (int.tryParse(m['id']?.toString() ?? '') ?? 0);
          final exists = loaded.any((n) => n.announcementId == annId);
          if (!exists && annId != 0) {
            final deptName = m['department_name']?.toString();
            final senderLabel = m['sender_label']?.toString() ??
                (deptName != null && deptName.isNotEmpty ? "From: HOD – $deptName" : "From: Principal");
            loaded.add(NotificationItem(
              id: -annId,
              title: m['title']?.toString() ?? 'Notice',
              message: m['content']?.toString() ?? '',
              notificationType: 'ANNOUNCEMENT',
              isRead: false,
              createdAt: m['publish_date'] != null ? DateTime.tryParse(m['publish_date'].toString()) : null,
              announcementId: annId,
              announcementTitle: m['title']?.toString(),
              announcementCategory: m['category']?.toString(),
              announcementPriority: m['priority']?.toString(),
              senderLabel: senderLabel,
              authorRole: m['author_role']?.toString() ?? (deptName != null ? 'HOD' : 'Principal'),
              departmentName: deptName,
            ));
          }
        }
      } catch (_) {}

      loaded.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      final unread = loaded.where((n) => !n.isRead).length;
      widget.onUnreadChanged?.call(unread);

      if (mounted) {
        setState(() {
          _notifications = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not load notifications: $e";
        });
      }
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      if (item.id > 0) {
        final dio = ApiClient().dio;
        await dio.post('/announcements/notifications/${item.id}/mark_read/');
      }
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == item.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        }
      });
      final unread = _notifications.where((n) => !n.isRead).length;
      widget.onUnreadChanged?.call(unread);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/announcements/notifications/mark_all_read/');
    } catch (_) {}

    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
    widget.onUnreadChanged?.call(0);
  }

  void _showDetails(NotificationItem item) {
    final sender = item.senderLabel ??
        (item.departmentName != null && item.departmentName!.isNotEmpty
            ? "From: HOD – ${item.departmentName}"
            : (item.authorRole == 'Principal' ? "From: Principal" : "From: College Administration"));
    final isHod = sender.contains("HOD");
    final isPrincipal = sender.contains("Principal");
    final senderColor = isHod ? const Color(0xFF6D28D9) : (isPrincipal ? const Color(0xFF13246E) : Colors.teal.shade800);
    final senderBg = isHod ? const Color(0xFFEDE9FE) : (isPrincipal ? const Color(0xFFE0E7FF) : Colors.teal.shade50);
    final senderIcon = isHod ? Icons.business_rounded : (isPrincipal ? Icons.account_balance_rounded : Icons.notifications_active_rounded);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: senderBg,
              child: Icon(senderIcon, color: senderColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: senderBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: senderColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      sender,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: senderColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.departmentName != null && item.departmentName!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      "Dept: ${item.departmentName}",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                    ),
                  ),
                if (item.authorRole != null && item.authorRole!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      "Role: ${item.authorRole}",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                  ),
                if (item.announcementCategory != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13246E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.announcementCategory!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                    ),
                  ),
                if (item.announcementPriority != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.announcementPriority?.toUpperCase() == 'URGENT'
                          ? Colors.red.shade100
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.announcementPriority!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.announcementPriority?.toUpperCase() == 'URGENT'
                            ? Colors.red.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.message,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151)),
            ),
            if (item.createdAt != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    "Received: ${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year} at ${item.createdAt!.hour}:${item.createdAt!.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE", style: TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'ATTENDANCE':
        return Icons.calendar_today_rounded;
      case 'IA':
      case 'EXAM':
        return Icons.grade_rounded;
      case 'TIMETABLE':
        return Icons.schedule_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m <= 1 ? "Just now" : "${m}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}d ago";
    } else {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final filtered = _filter == 'UNREAD' ? _notifications.where((n) => !n.isRead).toList() : _notifications;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isDesktopPopup
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: widget.isDesktopPopup
            ? []
            : const [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -2)),
              ],
      ),
      child: Column(
        children: [
          if (!widget.isDesktopPopup)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFF13246E), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Notifications",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF13246E)),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$unreadCount",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    if (unreadCount > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF13246E),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                        onPressed: _markAllRead,
                        icon: const Icon(Icons.done_all_rounded, size: 14),
                        label: const Text("Mark all read", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.grey),
                      tooltip: "Refresh",
                      onPressed: _loadNotifications,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                      tooltip: "Close",
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text("All (${_notifications.length})"),
                  selected: _filter == 'ALL',
                  selectedColor: const Color(0xFF13246E),
                  labelStyle: TextStyle(
                    color: _filter == 'ALL' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _filter = 'ALL');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text("Unread ($unreadCount)"),
                  selected: _filter == 'UNREAD',
                  selectedColor: const Color(0xFF13246E),
                  labelStyle: TextStyle(
                    color: _filter == 'UNREAD' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _filter = 'UNREAD');
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/notifications');
                  },
                  child: const Text(
                    "View All →",
                    style: TextStyle(fontSize: 12, color: Color(0xFF13246E), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF13246E)),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 36, color: Colors.red.shade400),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                                onPressed: _loadNotifications,
                                child: const Text("Retry", style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none_rounded, size: 44, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    _filter == 'UNREAD' ? "No unread notices" : "No notifications yet",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "You are up to date on all department & campus notices.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (context, index) {
                              final n = filtered[index];
                              final sender = n.senderLabel ??
                                  (n.departmentName != null && n.departmentName!.isNotEmpty
                                      ? "From: HOD – ${n.departmentName}"
                                      : (n.authorRole == 'Principal' ? "From: Principal" : "From: Administration"));
                              final isHod = sender.contains("HOD");
                              final isPrincipal = sender.contains("Principal");
                              final senderColor = isHod
                                  ? const Color(0xFF6D28D9)
                                  : (isPrincipal ? const Color(0xFF13246E) : Colors.teal.shade800);
                              final senderBg = isHod
                                  ? const Color(0xFFEDE9FE)
                                  : (isPrincipal ? const Color(0xFFE0E7FF) : Colors.teal.shade50);

                              return InkWell(
                                onTap: () async {
                                  await _markRead(n);
                                  _showDetails(n);
                                },
                                child: Container(
                                  color: n.isRead ? Colors.white : const Color(0xFFF1F5FD),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: n.isRead
                                            ? Colors.grey.shade100
                                            : senderBg,
                                        child: Icon(
                                          _getIconForType(n.notificationType),
                                          color: n.isRead ? Colors.grey.shade600 : senderColor,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: senderBg,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: senderColor.withValues(alpha: 0.25)),
                                                  ),
                                                  child: Text(
                                                    sender,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: senderColor,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (n.createdAt != null)
                                                  Text(
                                                    _formatTime(n.createdAt!),
                                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              n.title,
                                              style: TextStyle(
                                                fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                                fontSize: 13,
                                                color: const Color(0xFF111827),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              n.message,
                                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.3),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!n.isRead) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          margin: const EdgeInsets.only(top: 5),
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF13246E),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
