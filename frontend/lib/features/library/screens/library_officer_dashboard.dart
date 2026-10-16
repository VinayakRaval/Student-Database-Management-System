import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';

class LibraryOfficerDashboard extends StatefulWidget {
  final int initialTabIndex; // Kept for backwards-compatibility
  const LibraryOfficerDashboard({super.key, this.initialTabIndex = 0});

  @override
  State<LibraryOfficerDashboard> createState() => _LibraryOfficerDashboardState();
}

class _LibraryOfficerDashboardState extends State<LibraryOfficerDashboard> {
  // Stats & Data
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentIssues = [];
  List<Map<String, dynamic>> _pendingRequests = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;

      final results = await Future.wait([
        dio.get('/library/books/stats/').catchError((_) => dio.get('/library/books/')),
        dio.get('/library/issues/'),
        dio.get('/library/requests/'),
        dio.get('/library/fines/'),
      ]);

      Map<String, dynamic> statsMap = {};
      if (results[0].data is Map) {
        statsMap = Map<String, dynamic>.from(results[0].data as Map);
      }

      final List issuesList = results[1].data is List ? results[1].data : [];
      final List requestsList = results[2].data is List ? results[2].data : [];

      if (mounted) {
        setState(() {
          _stats = statsMap;
          _recentIssues = List<Map<String, dynamic>>.from(issuesList);
          _pendingRequests = List<Map<String, dynamic>>.from(requestsList)
              .where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load library overview: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTitles = _stats['total_books'] ?? 0;
    final totalCopies = _stats['total_copies'] ?? 0;
    final issuedCopies = _stats['issued_copies'] ?? 0;
    final overdueCount = _stats['overdue_copies'] ?? 0;
    final unpaidFines = _stats['unpaid_fines'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.local_library_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Library Officer Overview",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Dashboard",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchDashboardData,
          ),
          const SizedBox(width: 10),
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
                          onPressed: _fetchDashboardData,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Circulation & Catalogue Command Center",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Manage book issues, library inventory, acquisitions, and student dues.",
                                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF13246E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/library/books/add'),
                                icon: const Icon(Icons.add_box_rounded, size: 18),
                                label: const Text("Add New Book", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/library/issue-book'),
                                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                                label: const Text("Issue Book", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // KPI Metrics Row
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isNarrow = constraints.maxWidth < 900;
                          return isNarrow
                              ? Column(
                                  children: [
                                    Row(
                                      children: [
                                        _buildKpiCard("TOTAL TITLES", "$totalTitles", Icons.library_books_rounded, const Color(0xFF13246E)),
                                        const SizedBox(width: 12),
                                        _buildKpiCard("TOTAL COPIES", "$totalCopies", Icons.layers_rounded, const Color(0xFF13246E)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildKpiCard("ACTIVE LOANS", "$issuedCopies", Icons.swap_horiz_rounded, const Color(0xFF13246E)),
                                        const SizedBox(width: 12),
                                        _buildKpiCard("OVERDUE", "$overdueCount", Icons.alarm_rounded, overdueCount > 0 ? Colors.red.shade700 : const Color(0xFF059669)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildKpiCard("UNPAID FINES", "₹$unpaidFines", Icons.money_off_rounded, const Color(0xFFD97706)),
                                        const SizedBox(width: 12),
                                        _buildKpiCard("PENDING REQ.", "${_pendingRequests.length}", Icons.pending_actions_rounded, const Color(0xFF13246E)),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    _buildKpiCard("TOTAL TITLES", "$totalTitles Titles", Icons.library_books_rounded, const Color(0xFF13246E)),
                                    const SizedBox(width: 12),
                                    _buildKpiCard("TOTAL COPIES", "$totalCopies Copies", Icons.layers_rounded, const Color(0xFF13246E)),
                                    const SizedBox(width: 12),
                                    _buildKpiCard("ACTIVE LOANS", "$issuedCopies Issued", Icons.swap_horiz_rounded, const Color(0xFF13246E)),
                                    const SizedBox(width: 12),
                                    _buildKpiCard("OVERDUE", "$overdueCount Overdue", Icons.alarm_rounded, overdueCount > 0 ? Colors.red.shade700 : const Color(0xFF059669)),
                                    const SizedBox(width: 12),
                                    _buildKpiCard("UNPAID FINES", "₹$unpaidFines", Icons.money_off_rounded, const Color(0xFFD97706)),
                                    const SizedBox(width: 12),
                                    _buildKpiCard("PENDING REQ.", "${_pendingRequests.length} Pending", Icons.pending_actions_rounded, const Color(0xFF13246E)),
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Quick Action Navigation Cards
                      const Text(
                        "Library Modules & Dedicated Workspaces",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final crossCount = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
                          return GridView.count(
                            crossAxisCount: crossCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.6,
                            children: [
                              _buildModuleCard(
                                title: "Book Catalogue",
                                subtitle: "Browse, filter, add titles & stock copies",
                                icon: Icons.menu_book_rounded,
                                color: const Color(0xFF13246E),
                                badgeText: "$totalTitles titles",
                                onTap: () => context.go('/library/catalog'),
                              ),
                              _buildModuleCard(
                                title: "Issue & Return Desk",
                                subtitle: "Circulation desk, return books & mark lost",
                                icon: Icons.swap_horiz_rounded,
                                color: const Color(0xFF13246E),
                                badgeText: "$issuedCopies active",
                                onTap: () => context.go('/library/desk'),
                              ),
                              _buildModuleCard(
                                title: "Book Requests",
                                subtitle: "Review, verify & procure book proposals",
                                icon: Icons.pending_actions_rounded,
                                color: const Color(0xFF13246E),
                                badgeText: "${_pendingRequests.length} pending",
                                onTap: () => context.go('/library/requests'),
                              ),
                              _buildModuleCard(
                                title: "Library Cards",
                                subtitle: "Generate cards, digital signatures & issue",
                                icon: Icons.badge_rounded,
                                color: const Color(0xFF13246E),
                                badgeText: "Issue Cards",
                                onTap: () => context.go('/library/cards'),
                              ),
                              _buildModuleCard(
                                title: "Fines & Dues",
                                subtitle: "Track overdue penalties & record receipts",
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFF13246E),
                                badgeText: "₹$unpaidFines dues",
                                onTap: () => context.go('/library/fines'),
                              ),
                              _buildModuleCard(
                                title: "Notifications",
                                subtitle: "Directives & circulars from Principal",
                                icon: Icons.notifications_active_rounded,
                                color: const Color(0xFF13246E),
                                badgeText: "Principal",
                                onTap: () => context.go('/library/notifications'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Recent Circulation Activity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Recent Circulation Activity",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          TextButton(
                            onPressed: () => context.go('/library/desk'),
                            child: const Text("View All Desk Records →"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: _recentIssues.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Text("No circulation records recorded yet."),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recentIssues.take(6).length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                itemBuilder: (ctx, i) {
                                  final item = _recentIssues[i];
                                  final isOverdue = item['is_overdue'] == true;
                                  final status = (item['status'] ?? '').toString().toUpperCase();

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isOverdue
                                          ? Colors.red.shade100
                                          : (status == 'ISSUED' ? const Color(0xFF13246E).withOpacity(0.1) : Colors.green.shade100),
                                      child: Icon(
                                        isOverdue ? Icons.alarm_rounded : (status == 'ISSUED' ? Icons.menu_book_rounded : Icons.check_circle_rounded),
                                        color: isOverdue ? Colors.red.shade700 : (status == 'ISSUED' ? const Color(0xFF13246E) : const Color(0xFF059669)),
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      item['book_title'] ?? 'Book',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      "Borrower: ${item['borrower_name'] ?? 'N/A'} (USN: ${item['borrower_usn'] ?? 'N/A'}) • Due: ${item['due_date'] ?? 'N/A'}",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isOverdue ? Colors.red.shade100 : (status == 'ISSUED' ? Colors.blue.shade50 : Colors.green.shade50),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isOverdue ? "OVERDUE" : status,
                                        style: TextStyle(
                                          color: isOverdue ? Colors.red.shade900 : (status == 'ISSUED' ? Colors.blue.shade900 : const Color(0xFF059669)),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.14),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
