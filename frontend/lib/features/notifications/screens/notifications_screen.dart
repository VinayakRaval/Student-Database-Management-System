import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/network/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'ALL'; // ALL, CAMPUS, DEPARTMENT, ALERTS, UNREAD
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final List<Map<String, dynamic>> combined = [];

      // 1. Fetch system notifications
      try {
        final resNotif = await dio.get('/announcements/notifications/');
        final dynamic rawNotif = resNotif.data;
        final List listNotif = rawNotif is List ? rawNotif : (rawNotif is Map && rawNotif['results'] is List ? rawNotif['results'] : []);

        for (final item in listNotif) {
          final m = Map<String, dynamic>.from(item as Map);
          combined.add({
            'source_type': 'NOTIFICATION',
            'id': m['id'],
            'title': m['title'] ?? 'Notification',
            'content': m['message'] ?? '',
            'notification_type': m['notification_type'] ?? 'ALERT',
            'is_read': m['is_read'] == true,
            'created_at': m['created_at'],
            'announcement_id': m['announcement'],
            'category': m['announcement_category'] ?? 'Notice',
            'priority': m['announcement_priority'] ?? 'NORMAL',
            'sender_label': m['sender_label'],
            'author_role': m['author_role'],
            'department_name': m['department_name'],
            'image_url': null,
            'attachment_url': null,
          });
        }
      } catch (e) {
        debugPrint("Error fetching notifications: $e");
      }

      // 2. Fetch published announcements (Principal campus-wide + HOD department-scoped)
      try {
        final resAnn = await dio.get('/announcements/');
        final dynamic rawAnn = resAnn.data;
        final List listAnn = rawAnn is List ? rawAnn : (rawAnn is Map && rawAnn['results'] is List ? rawAnn['results'] : []);

        for (final item in listAnn) {
          final m = Map<String, dynamic>.from(item as Map);
          final int annId = (m['id'] is num) ? (m['id'] as num).toInt() : (int.tryParse(m['id']?.toString() ?? '') ?? 0);
          final deptName = m['department_name']?.toString();
          final bool isDept = deptName != null && deptName.isNotEmpty;
          final senderLabel = m['sender_label']?.toString();
          final authorRole = m['author_role']?.toString();

          // Check if an existing notification already covers this announcement
          final notifIndex = combined.indexWhere((c) => c['announcement_id'] == annId);
          if (notifIndex != -1) {
            // Enrich notification with poster & attachments
            combined[notifIndex]['source_type'] = isDept ? 'DEPARTMENT_ANNOUNCEMENT' : 'CAMPUS_ANNOUNCEMENT';
            combined[notifIndex]['department_name'] = deptName ?? combined[notifIndex]['department_name'];
            combined[notifIndex]['sender_label'] = senderLabel ?? combined[notifIndex]['sender_label'];
            combined[notifIndex]['author_role'] = authorRole ?? combined[notifIndex]['author_role'];
            combined[notifIndex]['image_url'] = m['image_url'] ?? m['image'];
            combined[notifIndex]['attachment_url'] = m['attachment_url'] ?? m['attachment'];
            combined[notifIndex]['author_name'] = m['author_name'];
          } else {
            combined.add({
              'source_type': isDept ? 'DEPARTMENT_ANNOUNCEMENT' : 'CAMPUS_ANNOUNCEMENT',
              'id': -annId, // synthetic id
              'announcement_id': annId,
              'title': m['title'] ?? 'Announcement',
              'content': m['content'] ?? '',
              'notification_type': 'ANNOUNCEMENT',
              'is_read': false,
              'created_at': m['publish_date'] ?? m['created_at'],
              'category': m['category'] ?? 'GENERAL',
              'priority': m['priority'] ?? 'NORMAL',
              'sender_label': senderLabel,
              'author_role': authorRole,
              'department_name': deptName,
              'author_name': m['author_name'],
              'image_url': m['image_url'] ?? m['image'],
              'attachment_url': m['attachment_url'] ?? m['attachment'],
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching announcements: $e");
      }

      // Sort by date descending
      combined.sort((a, b) {
        final dtA = a['created_at'] != null ? DateTime.tryParse(a['created_at'].toString()) : null;
        final dtB = b['created_at'] != null ? DateTime.tryParse(b['created_at'].toString()) : null;
        if (dtA == null) return 1;
        if (dtB == null) return -1;
        return dtB.compareTo(dtA);
      });

      if (mounted) {
        setState(() {
          _feedItems = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load announcements and notifications: $e";
        });
      }
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    final int id = item['id'] is num ? (item['id'] as num).toInt() : 0;
    try {
      if (id > 0) {
        final dio = ApiClient().dio;
        await dio.post('/announcements/notifications/$id/mark_read/');
      }
      setState(() {
        item['is_read'] = true;
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/announcements/notifications/mark_all_read/');
    } catch (_) {}

    setState(() {
      for (final item in _feedItems) {
        item['is_read'] = true;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All announcements and notifications marked as read"), backgroundColor: Colors.green),
      );
    }
  }

  void _showImagePreview(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(40),
                      color: Colors.grey.shade100,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("Unable to load image", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open attachment at: $url")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening attachment: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _feedItems.where((n) => n['is_read'] != true).length;
    final campusCount = _feedItems.where((n) => n['source_type'] == 'CAMPUS_ANNOUNCEMENT').length;
    final deptCount = _feedItems.where((n) => n['source_type'] == 'DEPARTMENT_ANNOUNCEMENT').length;

    var filtered = _feedItems.where((item) {
      if (_activeTab == 'UNREAD' && item['is_read'] == true) return false;
      if (_activeTab == 'CAMPUS' && item['source_type'] != 'CAMPUS_ANNOUNCEMENT') return false;
      if (_activeTab == 'DEPARTMENT' && item['source_type'] != 'DEPARTMENT_ANNOUNCEMENT') return false;
      if (_activeTab == 'ALERTS' && item['source_type'] != 'NOTIFICATION') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (item['title'] ?? '').toString().toLowerCase();
        final content = (item['content'] ?? '').toString().toLowerCase();
        final cat = (item['category'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !content.contains(q) && !cat.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      // Signature dark blue navbar like Image 2
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Campus & Department Notifications",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Notifications",
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action & Summary Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Centralized Announcements & Notices",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "View institutional notices from the Principal and department announcements from your HOD",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                if (unreadCount > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text("Mark All Read", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Metric Cards
            Row(
              children: [
                _buildStatCard("ALL NOTICES", "${_feedItems.length}", Icons.campaign_rounded, const Color(0xFF13246E)),
                const SizedBox(width: 14),
                _buildStatCard("CAMPUS (PRINCIPAL)", "$campusCount", Icons.account_balance_rounded, Colors.blue.shade700),
                const SizedBox(width: 14),
                _buildStatCard("DEPARTMENT (HOD)", "$deptCount", Icons.business_rounded, const Color(0xFF7C3AED)),
                const SizedBox(width: 14),
                _buildStatCard("UNREAD", "$unreadCount", Icons.mark_email_unread_rounded, unreadCount > 0 ? Colors.red.shade700 : Colors.grey.shade700),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar & Filter Tabs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Field
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: "Search notices by keyword, title, or category...",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabChip("ALL", "All Notices (${_feedItems.length})", Icons.all_inbox_rounded),
                        const SizedBox(width: 8),
                        _buildTabChip("CAMPUS", "Campus Wide ($campusCount)", Icons.account_balance_rounded),
                        const SizedBox(width: 8),
                        _buildTabChip("DEPARTMENT", "Department ($deptCount)", Icons.business_rounded),
                        const SizedBox(width: 8),
                        _buildTabChip("ALERTS", "Alerts", Icons.notifications_active_rounded),
                        const SizedBox(width: 8),
                        _buildTabChip("UNREAD", "Unread ($unreadCount)", Icons.mark_email_unread_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(60),
                  child: CircularProgressIndicator(color: Color(0xFF13246E)),
                ),
              )
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.shade700),
                    const SizedBox(height: 10),
                    Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                      onPressed: _loadData,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
            else if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(60),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.campaign_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      "No Announcements Found",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty
                          ? "No notices matched '$_searchQuery'. Try clearing the search filter."
                          : "You have received all current notices from the Principal and Department HOD.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _buildAnnouncementCard(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String tabKey, String label, IconData icon) {
    final isSelected = _activeTab == tabKey;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF13246E)),
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF13246E),
      backgroundColor: Colors.grey.shade50,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) setState(() => _activeTab = tabKey);
      },
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return "${dt.day} $month ${dt.year}, $hour:$min $ampm";
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Notice';
    final content = item['content']?.toString() ?? '';
    final category = item['category']?.toString() ?? 'General';
    final priority = item['priority']?.toString() ?? 'NORMAL';
    final sourceType = item['source_type']?.toString() ?? 'CAMPUS_ANNOUNCEMENT';
    final deptName = item['department_name']?.toString();
    final authorName = item['author_name']?.toString();
    final authorRole = item['author_role']?.toString();
    final imageUrl = item['image_url']?.toString();
    final attachmentUrl = item['attachment_url']?.toString();
    final isRead = item['is_read'] == true;
    final created = item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) : null;

    // Sender Label & Role Enrichment
    String senderLabel = (item['sender_label'] ?? '').toString().trim();
    if (senderLabel.isEmpty) {
      if (sourceType == 'DEPARTMENT_ANNOUNCEMENT' || authorRole == 'HOD') {
        senderLabel = (deptName != null && deptName.isNotEmpty)
            ? "From: HOD – $deptName"
            : "From: HOD";
      } else if (sourceType == 'CAMPUS_ANNOUNCEMENT' || authorRole == 'Principal') {
        senderLabel = "From: Principal";
      } else {
        senderLabel = "From: College Administration";
      }
    }

    final bool isHod = senderLabel.contains("HOD") || authorRole == 'HOD' || sourceType == 'DEPARTMENT_ANNOUNCEMENT';
    final bool isPrincipal = senderLabel.contains("Principal") || authorRole == 'Principal' || sourceType == 'CAMPUS_ANNOUNCEMENT';

    Color senderColor;
    Color senderBg;
    IconData senderIcon;

    if (isHod) {
      senderColor = const Color(0xFF6D28D9); // deep royal purple
      senderBg = const Color(0xFFEDE9FE);
      senderIcon = Icons.business_rounded;
    } else if (isPrincipal) {
      senderColor = const Color(0xFF13246E); // signature navy blue
      senderBg = const Color(0xFFE0E7FF);
      senderIcon = Icons.account_balance_rounded;
    } else {
      senderColor = Colors.teal.shade800;
      senderBg = Colors.teal.shade50;
      senderIcon = Icons.notifications_active_rounded;
    }

    // Priority Styling
    Color priorityColor;
    Color priorityBg;
    if (priority.toUpperCase() == 'URGENT') {
      priorityColor = Colors.red.shade800;
      priorityBg = Colors.red.shade50;
    } else if (priority.toUpperCase() == 'IMPORTANT') {
      priorityColor = Colors.amber.shade900;
      priorityBg = Colors.amber.shade50;
    } else {
      priorityColor = Colors.grey.shade700;
      priorityBg = Colors.grey.shade100;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFF13246E).withValues(alpha: 0.35),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isRead ? Colors.black.withValues(alpha: 0.02) : const Color(0xFF13246E).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Clear Sender Identification
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isRead ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5FD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Prominent Sender Badge: e.g. "From: Principal" or "From: HOD – CSE"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: senderBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: senderColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(senderIcon, size: 14, color: senderColor),
                            const SizedBox(width: 6),
                            Text(
                              senderLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: senderColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Department / Role Scope Tag
                      if (isHod && deptName != null && deptName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.domain_rounded, size: 13, color: Colors.purple.shade700),
                              const SizedBox(width: 4),
                              Text(
                                "Dept: $deptName",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade900),
                              ),
                            ],
                          ),
                        )
                      else if (isPrincipal)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public_rounded, size: 13, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                "Campus-Wide",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                              ),
                            ],
                          ),
                        ),

                      // Priority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (!isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    if (created != null)
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(created),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Main Card Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF334155),
                  ),
                ),

                // Poster Image preview if available
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _showImagePreview(imageUrl, title),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text("Poster Preview", style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text("Click to enlarge", style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Action Footer with Sender Role & Department details
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(senderIcon, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          isHod
                              ? "Sender: Head of Department (HOD)${deptName != null ? ' • $deptName' : ''}${authorName != null && authorName.isNotEmpty ? ' ($authorName)' : ''}"
                              : isPrincipal
                                  ? "Sender: Office of the Principal${authorName != null && authorName.isNotEmpty ? ' ($authorName)' : ''}"
                                  : "Sender: College Administration",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _openAttachment(attachmentUrl),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text("Attachment / Document", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                        ],

                        if (!isRead)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF13246E),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _markRead(item),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text("Mark as read", style: TextStyle(fontSize: 12)),
                          ),
                      ],
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

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
