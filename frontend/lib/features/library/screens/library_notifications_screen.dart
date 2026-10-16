import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/network/api_client.dart';

class LibraryNotificationsScreen extends StatefulWidget {
  const LibraryNotificationsScreen({super.key});

  @override
  State<LibraryNotificationsScreen> createState() => _LibraryNotificationsScreenState();
}

class _LibraryNotificationsScreenState extends State<LibraryNotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _notifications = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPrincipalNotifications();
  }

  Future<void> _fetchPrincipalNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final List<Map<String, dynamic>> items = [];

      // 1. Fetch announcements
      try {
        final resAnn = await dio.get('/announcements/');
        final rawAnn = resAnn.data;
        final List listAnn = rawAnn is List ? rawAnn : (rawAnn is Map && rawAnn['results'] is List ? rawAnn['results'] : []);

        for (final item in listAnn) {
          final m = Map<String, dynamic>.from(item as Map);
          final role = (m['author_role'] ?? '').toString().toUpperCase();
          final senderLabel = (m['sender_label'] ?? '').toString().toUpperCase();
          final dept = m['department_name']?.toString() ?? '';

          // Library role only receives announcements from the Principal (campus-wide)
          final isFromPrincipal = role == 'PRINCIPAL' ||
              senderLabel.contains('PRINCIPAL') ||
              (m['scope'] == 'campus' && dept.isEmpty);

          if (isFromPrincipal) {
            items.add({
              'id': m['id'],
              'title': m['title'] ?? 'Principal Circular',
              'content': m['content'] ?? '',
              'sender': 'Principal',
              'sender_label': m['sender_label'] ?? 'From: Principal',
              'category': m['category'] ?? 'OFFICIAL',
              'priority': m['priority'] ?? 'HIGH',
              'publish_date': m['publish_date'] ?? m['created_at'],
              'image_url': m['image_url'] ?? m['image'],
              'attachment_url': m['attachment_url'] ?? m['attachment'],
              'is_read': false,
            });
          }
        }
      } catch (_) {}

      // 2. Fetch direct notifications targeting Principal directives
      try {
        final resNotif = await dio.get('/announcements/notifications/');
        final rawNotif = resNotif.data;
        final List listNotif = rawNotif is List ? rawNotif : (rawNotif is Map && rawNotif['results'] is List ? rawNotif['results'] : []);

        for (final item in listNotif) {
          final m = Map<String, dynamic>.from(item as Map);
          final role = (m['author_role'] ?? '').toString().toUpperCase();
          final sender = (m['sender_label'] ?? '').toString().toUpperCase();

          if (role == 'PRINCIPAL' || sender.contains('PRINCIPAL')) {
            // Check if not already covered by announcement
            final annId = m['announcement'];
            if (annId == null || !items.any((i) => i['id'] == annId)) {
              items.add({
                'id': m['id'],
                'title': m['title'] ?? 'Directive from Principal',
                'content': m['message'] ?? '',
                'sender': 'Principal',
                'sender_label': m['sender_label'] ?? 'From: Principal',
                'category': m['announcement_category'] ?? 'DIRECTIVE',
                'priority': m['announcement_priority'] ?? 'HIGH',
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load notifications: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final title = (n['title'] ?? '').toString().toLowerCase();
      final content = (n['content'] ?? '').toString().toLowerCase();
      return title.contains(q) || content.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Principal Directives & Circulars",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Notifications",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchPrincipalNotifications,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade700),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade800)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                          onPressed: _fetchPrincipalNotifications,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Filter & Notice Banner
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13246E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_user_rounded, color: Color(0xFF13246E), size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      "Authoritative Channel: Principal's Office Only",
                                      style: TextStyle(color: Color(0xFF13246E), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${_notifications.length} Directives",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: "Search circulars and directives from Principal...",
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Notification List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text("No directives received from Principal.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  const Text("All institutional circulars will be displayed here in real time."),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final n = filtered[i];
                                final dateStr = n['publish_date']?.toString().substring(0, 10) ?? '';
                                final hasAttachment = n['attachment_url'] != null;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Sender Badge + Date
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF13246E),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.account_balance_rounded, color: Colors.white, size: 13),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    "From: Principal",
                                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                n['category'] ?? 'CIRCULAR',
                                                style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade500),
                                            const SizedBox(width: 5),
                                            Text(dateStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Title
                                        Text(
                                          n['title'] ?? 'Directive',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 8),

                                        // Body
                                        Text(
                                          n['content'] ?? '',
                                          style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
                                        ),

                                        // Image if attached
                                        if (n['image_url'] != null) ...[
                                          const SizedBox(height: 14),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              n['image_url'],
                                              height: 240,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                            ),
                                          ),
                                        ],

                                        // Attachment Button
                                        if (hasAttachment) ...[
                                          const SizedBox(height: 14),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF13246E),
                                              side: const BorderSide(color: Color(0xFF13246E)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () async {
                                              final url = Uri.tryParse(n['attachment_url']);
                                              if (url != null && await canLaunchUrl(url)) {
                                                await launchUrl(url);
                                              }
                                            },
                                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                            label: const Text("View Official Notice PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
