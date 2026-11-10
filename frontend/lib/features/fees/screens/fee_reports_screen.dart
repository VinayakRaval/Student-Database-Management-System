import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class FeeReportsScreen extends StatefulWidget {
  final int initialTab;
  const FeeReportsScreen({super.key, this.initialTab = 0});

  @override
  State<FeeReportsScreen> createState() => _FeeReportsScreenState();
}

class _FeeReportsScreenState extends State<FeeReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _collectionsData;
  Map<String, dynamic>? _defaultersData;
  Map<String, dynamic>? _departmentsData;
  Map<String, dynamic>? _concessionsData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
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
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final results = await Future.wait([
        dio.get('/fees/reports/', queryParameters: {'report_type': 'collections'}),
        dio.get('/fees/reports/', queryParameters: {'report_type': 'defaulters'}),
        dio.get('/fees/reports/', queryParameters: {'report_type': 'departments'}),
        dio.get('/fees/reports/', queryParameters: {'report_type': 'concessions'}),
      ]);

      if (mounted) {
        setState(() {
          _collectionsData = results[0].data as Map<String, dynamic>?;
          _defaultersData = results[1].data as Map<String, dynamic>?;
          _departmentsData = results[2].data as Map<String, dynamic>?;
          _concessionsData = results[3].data as Map<String, dynamic>?;
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

  Future<void> _exportCsv(String reportType) async {
    final dio = ApiClient().dio;
    final baseUrl = dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final urlStr = '$baseUrl/fees/reports/?report_type=$reportType&export=csv';
    final uri = Uri.parse(urlStr);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Downloading $reportType report CSV..."),
              backgroundColor: const Color(0xFF0F2577),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("CSV Export URL: $urlStr"),
            backgroundColor: const Color(0xFF0F2577),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error loading reports: $_error"))
              : Column(
                  children: [
                    // Segment Tab Bar Row matching Image 3
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _buildSegmentTabBar(),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCollectionsTab(),
                          _buildDefaultersTab(),
                          _buildDepartmentsTab(),
                          _buildConcessionsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // --- 4-Segment Tab Bar matching Image 3 ---
  Widget _buildSegmentTabBar() {
    final tabs = [
      {'title': 'Collections', 'icon': Icons.analytics_rounded},
      {'title': 'Outstanding Dues', 'icon': Icons.access_time_rounded},
      {'title': 'Department Summary', 'icon': Icons.account_balance_rounded},
      {'title': 'Concessions & Scholarships', 'icon': Icons.card_giftcard_rounded},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _tabController.index == index;
          final tab = tabs[index];

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _tabController.animateTo(index);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F2577) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tab['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- TAB 1: Collections ---
  Widget _buildCollectionsTab() {
    final list = (_collectionsData?['data'] as List?) ?? [];
    final total = (_collectionsData?['total_collected'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(
            title: "Periodic Fee Collections",
            subtitle: "Verified daily collection logs from active payments",
            totalLabel: "Total Verified Collections",
            totalValue: "₹${total.toStringAsFixed(2)}",
            icon: Icons.savings_outlined,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFEBF5FE),
            onExportCsv: () => _exportCsv('collections'),
          ),
          const SizedBox(height: 16),
          _tableContainer(
            DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dividerThickness: 1,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(
                  label: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF1E293B)),
                      SizedBox(width: 8),
                      Text("Date", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13)),
                    ],
                  ),
                ),
                DataColumn(
                  label: Row(
                    children: [
                      Icon(Icons.sync_alt_rounded, size: 16, color: Color(0xFF1E293B)),
                      SizedBox(width: 8),
                      Text("Transactions", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13)),
                    ],
                  ),
                ),
                DataColumn(
                  label: Row(
                    children: [
                      Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF1E293B)),
                      SizedBox(width: 8),
                      Text("Total Collected", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13)),
                    ],
                  ),
                ),
              ],
              rows: list.map((d) {
                final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
                return DataRow(
                  cells: [
                    DataCell(Text("${d['date']}", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 13.5))),
                    DataCell(Text("${d['transactions_count']}", style: const TextStyle(color: Color(0xFF334155), fontSize: 13.5))),
                    DataCell(Text("₹${amt.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Outstanding Defaulters ---
  Widget _buildDefaultersTab() {
    final list = (_defaultersData?['data'] as List?) ?? [];
    final total = (_defaultersData?['total_outstanding'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(
            title: "Outstanding Fee Defaulters Report",
            subtitle: "Active students with pending or partial balance payments",
            totalLabel: "Total Outstanding Dues",
            totalValue: "₹${total.toStringAsFixed(2)}",
            valueColor: const Color(0xFFDC2626),
            icon: Icons.pending_actions_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBgColor: const Color(0xFFFEF2F2),
            onExportCsv: () => _exportCsv('defaulters'),
          ),
          const SizedBox(height: 16),
          _tableContainer(
            DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dividerThickness: 1,
              columns: const [
                DataColumn(label: Text("USN", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Sem", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Total Fee", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Concession", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Paid", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Outstanding Balance", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: list.map((d) {
                final bal = (d['balance_amount'] as num?)?.toDouble() ?? 0.0;
                final tot = (d['total_fee'] as num?)?.toDouble() ?? 0.0;
                final conc = (d['concession'] as num?)?.toDouble() ?? 0.0;
                final paid = (d['paid_amount'] as num?)?.toDouble() ?? 0.0;

                return DataRow(
                  cells: [
                    DataCell(Text("${d['usn']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text("${d['student_name']}")),
                    DataCell(Text("${d['department']}")),
                    DataCell(Text("${d['semester']}")),
                    DataCell(Text("₹${tot.toStringAsFixed(0)}")),
                    DataCell(Text("₹${conc.toStringAsFixed(0)}", style: const TextStyle(color: Colors.purple))),
                    DataCell(Text("₹${paid.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green))),
                    DataCell(Text("₹${bal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (d['status'] == 'PARTIAL' ? Colors.orange : Colors.red).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${d['status']}",
                          style: TextStyle(
                            color: d['status'] == 'PARTIAL' ? Colors.orange : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
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

  // --- TAB 3: Department Summary ---
  Widget _buildDepartmentsTab() {
    final list = (_departmentsData?['data'] as List?) ?? [];
    final collected = (_departmentsData?['total_collected'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (_departmentsData?['total_outstanding'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(
            title: "Department-wise Collection & Dues",
            subtitle: "Breakdown of fee allocations, receipts, and balances per branch",
            totalLabel: "Collected: ₹${collected.toStringAsFixed(0)} | Dues: ₹${outstanding.toStringAsFixed(0)}",
            totalValue: "₹${(collected + outstanding).toStringAsFixed(2)} Total Assigned",
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBgColor: const Color(0xFFF5F3FF),
            onExportCsv: () => _exportCsv('departments'),
          ),
          const SizedBox(height: 16),
          _tableContainer(
            DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dividerThickness: 1,
              columns: const [
                DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Students", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Assigned Fee", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Total Collected", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Outstanding Due", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Recovery %", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: list.map((d) {
                final assigned = (d['assigned_amount'] as num?)?.toDouble() ?? 0.0;
                final col = (d['collected_amount'] as num?)?.toDouble() ?? 0.0;
                final out = (d['outstanding_amount'] as num?)?.toDouble() ?? 0.0;
                final pct = assigned > 0 ? (col / assigned * 100) : 0.0;

                return DataRow(
                  cells: [
                    DataCell(Text("${d['department_name']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text("${d['students_count']}")),
                    DataCell(Text("₹${assigned.toStringAsFixed(0)}")),
                    DataCell(Text("₹${col.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
                    DataCell(Text("₹${out.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
                    DataCell(Text("${pct.toStringAsFixed(1)}%", style: TextStyle(fontWeight: FontWeight.bold, color: pct >= 80 ? Colors.green : Colors.orange))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: Concessions & Scholarships ---
  Widget _buildConcessionsTab() {
    final list = (_concessionsData?['data'] as List?) ?? [];
    final total = (_concessionsData?['total_concessions'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(
            title: "Approved Concessions & Scholarships",
            subtitle: "Audit log of all student fee waivers and institutional concessions",
            totalLabel: "Total Concessions Granted",
            totalValue: "₹${total.toStringAsFixed(2)}",
            valueColor: const Color(0xFF7C3AED),
            icon: Icons.card_giftcard_rounded,
            iconColor: const Color(0xFFD97706),
            iconBgColor: const Color(0xFFFFFBEB),
            onExportCsv: () => _exportCsv('concessions'),
          ),
          const SizedBox(height: 16),
          _tableContainer(
            DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dividerThickness: 1,
              columns: const [
                DataColumn(label: Text("USN", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Concession Amount", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Scholarship / Reason", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Approved By", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: list.map((d) {
                final amt = (d['concession_amount'] as num?)?.toDouble() ?? 0.0;
                return DataRow(
                  cells: [
                    DataCell(Text("${d['usn']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text("${d['student_name']}")),
                    DataCell(Text("${d['department']}")),
                    DataCell(Text("₹${amt.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
                    DataCell(Text("${d['reason']}")),
                    DataCell(Text("${d['approved_by']}")),
                    DataCell(Text("${d['approved_on']}")),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard({
    required String title,
    required String subtitle,
    required String totalLabel,
    required String totalValue,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    Color? valueColor,
    required VoidCallback onExportCsv,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Icon Badge matching Image 3
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 18),

          // Titles & Totals
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalLabel,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalValue,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: valueColor ?? const Color(0xFF0F2577),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Right Export CSV button matching Image 3
          ElevatedButton.icon(
            onPressed: onExportCsv,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2577),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.file_download_rounded, size: 18),
            label: const Text(
              "Export CSV",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableContainer(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      ),
    );
  }
}
