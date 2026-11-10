import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/providers/notification_count_manager.dart';

class AdmissionNotificationsScreen extends StatefulWidget {
  const AdmissionNotificationsScreen({super.key});

  @override
  State<AdmissionNotificationsScreen> createState() => _AdmissionNotificationsScreenState();
}

class _AdmissionNotificationsScreenState extends State<AdmissionNotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _notifications = [];
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, UNREAD, DIRECTIVES, CIRCULARS, URGENT

  @override
  void initState() {
    super.initState();
    _fetchPrincipalDirectives();
  }

  Future<void> _fetchPrincipalDirectives() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final List<Map<String, dynamic>> items = [];

      // 1. Fetch campus announcements issued by Principal
      try {
        final resAnn = await dio.get('/announcements/');
        final rawAnn = resAnn.data;
        final List listAnn = rawAnn is List
            ? rawAnn
            : (rawAnn is Map && rawAnn['results'] is List ? rawAnn['results'] : []);

        for (final item in listAnn) {
          final m = Map<String, dynamic>.from(item as Map);
          final role = (m['author_role'] ?? '').toString().toUpperCase();
          final senderLabel = (m['sender_label'] ?? '').toString().toUpperCase();
          final dept = m['department_name']?.toString() ?? '';

          // Filter for Principal circulars / campus-wide directives
          final isFromPrincipal = role == 'PRINCIPAL' ||
              senderLabel.contains('PRINCIPAL') ||
              (m['scope'] == 'campus' && dept.isEmpty);

          if (isFromPrincipal) {
            items.add({
              'id': m['id'],
              'is_announcement': true,
              'title': m['title'] ?? 'Principal Circular',
              'content': m['content'] ?? '',
              'sender': 'Principal',
              'sender_label': m['sender_label'] ?? 'From: Principal',
              'category': m['category'] ?? 'OFFICIAL',
              'priority': (m['priority'] ?? 'HIGH').toString().toUpperCase(),
              'publish_date': m['publish_date'] ?? m['created_at'],
              'image_url': m['image_url'] ?? m['image'],
              'attachment_url': m['attachment_url'] ?? m['attachment'],
              'is_read': false,
            });
          }
        }
      } catch (_) {}

      // 2. Fetch direct user notifications targeted to Admission Officer
      try {
        final resNotif = await dio.get('/announcements/notifications/');
        final rawNotif = resNotif.data;
        final List listNotif = rawNotif is List
            ? rawNotif
            : (rawNotif is Map && rawNotif['results'] is List ? rawNotif['results'] : []);

        for (final item in listNotif) {
          final m = Map<String, dynamic>.from(item as Map);
          final role = (m['author_role'] ?? '').toString().toUpperCase();
          final sender = (m['sender_label'] ?? '').toString().toUpperCase();

          // Directives from Principal or system-wide admin directives
          if (role == 'PRINCIPAL' || sender.contains('PRINCIPAL') || role == 'SYSTEM') {
            final annId = m['announcement'];
            if (annId == null || !items.any((i) => i['id'] == annId && i['is_announcement'] == true)) {
              items.add({
                'id': m['id'],
                'is_announcement': false,
                'title': m['title'] ?? 'Directive from Principal',
                'content': m['message'] ?? '',
                'sender': 'Principal',
                'sender_label': m['sender_label'] ?? 'From: Principal',
                'category': m['announcement_category'] ?? 'DIRECTIVE',
                'priority': (m['announcement_priority'] ?? 'HIGH').toString().toUpperCase(),
                'publish_date': m['created_at'],
                'image_url': null,
                'attachment_url': null,
                'is_read': m['is_read'] == true,
              });
            }
          }
        }
      } catch (_) {}

      // Sort latest first
      items.sort((a, b) {
        final da = DateTime.tryParse(a['publish_date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['publish_date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
        final unread = items.where((n) => n['is_read'] != true).length;
        NotificationCountManager.instance.setCount(unread);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load Principal directives: $e";
        });
      }
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    try {
      final dio = ApiClient().dio;
      if (item['is_announcement'] != true) {
        await dio.post('/announcements/notifications/${item['id']}/mark_read/');
      }
      setState(() {
        item['is_read'] = true;
      });
      final unread = _notifications.where((n) => n['is_read'] != true).length;
      NotificationCountManager.instance.setCount(unread);
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/announcements/notifications/mark_all_read/');
      setState(() {
        for (final n in _notifications) {
          n['is_read'] = true;
        }
      });
      NotificationCountManager.instance.setCount(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All directives marked as read"),
            backgroundColor: Color(0xFF13246E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openAttachment(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open attachment")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to open link: $e")),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    return _notifications.where((n) {
      // 1. Text Search Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (n['title'] ?? '').toString().toLowerCase();
        final content = (n['content'] ?? '').toString().toLowerCase();
        final cat = (n['category'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !content.contains(q) && !cat.contains(q)) {
          return false;
        }
      }

      // 2. Tab Filter
      if (_selectedFilter == 'UNREAD') {
        return n['is_read'] != true;
      } else if (_selectedFilter == 'DIRECTIVES') {
        return n['category'] == 'DIRECTIVE';
      } else if (_selectedFilter == 'CIRCULARS') {
        return n['category'] == 'OFFICIAL' || n['is_announcement'] == true;
      } else if (_selectedFilter == 'URGENT') {
        final p = (n['priority'] ?? '').toString().toUpperCase();
        return p == 'URGENT' || p == 'HIGH';
      }

      return true;
    }).toList();
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return "Recent";
    try {
      final dt = DateTime.parse(dateVal.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m ago";
      } else if (diff.inHours < 24) {
        return "${diff.inHours}h ago";
      } else if (diff.inDays < 7) {
        return "${diff.inDays}d ago";
      } else {
        return DateFormat("dd MMM yyyy, hh:mm a").format(dt);
      }
    } catch (_) {
      return dateVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredNotifications();
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchPrincipalDirectives,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              _buildHeroBanner(unreadCount),
              const SizedBox(height: 16),

              // Filter & Search Bar
              _buildFilterToolbar(),
              const SizedBox(height: 16),

              // Notification List or Empty State
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                _buildErrorState()
              else if (filtered.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildNotificationCard(filtered[index]),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(int unreadCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEBF3FE),
            Color(0xFFF0F6FF),
            Color(0xFFE4EFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4F8)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -30,
            bottom: -30,
            child: Opacity(
              opacity: 0.25,
              child: Container(
                width: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFBFDBFE),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 28,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            "Principal Directives & Notifications",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "$unreadCount Unread",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Official institutional directives, policy notices, and admission guidance issued by the Principal.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadCount > 0)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text("Mark All Read", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _markAllAsRead,
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF13246E), size: 22),
                    tooltip: "Refresh Directives",
                    onPressed: _fetchPrincipalDirectives,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search directives by keyword, title, or category...",
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("ALL", "All Notifications (${_notifications.length})"),
                const SizedBox(width: 8),
                _buildFilterChip("UNREAD", "Unread Only"),
                const SizedBox(width: 8),
                _buildFilterChip("DIRECTIVES", "Directives"),
                const SizedBox(width: 8),
                _buildFilterChip("CIRCULARS", "Official Circulars"),
                const SizedBox(width: 8),
                _buildFilterChip("URGENT", "Urgent / High Priority"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF13246E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF13246E) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final isRead = item['is_read'] == true;
    final title = item['title']?.toString() ?? 'Notification';
    final content = item['content']?.toString() ?? '';
    final priority = (item['priority'] ?? 'NORMAL').toString().toUpperCase();
    final category = (item['category'] ?? 'OFFICIAL').toString().toUpperCase();
    final senderLabel = item['sender_label']?.toString() ?? 'From: Principal';
    final dateStr = _formatDate(item['publish_date']);
    final attachmentUrl = item['attachment_url']?.toString();
    final imageUrl = item['image_url']?.toString();

    // Priority color
    Color priorityColor = const Color(0xFF3B82F6);
    Color priorityBg = const Color(0xFFEFF6FF);
    if (priority == 'URGENT') {
      priorityColor = const Color(0xFFDC2626);
      priorityBg = const Color(0xFFFEF2F2);
    } else if (priority == 'HIGH') {
      priorityColor = const Color(0xFFEA580C);
      priorityBg = const Color(0xFFFFF7ED);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left accent bar for unread
          if (!isRead)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF13246E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with pills
                Row(
                  children: [
                    // Sender Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 4),
                          Text(
                            senderLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Priority Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Category Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Timestamp
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Content
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                ),

                // Image preview if present
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ],

                // Actions row
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (attachmentUrl != null && attachmentUrl.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF13246E),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.attach_file_rounded, size: 14),
                        label: const Text("View Attachment", style: TextStyle(fontSize: 12)),
                        onPressed: () => _openAttachment(attachmentUrl),
                      ),
                    const Spacer(),
                    if (!isRead)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF13246E),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text("Mark Read", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _markAsRead(item),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF5FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Directives or Notifications",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Official directives and circulars issued by the Principal will appear here.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 40),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? "An error occurred",
            style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: _fetchPrincipalDirectives,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
