import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import '../widgets/dte_fee_receipt_widget.dart';

class AccountsDashboardScreen extends StatefulWidget {
  const AccountsDashboardScreen({super.key});

  @override
  State<AccountsDashboardScreen> createState() => _AccountsDashboardScreenState();
}

class _AccountsDashboardScreenState extends State<AccountsDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/fees/dashboard-stats/');
      if (mounted) {
        setState(() {
          _stats = response.data;
          _isLoading = false;
        });
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

  void _showReceiptDialog(Map<String, dynamic> txn) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
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
                        "Official DTE Receipt",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: Colors.white),
                      tooltip: "Print Receipt",
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Sending official DTE receipt to printer / PDF export..."),
                            backgroundColor: Color(0xFF13246E),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DteFeeReceiptWidget(
                    institutionName: "Government Engineering College Chamarajanagara",
                    bookletNo: "10495${txn['id'].toString().padLeft(3, '0')}",
                    receiptDate: txn['paid_on']?.toString().substring(0, 10) ?? "01/01/2026",
                    receiptNo: txn['receipt_no'] ?? (821000 + (txn['id'] as int? ?? 1)).toString().padLeft(7, '0'),
                    studentName: txn['student_name'] ?? "Student",
                    branch: txn['department'] ?? "CSE",
                    category: "General",
                    components: (txn['components'] is List && (txn['components'] as List).isNotEmpty)
                        ? (txn['components'] as List)
                            .map((c) => {
                                  'name': (c is Map ? c['name'] : '')?.toString() ?? '',
                                  'amount': double.tryParse((c is Map ? c['amount'] : 0)?.toString() ?? '0') ?? 0.0,
                                })
                            .toList()
                        : [
                            {'name': 'Tuition Fee', 'amount': (txn['amount'] as num?)?.toDouble() ?? 0.0},
                          ],
                    totalAmount: (txn['amount'] as num?)?.toDouble() ?? 0.0,
                    status: 'paid',
                    isStudentReceipt: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text("Failed to load dashboard: $_error"),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchDashboard, child: const Text("Retry")),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDashboard,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width < 480 ? 14 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Banner with date
                        _buildHeroBanner(),
                        const SizedBox(height: 24),

                        // Metric Stat Cards Grid
                        _buildStatCardsGrid(),
                        const SizedBox(height: 24),

                        // Quick Navigation / Action Panel
                        _buildQuickActionsPanel(),
                        const SizedBox(height: 28),

                        // Distribution Cards (Seat Types & Departments)
                        _buildBreakdownSection(),
                        const SizedBox(height: 28),

                        // Recent Transactions Table
                        _buildRecentTransactionsCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeroBanner() {
    final pendingCount = _stats?['pending_payments_count'] ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "College Accounts & Fee Directorate",
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              "Financial Overview & Collections",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Track real-time fee receipts, verify payments, manage student concessions, and export audit statements.",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              tooltip: "Refresh Overview",
              onPressed: _fetchDashboard,
            ),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/fees/student-payments'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notification_important_rounded, color: Colors.black87),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$pendingCount Pending",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const Text("Verify Now", style: TextStyle(fontSize: 11, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF13246E), Color(0xFF2A3B8F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF13246E).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: content),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatCardsGrid() {
    final collected = ((_stats?['total_collected'] ?? _stats?['net_collected']) as num?)?.toDouble() ?? 0.0;
    final today = ((_stats?['today_collections'] ?? _stats?['today_net']) as num?)?.toDouble() ?? 0.0;
    final outstanding = (_stats?['total_outstanding'] as num?)?.toDouble() ?? 0.0;
    final concessions = (_stats?['total_concessions'] as num?)?.toDouble() ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final isMedium = constraints.maxWidth > 600;
        final crossAxisCount = isWide ? 4 : (isMedium ? 2 : 1);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 1.6 : (isMedium ? 1.8 : 2.4),
          children: [
            _statMetricCard(
              title: "Total Collections",
              value: "₹${collected.toStringAsFixed(2)}",
              subtitle: "All verified collections",
              icon: Icons.payments_rounded,
              color: const Color(0xFF10B981),
            ),
            _statMetricCard(
              title: "Today's Collections",
              value: "₹${today.toStringAsFixed(2)}",
              subtitle: "Received today",
              icon: Icons.today_rounded,
              color: const Color(0xFF3B82F6),
            ),
            _statMetricCard(
              title: "Total Outstanding",
              value: "₹${outstanding.toStringAsFixed(2)}",
              subtitle: "Pending student dues",
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFFEF4444),
            ),
            _statMetricCard(
              title: "Approved Concessions",
              value: "₹${concessions.toStringAsFixed(2)}",
              subtitle: "Scholarships & fee waivers",
              icon: Icons.card_giftcard_rounded,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        );
      },
    );
  }

  Widget _statMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Operations",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _actionButton(
                label: "Record Payment",
                icon: Icons.add_card_rounded,
                color: const Color(0xFF13246E),
                onTap: () => context.push('/fees/record-payment'),
              ),
              _actionButton(
                label: "Student Fee Directory",
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF2563EB),
                onTap: () => context.push('/fees/students'),
              ),
              _actionButton(
                label: "Verify Payments",
                icon: Icons.verified_user_rounded,
                color: const Color(0xFF10B981),
                onTap: () => context.push('/fees/student-payments'),
              ),
              _actionButton(
                label: "Fee Structures",
                icon: Icons.account_tree_rounded,
                color: const Color(0xFF6366F1),
                onTap: () => context.push('/fees'),
              ),
              _actionButton(
                label: "Financial Reports",
                icon: Icons.analytics_rounded,
                color: const Color(0xFFD97706),
                onTap: () => context.push('/fees/reports'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.08),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      icon: Icon(icon, size: 20, color: color),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildBreakdownSection() {
    final seatTypes = (_stats?['collection_by_seat_type'] as List?) ?? [];
    final modes = (_stats?['collection_by_mode'] as List?) ?? [];
    final depts = (_stats?['collection_by_department'] as List?) ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _listCard("Collections by Seat Category", seatTypes, 'label', 'amount', Icons.category_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _listCard("Collections by Payment Mode", modes, 'label', 'amount', Icons.payment_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _listCard("Collections by Department", depts, 'name', 'amount', Icons.school_rounded)),
                ],
              )
            : Column(
                children: [
                  _listCard("Collections by Seat Category", seatTypes, 'label', 'amount', Icons.category_rounded),
                  const SizedBox(height: 16),
                  _listCard("Collections by Payment Mode", modes, 'label', 'amount', Icons.payment_rounded),
                  const SizedBox(height: 16),
                  _listCard("Collections by Department", depts, 'name', 'amount', Icons.school_rounded),
                ],
              );
      },
    );
  }

  Widget _listCard(String title, List items, String labelKey, String valueKey, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF13246E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E)),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("No records recorded yet", style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...items.map((item) {
              final label = item[labelKey]?.toString() ?? 'Other';
              final amt = (item[valueKey] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    Text(
                      "₹${amt.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    final txns = (_stats?['recent_transactions'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: Color(0xFF13246E), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Recent Fee Transactions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/fees/reports?tab=0'),
                child: const Text("View All Reports"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (txns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text("No transactions recorded yet.")),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text("Txn ID", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Student", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("USN", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Amount", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Mode", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: txns.map((t) {
                  final verified = t['verified'] == true;
                  final isReversed = t['is_reversed'] == true;
                  Color statusColor = Colors.orange;
                  String statusText = "PENDING";
                  if (isReversed) {
                    statusColor = Colors.purple;
                    statusText = "REVERSED";
                  } else if (verified) {
                    statusColor = Colors.green;
                    statusText = "VERIFIED";
                  }

                  return DataRow(
                    cells: [
                      DataCell(Text("#${t['id']}")),
                      DataCell(Text("${t['student_name']}", style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text("${t['student_usn']}")),
                      DataCell(Text("₹${t['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E)))),
                      DataCell(Text("${t['mode_display'] ?? t['mode']}")),
                      DataCell(Text("${t['paid_on'] ?? 'N/A'}")),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            if (verified)
                              IconButton(
                                icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF13246E), size: 20),
                                tooltip: "View Official DTE Receipt",
                                onPressed: () => _showReceiptDialog(t),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
