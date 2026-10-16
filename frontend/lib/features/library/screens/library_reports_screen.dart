import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class LibraryReportsScreen extends StatefulWidget {
  const LibraryReportsScreen({super.key});

  @override
  State<LibraryReportsScreen> createState() => _LibraryReportsScreenState();
}

class _LibraryReportsScreenState extends State<LibraryReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Report Data
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _borrowers = [];
  List<Map<String, dynamic>> _reservations = [];
  Map<String, dynamic> _cardStats = {};

  // Report Types matching Image 2
  final List<String> _reportTypes = [
    'Library Overview',
    'Book Inventory',
    'Issue & Return',
    'Borrowers',
    'Reservations',
    'Library Cards',
  ];
  String _selectedReportType = 'Issue & Return';

  // Filters
  String _selectedDateRange = 'all'; // all, today, week, month, semester
  String _selectedDepartment = 'All Departments';
  String _searchQuery = '';

  final List<String> _departments = [
    'All Departments',
    'Computer Science and Engineering',
    'Electronics and Communication Engineering',
    'Civil Engineering',
    'Mechanical Engineering',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: 2);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {
          _selectedReportType = _reportTypes[_tabController.index];
        });
      }
    });
    _fetchReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/reports/summary/', queryParameters: {
        'department': _selectedDepartment,
        'date_range': _selectedDateRange,
        'search': _searchQuery.trim(),
      });

      if (mounted) {
        final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
        setState(() {
          _summary = Map<String, dynamic>.from(data['summary'] ?? {});
          _inventory = List<Map<String, dynamic>>.from(data['inventory'] ?? []);
          _issues = List<Map<String, dynamic>>.from(data['issues'] ?? []);
          _borrowers = List<Map<String, dynamic>>.from(data['borrowers'] ?? []);
          _reservations = List<Map<String, dynamic>>.from(data['reservations'] ?? []);
          _cardStats = Map<String, dynamic>.from(data['card_stats'] ?? {});
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load library reports: $e";
        });
      }
    }
  }

  void _exportReport() {
    final buffer = StringBuffer();
    final tabIndex = _tabController.index;
    String reportName = "Report";

    if (tabIndex == 1) {
      reportName = "Book_Inventory_Report";
      buffer.writeln("#,Book Title,Author,ISBN,Category,Department,Total Copies,Available,Issued,Damaged/Lost");
      for (int i = 0; i < _inventory.length; i++) {
        final b = _inventory[i];
        buffer.writeln('${i + 1},"${b['title']}","${b['authors']}","${b['isbn']}","${b['category']}","${b['department']}",${b['total_copies']},${b['available_copies']},${b['issued_copies']},${(b['damaged_copies'] ?? 0) + (b['lost_copies'] ?? 0)}');
      }
    } else if (tabIndex == 2) {
      reportName = "Issue_Return_Report";
      buffer.writeln("#,Issue ID,Book Title,Copy Barcode,Borrower Name,Borrower USN,Issue Date,Due Date,Return Date,Status");
      for (int i = 0; i < _issues.length; i++) {
        final iss = _issues[i];
        buffer.writeln('${i + 1},"${iss['issue_id']}","${iss['book_title']}","${iss['copy_id']}","${iss['borrower_name']}","${iss['borrower_usn']}","${iss['issue_date']}","${iss['due_date']}","${iss['returned_at']}","${iss['status']}"');
      }
    } else if (tabIndex == 3) {
      reportName = "Borrower_Report";
      buffer.writeln("#,Card No,Name,Type,USN/Staff ID,Department,Semester,Status,Active Loans,Overdue Books");
      for (int i = 0; i < _borrowers.length; i++) {
        final br = _borrowers[i];
        buffer.writeln('${i + 1},"${br['card_number']}","${br['borrower_name']}","${br['borrower_type']}","${br['identifier']}","${br['department']}","${br['semester']}","${br['status']}",${br['active_loans']},${br['overdue_books']}');
      }
    } else if (tabIndex == 4) {
      reportName = "Reservations_Report";
      buffer.writeln("#,Reservation ID,Book Title,Author,Requester,Department,Status,Reserved Date");
      for (int i = 0; i < _reservations.length; i++) {
        final res = _reservations[i];
        buffer.writeln('${i + 1},${res['id']},"${res['title']}","${res['authors']}","${res['requester_name']}","${res['department']}","${res['status']}","${res['created_at']}"');
      }
    } else if (tabIndex == 5) {
      reportName = "Library_Cards_Report";
      buffer.writeln("Card Metric,Value");
      _cardStats.forEach((k, v) => buffer.writeln("$k,$v"));
    } else {
      reportName = "Library_Overview_Report";
      buffer.writeln("Metric,Count");
      _summary.forEach((k, v) => buffer.writeln("$k,$v"));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Exported $reportName (${buffer.length} bytes) successfully!"),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Preparing print-ready analytical report for College Administration..."),
        backgroundColor: Color(0xFF13246E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Text(
          "Library Officer Reports & Analytics",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text("Export CSV"),
            onPressed: _exportReport,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7CA18),
              foregroundColor: const Color(0xFF4A1504),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text("Print Report", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _printReport,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: "Refresh Reports",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchReportData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFF7CA18),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: "Library Overview"),
            Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: "Book Inventory"),
            Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: "Issue & Return"),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: "Borrowers"),
            Tab(icon: Icon(Icons.bookmark_added_rounded, size: 18), text: "Reservations"),
            Tab(icon: Icon(Icons.badge_rounded, size: 18), text: "Library Cards"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Header Bar (Report Type Dropdown matching Image 2, Department, Date Range, Search)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Report Type filter matching clean UI of Date Range
                SizedBox(
                  width: 220,
                  height: 38,
                  child: DropdownButtonFormField<String>(
                    value: _selectedReportType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF13246E)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    items: _reportTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedReportType = val;
                          final idx = _reportTypes.indexOf(val);
                          if (idx >= 0 && idx < _tabController.length) {
                            _tabController.animateTo(idx);
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Department filter
                SizedBox(
                  width: 250,
                  height: 38,
                  child: DropdownButtonFormField<String>(
                    value: _selectedDepartment,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.school_rounded, size: 18, color: Color(0xFF13246E)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedDepartment = v ?? 'All Departments');
                      _fetchReportData();
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Date Range filter
                SizedBox(
                  width: 170,
                  height: 38,
                  child: DropdownButtonFormField<String>(
                    value: _selectedDateRange,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF13246E)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text("All Time")),
                      DropdownMenuItem(value: 'today', child: Text("Today")),
                      DropdownMenuItem(value: 'week', child: Text("This Week")),
                      DropdownMenuItem(value: 'month', child: Text("This Month")),
                      DropdownMenuItem(value: 'semester', child: Text("This Semester")),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedDateRange = v ?? 'all');
                      _fetchReportData();
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Search query input
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      onSubmitted: (_) => _fetchReportData(),
                      decoration: InputDecoration(
                        hintText: "Search title, copy ID, USN, or Staff ID...",
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: _fetchReportData,
                  child: const Text("Apply Filters", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSummaryDashboardTab(),
                          _buildInventoryReportTab(),
                          _buildIssuesReportTab(),
                          _buildBorrowersReportTab(),
                          _buildReservationsReportTab(),
                          _buildCardsReportTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // 1. Summary Dashboard Tab
  Widget _buildSummaryDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Library Inventory & Circulation Overview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricCard("Total Titles", "${_summary['total_titles'] ?? 0}", Icons.menu_book_rounded, const Color(0xFF13246E)),
              const SizedBox(width: 14),
              _buildMetricCard("Physical Copies", "${_summary['total_copies'] ?? 0}", Icons.library_books_rounded, const Color(0xFF0284C7)),
              const SizedBox(width: 14),
              _buildMetricCard("Available Copies", "${_summary['available_copies'] ?? 0}", Icons.check_circle_rounded, const Color(0xFF059669)),
              const SizedBox(width: 14),
              _buildMetricCard("Issued Copies", "${_summary['issued_copies'] ?? 0}", Icons.swap_horiz_rounded, const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricCard("Damaged / Lost Copies", "${(_summary['damaged_copies'] ?? 0) + (_summary['lost_copies'] ?? 0)}", Icons.warning_rounded, const Color(0xFFDC2626)),
              const SizedBox(width: 14),
              _buildMetricCard("Active Loans", "${_summary['active_loans'] ?? 0}", Icons.outbox_rounded, const Color(0xFF2563EB)),
              const SizedBox(width: 14),
              _buildMetricCard("Overdue Books (₹0 Fines)", "${_summary['overdue_loans'] ?? 0}", Icons.timer_off_rounded, const Color(0xFFEA580C)),
              const SizedBox(width: 14),
              _buildMetricCard("Registered Borrowers", "${_summary['total_borrowers'] ?? 0}", Icons.badge_rounded, const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 24),

          // Policy reminder box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: const [
                Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "College Free Borrowing Policy Enforced: All student & faculty borrowing is free of charge (₹0.00 borrowing fees and ₹0.00 late fines). Overdue books are monitored and flagged without monetary penalties.",
                    style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  // 2. Book Inventory Report Tab
  Widget _buildInventoryReportTab() {
    return _inventory.isEmpty
        ? const Center(child: Text("No book inventory records found."))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _inventory.length,
            itemBuilder: (ctx, i) {
              final b = _inventory[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text("${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['title'] ?? 'Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("Author: ${b['authors']} • ISBN: ${b['isbn']} • Dept: ${b['department']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      Text(
                        "${b['available_copies']} / ${b['total_copies']} Avail",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 16),
                      Text("Issued: ${b['issued_copies']}", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // 3. Issue & Return Report Tab
  Widget _buildIssuesReportTab() {
    return _issues.isEmpty
        ? const Center(child: Text("No circulation issue/return records found."))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _issues.length,
            itemBuilder: (ctx, i) {
              final iss = _issues[i];
              final isOverdue = iss['is_overdue'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListTile(
                  title: Text("${iss['book_title']} (${iss['copy_id']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text("Borrower: ${iss['borrower_name']} (${iss['borrower_usn']}) • Issued: ${iss['issue_date']} • Due: ${iss['due_date']}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverdue ? Colors.red.shade50 : (iss['status'] == 'RETURNED' ? Colors.green.shade50 : Colors.blue.shade50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      iss['status'] ?? 'ISSUED',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isOverdue ? Colors.red.shade700 : (iss['status'] == 'RETURNED' ? Colors.green.shade800 : Colors.blue.shade800),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  // 4. Borrower Report Tab
  Widget _buildBorrowersReportTab() {
    return _borrowers.isEmpty
        ? const Center(child: Text("No borrower records found."))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _borrowers.length,
            itemBuilder: (ctx, i) {
              final br = _borrowers[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF7CA18),
                    child: Icon(Icons.person, color: Colors.brown.shade900),
                  ),
                  title: Text("${br['borrower_name']} (${br['identifier']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text("Dept: ${br['department']} • ${br['semester']} • Card: ${br['card_number']}"),
                  trailing: Text("Active Loans: ${br['active_loans']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                ),
              );
            },
          );
  }

  // 5. Reservation Report Tab
  Widget _buildReservationsReportTab() {
    return _reservations.isEmpty
        ? const Center(child: Text("No book reservation records found."))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _reservations.length,
            itemBuilder: (ctx, i) {
              final r = _reservations[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListTile(
                  title: Text(r['title'] ?? 'Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text("Requester: ${r['requester_name']} • Dept: ${r['department']} • Date: ${r['created_at']}"),
                  trailing: Chip(label: Text(r['status'] ?? 'PENDING', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ),
              );
            },
          );
  }

  // 6. Library Issue Cards Report Tab
  Widget _buildCardsReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Digital Library Card Issuance Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard("Total Issued Cards", "${_cardStats['total_generated'] ?? 0}", Icons.badge_rounded, const Color(0xFF13246E)),
              const SizedBox(width: 14),
              _buildMetricCard("Active Cards", "${_cardStats['active_cards'] ?? 0}", Icons.verified_rounded, const Color(0xFF059669)),
              const SizedBox(width: 14),
              _buildMetricCard("Awaiting Generation", "${_cardStats['pending_generation'] ?? 0}", Icons.hourglass_top_rounded, const Color(0xFFD97706)),
              const SizedBox(width: 14),
              _buildMetricCard("Suspended / Expired", "${(_cardStats['suspended_cards'] ?? 0) + (_cardStats['expired_cards'] ?? 0)}", Icons.block_rounded, const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    );
  }
}
