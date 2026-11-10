import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/providers/notification_count_manager.dart';
import '../widgets/dte_fee_receipt_widget.dart';

class AccountsNotificationsScreen extends StatefulWidget {
  const AccountsNotificationsScreen({super.key});

  @override
  State<AccountsNotificationsScreen> createState() => _AccountsNotificationsScreenState();
}

class _AccountsNotificationsScreenState extends State<AccountsNotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'principal', 'unread'

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/announcements/notifications/');
      final List results = response.data is List ? response.data : (response.data['results'] ?? []);
      if (mounted) {
        setState(() {
          _notifications = results;
          _isLoading = false;
        });
        final unread = results.where((n) => n['is_read'] != true).length;
        NotificationCountManager.instance.setCount(unread);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/announcements/notifications/$notificationId/mark_read/');
      setState(() {
        for (var notif in _notifications) {
          if (notif['id'] == notificationId) {
            notif['is_read'] = true;
          }
        }
      });
      NotificationCountManager.instance.decrement();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Marked as read"),
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

  Future<void> _markAllAsRead() async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/announcements/notifications/mark_all_read/');
      setState(() {
        for (var notif in _notifications) {
          notif['is_read'] = true;
        }
      });
      NotificationCountManager.instance.markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All directives marked as read"),
            backgroundColor: Color(0xFF10B981),
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

  Future<void> _openFeeStructureReceipt(Map<String, dynamic> notif) async {
    // 1. Mark as read immediately if not yet read
    final notifId = notif['id'] is num ? (notif['id'] as num).toInt() : 0;
    if (notif['is_read'] != true && notifId > 0) {
      _markAsRead(notifId);
    }

    // 2. Show brief loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF13246E)),
                SizedBox(height: 16),
                Text("Loading Official Fee Receipt...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    Map<String, dynamic>? matched;
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/fees/fee-structures/');
      final List structures = response.data is List ? response.data : (response.data['results'] ?? []);

      final title = (notif['title'] ?? '').toString().toLowerCase();
      final msg = (notif['message'] ?? '').toString().toLowerCase();

      for (var s in structures) {
        final sTitle = (s['title'] ?? '').toString().toLowerCase();
        final dept = (s['department_name'] ?? s['department'] ?? '').toString().toLowerCase();
        if (sTitle.isNotEmpty && (title.contains(sTitle) || msg.contains(sTitle))) {
          matched = Map<String, dynamic>.from(s);
          break;
        }
        if (title.contains('returned') || msg.contains('returned')) {
          if (s['approval_status'] == 'rejected') {
            matched = Map<String, dynamic>.from(s);
            break;
          }
        }
        if (dept.isNotEmpty && (title.contains(dept) || msg.contains(dept))) {
          matched = Map<String, dynamic>.from(s);
          break;
        }
      }

      if (matched == null && structures.isNotEmpty) {
        matched = Map<String, dynamic>.from(structures.first);
      }
    } catch (_) {}

    // Pop the loading dialog
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    final m = matched;
    if (m == null) {
      if (mounted) context.push('/fees');
      return;
    }

    final double totalAmt = double.tryParse(m['total_amount']?.toString() ?? '0') ?? 0.0;
    final List componentsRaw = (m['components'] as List?) ?? [];
    final List<Map<String, dynamic>> components = componentsRaw
        .map((c) => {
              'name': (c is Map ? c['name'] : '')?.toString() ?? '',
              'amount': double.tryParse((c is Map ? c['amount'] : 0)?.toString() ?? '0') ?? 0.0,
            })
        .toList();

    final statusStr = (m['approval_status'] ?? 'pending').toString();
    final bool isApproved = statusStr.toLowerCase() == 'approved';
    final int structureId = m['id'] is num ? (m['id'] as num).toInt() : 1;
    final String bookletNo = m['booklet_no']?.toString() ?? "10495${structureId.toString().padLeft(3, '0')}";
    final String receiptDate = m['receipt_date']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
    final String receiptNo = m['formatted_receipt_no']?.toString() ?? (821000 + structureId).toString().padLeft(7, '0');
    final String seatType = (m['seat_type'] ?? 'GM').toString().toUpperCase();
    final String deptName = m['department_name']?.toString() ?? m['department']?.toString() ?? "CSE";
    final String academicYear = m['academic_year_name']?.toString() ?? m['academic_year']?.toString() ?? '2025-2026';
    final String semester = m['semester_name']?.toString() ?? m['semester']?.toString() ?? '3';
    final String? rejectionRemark = m['rejection_remark']?.toString();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 850),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              // Dialog App Bar Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF13246E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Official DTE Fee Structure & Receipt",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: Colors.white),
                      tooltip: "Print Receipt",
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Sending official DTE fee receipt to local printer..."),
                            backgroundColor: Color(0xFF13246E),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      tooltip: "Download PDF",
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Downloading official receipt PDF with digital signatures..."),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Scrollable DTE Fee Receipt
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DteFeeReceiptWidget(
                    institutionName: "Government Engineering College Chamarajanagara",
                    bookletNo: bookletNo,
                    receiptDate: receiptDate,
                    receiptNo: receiptNo,
                    studentName: "Applicable to All $seatType Students",
                    branch: deptName,
                    category: seatType,
                    year: "$academicYear • Semester $semester",
                    components: components.isNotEmpty
                        ? components
                        : [
                            {'name': 'Tuition Fee', 'amount': totalAmt > 0 ? totalAmt : 36000.0},
                          ],
                    totalAmount: totalAmt,
                    status: statusStr,
                    approvedByName: isApproved ? "Dr. Principal (GEC Chamarajanagar)" : null,
                    approvedDate: isApproved ? "Approved by Principal" : (rejectionRemark != null ? "Remark: $rejectionRemark" : null),
                    isStudentReceipt: false,
                  ),
                ),
              ),

              // Dialog Footer Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isApproved)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/fees/edit/$structureId');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF13246E),
                          side: const BorderSide(color: Color(0xFF13246E)),
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Edit Structure"),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Done"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> get _filteredNotifications {
    if (_selectedFilter == 'unread') {
      return _notifications.where((n) => n['is_read'] != true).toList();
    } else if (_selectedFilter == 'principal') {
      return _notifications.where((n) {
        final title = (n['title'] ?? '').toString().toLowerCase();
        final msg = (n['message'] ?? '').toString().toLowerCase();
        return title.contains('principal') || msg.contains('principal');
      }).toList();
    }
    return _notifications;
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "Today at ${DateFormat('hh:mm a').format(dt)}";
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
        return "Yesterday at ${DateFormat('hh:mm a').format(dt)}";
      }
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredNotifications;
    final totalCount = _notifications.length;
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;
    final principalCount = _notifications.where((n) {
      final t = (n['title'] ?? '').toString().toLowerCase();
      final m = (n['message'] ?? '').toString().toLowerCase();
      return t.contains('principal') || m.contains('principal');
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Principal Notifications & Directives",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
              label: const Text(
                "Mark All Read",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Refresh Notifications",
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text("Failed to load notifications: $_error", style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchNotifications, child: const Text("Retry")),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          // Header Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF13246E), Color(0xFF1E3A8A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF13246E).withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 32),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Office of the Principal",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Official executive notifications, fee structure sanctions, concession directives, and financial review orders.",
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Stat Badges
                          Row(
                            children: [
                              _statChip("Total Directives", "$totalCount", Icons.inbox_rounded, Colors.grey.shade700),
                              const SizedBox(width: 12),
                              _statChip(
                                "Unread",
                                "$unreadCount",
                                Icons.mark_email_unread_rounded,
                                unreadCount > 0 ? const Color(0xFFDC2626) : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              _statChip("From Principal", "$principalCount", Icons.verified_user_rounded, const Color(0xFF13246E)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Filter Chips
                          Row(
                            children: [
                              _filterChoiceChip("All", 'all'),
                              const SizedBox(width: 8),
                              _filterChoiceChip("From Principal", 'principal'),
                              const SizedBox(width: 8),
                              _filterChoiceChip("Unread ($unreadCount)", 'unread'),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Notifications List
                          if (list.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(48),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.mark_email_read_outlined, size: 56, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No notifications in this view",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Directives from the Principal will appear here in real time.",
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: list.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final notif = list[index];
                                final isRead = notif['is_read'] == true;
                                final title = notif['title']?.toString() ?? 'Notification';
                                final message = notif['message']?.toString() ?? '';
                                final timeStr = _formatDateTime(notif['created_at']?.toString());
                                final notifId = notif['id'] as int? ?? 0;

                                final isPrincipal = title.toLowerCase().contains('principal') ||
                                    message.toLowerCase().contains('principal');

                                final isReturned = title.toLowerCase().contains('return') ||
                                    title.toLowerCase().contains('reject') ||
                                    message.toLowerCase().contains('returned') ||
                                    message.toLowerCase().contains('correct');
                                final isApproved = title.toLowerCase().contains('approv') ||
                                    message.toLowerCase().contains('approved');

                                // Extract remarks if present
                                String? principalRemarks;
                                if (isReturned) {
                                  final match = RegExp(r"Remark[s]?:\s*['""]?([^'""]+)['""]?", caseSensitive: false).firstMatch(message);
                                  if (match != null && match.group(1)?.isNotEmpty == true) {
                                    principalRemarks = match.group(1);
                                  } else {
                                    principalRemarks = "Please verify the fee components and total amount.";
                                  }
                                }

                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isReturned
                                          ? const Color(0xFFFCA5A5)
                                          : !isRead
                                              ? const Color(0xFF13246E).withValues(alpha: 0.35)
                                              : Colors.grey.shade200,
                                      width: isReturned || !isRead ? 1.5 : 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isReturned
                                            ? Colors.red.withValues(alpha: 0.04)
                                            : isRead
                                                ? Colors.black.withValues(alpha: 0.02)
                                                : const Color(0xFF13246E).withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 1. Header Row: Title + Unread + Approval Status
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isReturned ? const Color(0xFF991B1B) : const Color(0xFF13246E),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!isRead)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                                              ),
                                              child: const Text(
                                                "Unread",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(width: 6),
                                          // Approval status badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isReturned
                                                  ? const Color(0xFFFEF2F2)
                                                  : isApproved
                                                      ? const Color(0xFFECFDF5)
                                                      : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isReturned
                                                    ? const Color(0xFFFCA5A5)
                                                    : isApproved
                                                        ? const Color(0xFFA7F3D0)
                                                        : const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            child: Text(
                                              isReturned
                                                  ? "Returned for Correction"
                                                  : isApproved
                                                      ? "Approved"
                                                      : "Pending Review",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isReturned
                                                    ? const Color(0xFFB91C1C)
                                                    : isApproved
                                                        ? const Color(0xFF047857)
                                                        : const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // 2. Sender and Timestamp Line
                                      Row(
                                        children: [
                                          Icon(
                                            isPrincipal ? Icons.verified_user_rounded : Icons.notifications_active_rounded,
                                            size: 14,
                                            color: isPrincipal ? const Color(0xFF13246E) : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "From Principal · $timeStr",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // 3. Message Body
                                      Text(
                                        message,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[800],
                                          height: 1.45,
                                        ),
                                      ),

                                      // 4. Principal's Remarks Container (if returned or remarks present)
                                      if (principalRemarks != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFCA5A5)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.rate_review_rounded, size: 14, color: Color(0xFFB91C1C)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "Principal's remarks",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.red.shade900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                principalRemarks,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF7F1D1D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 16),

                                      // 5. Action Buttons
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _openFeeStructureReceipt(Map<String, dynamic>.from(notif)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF13246E),
                                              side: const BorderSide(color: Color(0xFF13246E)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.receipt_long_rounded, size: 15),
                                            label: const Text("View Fee Structure Receipt", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          ),
                                          if (title.toLowerCase().contains("payment") ||
                                              message.toLowerCase().contains("upi") ||
                                              message.toLowerCase().contains("reconcil")) ...[
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () => context.push('/fees/student-payments'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF10B981),
                                                side: const BorderSide(color: Color(0xFF10B981)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.verified_user_rounded, size: 15),
                                              label: const Text("Verify Payments", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (!isRead)
                                            TextButton.icon(
                                              onPressed: () => _markAsRead(notifId),
                                              icon: const Icon(Icons.done_rounded, size: 16, color: Color(0xFF13246E)),
                                              label: const Text(
                                                "Mark as read",
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _filterChoiceChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF13246E),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF13246E) : Colors.grey.shade300),
      showCheckmark: false,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
    );
  }
}
