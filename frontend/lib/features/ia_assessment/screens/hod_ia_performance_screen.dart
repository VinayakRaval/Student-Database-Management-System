import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class HODIAPerformanceScreen extends StatefulWidget {
  const HODIAPerformanceScreen({super.key});

  @override
  State<HODIAPerformanceScreen> createState() => _HODIAPerformanceScreenState();
}

class _HODIAPerformanceScreenState extends State<HODIAPerformanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _deptInfo = {};
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _subjectResults = [];
  List<Map<String, dynamic>> _needingSupport = [];
  List<Map<String, dynamic>> _suspiciousMarks = [];

  String _searchQuery = "";
  String? _selectedSemester;
  String? _selectedIAType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{};
      if (_selectedSemester != null && _selectedSemester!.isNotEmpty) {
        queryParams['semester_id'] = _selectedSemester;
      }
      if (_selectedIAType != null && _selectedIAType!.isNotEmpty) {
        queryParams['ia_type'] = _selectedIAType;
      }

      final res = await dio.get('/ia/hod/performance-summary/', queryParameters: queryParams);
      if (mounted) {
        setState(() {
          _overview = Map<String, dynamic>.from(res.data['overview'] ?? {});
          _deptInfo = Map<String, dynamic>.from(res.data['department_info'] ?? {});
          _submissions = List<Map<String, dynamic>>.from(res.data['submissions'] ?? []);
          _subjectResults = List<Map<String, dynamic>>.from(res.data['subject_results'] ?? []);
          _needingSupport = List<Map<String, dynamic>>.from(res.data['needing_support'] ?? []);
          _suspiciousMarks = List<Map<String, dynamic>>.from(res.data['suspicious_marks'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load academic performance data. Please retry.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showTestStudentsDialog(dynamic testId, String code, String iaName, dynamic maxMarks) async {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return FutureBuilder<Response>(
            future: ApiClient().dio.get('/ia/hod/test-students/', queryParameters: {'test_id': testId}),
            builder: (context, snapshot) {
              Widget content;
              if (snapshot.connectionState == ConnectionState.waiting) {
                content = const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                content = SizedBox(
                  height: 250,
                  child: Center(
                    child: Text("Failed to load student marks: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
                  ),
                );
              } else {
                final data = snapshot.data?.data;
                final List students = (data is Map && data['students'] is List) ? data['students'] : [];
                final evaluated = students.where((s) => s['obtained_marks'] != null).toList();
                final passed = evaluated.where((s) => (s['percentage'] as num? ?? 0) >= 40.0).toList();
                final passPct = evaluated.isNotEmpty ? (passed.length / evaluated.length * 100).toStringAsFixed(1) : "0.0";

                content = SizedBox(
                  width: 780,
                  height: 480,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniMetric("Total Eligible", "${students.length}"),
                            _miniMetric("Evaluated", "${evaluated.length}"),
                            _miniMetric("Pass Rate", "$passPct%"),
                            _miniMetric("Needing Support", "${evaluated.length - passed.length}", isAlert: (evaluated.length - passed.length) > 0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: students.isEmpty
                            ? const Center(child: Text("No students registered for this test."))
                            : SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFF13246E).withOpacity(0.06)),
                                    columns: const [
                                      DataColumn(label: Text("USN", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Semester", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Obtained", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Max Marks", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Percentage", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: students.map<DataRow>((st) {
                                      final obtained = st['obtained_marks'];
                                      final pct = (st['percentage'] as num?)?.toDouble();
                                      final isPassed = pct != null && pct >= 40.0;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(st['usn']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(Text(st['name']?.toString() ?? 'N/A')),
                                          DataCell(Text("Sem ${st['semester'] ?? 'N/A'}")),
                                          DataCell(Text(obtained != null ? "$obtained" : "—", style: const TextStyle(fontWeight: FontWeight.bold))),
                                          DataCell(Text("${st['max_marks'] ?? maxMarks}")),
                                          DataCell(Text(pct != null ? "$pct%" : "—", style: TextStyle(fontWeight: FontWeight.bold, color: isPassed ? Colors.green.shade800 : (pct != null ? Colors.red.shade800 : Colors.grey)))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (obtained == null ? Colors.grey : (isPassed ? Colors.green : Colors.red)).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                st['status']?.toString() ?? 'N/A',
                                                style: TextStyle(
                                                  color: obtained == null ? Colors.grey.shade700 : (isPassed ? Colors.green.shade800 : Colors.red.shade800),
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
                              ),
                      ),
                    ],
                  ),
                );
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$code: $iaName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF13246E))),
                          const SizedBox(height: 2),
                          const Text("Individual Student Marks Roster", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                content: content,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CLOSE"),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _miniMetric(String label, String value, {bool isAlert = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isAlert ? Colors.red.shade800 : const Color(0xFF13246E))),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  void _exportCSV() {
    final StringBuffer csv = StringBuffer();
    csv.writeln("Internal Assessment & Academic Performance Report - ${_deptInfo['name'] ?? 'Department'}");
    csv.writeln("Overall Pass Percentage,${_overview['overall_pass_pct'] ?? 0}%");
    csv.writeln("Total Tests Conducted,${_overview['total_tests'] ?? 0}");
    csv.writeln("Students Needing Support (<40%),${_overview['needing_support_count'] ?? 0}");
    csv.writeln();
    csv.writeln("Test Submissions");
    csv.writeln("Subject Code,Subject Name,Semester,IA Test,Faculty,Submitted,Eligible,Status");
    for (var s in _submissions) {
      csv.writeln('"${s['subject_code']}","${s['subject_name']}","Sem ${s['semester']}","${s['ia_name']}","${s['faculty_name']}",${s['submitted_count']},${s['eligible_count']},"${s['status_label'] ?? s['status']}"');
    }
    csv.writeln();
    csv.writeln("Subject-wise Performance");
    csv.writeln("Subject Code,Subject Name,Semester,Faculty,Average %,Pass %,Highest,Lowest");
    for (var r in _subjectResults) {
      csv.writeln('"${r['subject_code']}","${r['subject_name']}","Sem ${r['semester']}","${r['faculty_name']}",${r['average_percentage']}%,${r['pass_percentage']}%,${r['highest_score']},${r['lowest_score']}');
    }
    csv.writeln();
    csv.writeln("Students Needing Support (<40%)");
    csv.writeln("USN,Name,Semester,Subject,Test,Obtained,Max,Percentage");
    for (var s in _needingSupport) {
      csv.writeln('"${s['usn']}","${s['student_name']}","Sem ${s['semester']}","${s['subject_code']}","${s['ia_name']}",${s['obtained_marks']},${s['max_marks']},${s['percentage']}%');
    }

    Clipboard.setData(ClipboardData(text: csv.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Academic performance summary copied to clipboard in CSV format!"),
        backgroundColor: Color(0xFF13246E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    // Role detection
    final roleTag = (_deptInfo['user_role'] ?? '').toString().toUpperCase() == 'PRINCIPAL'
        ? 'CAMPUS ADMINISTRATION'
        : 'HEAD OF DEPARTMENT';
    final deptName = _deptInfo['name'] ?? 'Department of Computer Science';
    final userEmail = _deptInfo['user_email'] ?? 'hod@department.college.edu';

    // Filter submissions
    final filteredSubmissions = _submissions.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          (s['subject_code'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['subject_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['faculty_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['ia_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // 1. Top Navy Header Bar (Image 2 style)
          Container(
            color: const Color(0xFF13246E),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assessment_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      "IA & Academic Performance",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _loadData,
                  tooltip: "Refresh Data",
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // Main Scrollable Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Department Card (Image 2 style)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E2B68), Color(0xFF243B80)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF13246E).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.school_rounded, color: Color(0xFF1E2B68), size: 32),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    roleTag,
                                    style: const TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  deptName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Logged in as: $userEmail",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 3. Section Title (Image 2 style)
                    const Text(
                      "Department Statistics",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. 4 KPI Cards (Image 2 style)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 900;
                        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _buildImage2KPICard(
                                title: "Overall Pass Rate",
                                value: "${_overview['overall_pass_pct'] ?? 0}%",
                                icon: Icons.insights_rounded,
                                iconColor: const Color(0xFF13246E),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildImage2KPICard(
                                title: "Tests Conducted",
                                value: "${_overview['total_tests'] ?? 0}",
                                icon: Icons.quiz_rounded,
                                iconColor: const Color(0xFF0D9488),
                                iconBg: const Color(0xFFCCFBF1),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildImage2KPICard(
                                title: "Needs Support (<40%)",
                                value: "${_overview['needing_support_count'] ?? 0}",
                                icon: Icons.warning_rounded,
                                iconColor: const Color(0xFFEA580C),
                                iconBg: const Color(0xFFFFEDD5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildImage2KPICard(
                                title: "Completed IA",
                                value: "${_overview['completed_submissions'] ?? 0}",
                                icon: Icons.verified_rounded,
                                iconColor: const Color(0xFF7C3AED),
                                iconBg: const Color(0xFFEDE9FE),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // 5. Controls Toolbar & Tabs Container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Toolbar
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 260,
                                  height: 42,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: "Search test, subject, faculty...",
                                      hintStyle: const TextStyle(fontSize: 13),
                                      prefixIcon: const Icon(Icons.search, size: 20),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                    ),
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                  ),
                                ),
                                Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFFF8FAFC),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedSemester,
                                      hint: const Text("All Semesters", style: TextStyle(fontSize: 13)),
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text("All Semesters")),
                                        ...List.generate(8, (i) => DropdownMenuItem(value: "${i + 1}", child: Text("Semester ${i + 1}"))),
                                      ],
                                      onChanged: (val) {
                                        setState(() => _selectedSemester = val);
                                        _loadData();
                                      },
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFFF8FAFC),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedIAType,
                                      hint: const Text("All IA Types", style: TextStyle(fontSize: 13)),
                                      items: const [
                                        DropdownMenuItem(value: null, child: Text("All IA Types")),
                                        DropdownMenuItem(value: "IA-1", child: Text("IA-1")),
                                        DropdownMenuItem(value: "IA-2", child: Text("IA-2")),
                                        DropdownMenuItem(value: "IA-3", child: Text("IA-3")),
                                        DropdownMenuItem(value: "Assignment", child: Text("Assignment")),
                                        DropdownMenuItem(value: "Lab", child: Text("Lab")),
                                      ],
                                      onChanged: (val) {
                                        setState(() => _selectedIAType = val);
                                        _loadData();
                                      },
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF13246E),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: _exportCSV,
                                  icon: const Icon(Icons.download, size: 18),
                                  label: const Text("Export CSV"),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),

                          // TabBar
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: const Color(0xFF13246E),
                            unselectedLabelColor: Colors.grey.shade600,
                            indicatorColor: const Color(0xFF13246E),
                            indicatorWeight: 3,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            tabs: [
                              Tab(text: "Marks Submissions (${filteredSubmissions.length})"),
                              Tab(text: "Subject Results & Pass % (${_subjectResults.length})"),
                              Tab(
                                child: Row(
                                  children: [
                                    const Text("Academic Support (<40%)"),
                                    if (_needingSupport.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                        child: Text(
                                          "${_needingSupport.length}",
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Tab(text: "Missing / Suspicious Marks (${_suspiciousMarks.length})"),
                            ],
                          ),
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),

                          // Tab View
                          SizedBox(
                            height: 540,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildSubmissionsTab(filteredSubmissions),
                                _buildSubjectResultsTab(),
                                _buildNeedingSupportTab(),
                                _buildSuspiciousMarksTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage2KPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsTab(List<Map<String, dynamic>> submissionsList) {
    if (submissionsList.isEmpty) {
      return const Center(child: Text("No IA tests scheduled or matching criteria."));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Semester", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("IA Test", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Max Marks", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Faculty", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Submissions", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: submissionsList.map((s) {
            final submitted = s['submitted_count'] ?? 0;
            final eligible = s['eligible_count'] ?? 0;
            final statusCode = (s['status'] ?? '').toString();
            final statusLabel = s['status_label'] ?? statusCode;

            Color statusColor;
            Color statusBg;
            if (statusCode == 'NO_STUDENTS') {
              statusColor = Colors.grey.shade700;
              statusBg = Colors.grey.shade200;
            } else if (statusCode == 'NOT_STARTED') {
              statusColor = Colors.blueGrey.shade700;
              statusBg = Colors.blueGrey.shade100;
            } else if (statusCode == 'IN_PROGRESS') {
              statusColor = Colors.blue.shade800;
              statusBg = Colors.blue.shade100;
            } else if (statusCode == 'COMPLETED' || statusCode == 'SUBMITTED') {
              statusColor = Colors.green.shade800;
              statusBg = Colors.green.shade100;
            } else {
              statusColor = Colors.orange.shade800;
              statusBg = Colors.orange.shade100;
            }

            return DataRow(
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['subject_code'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(s['subject_name'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                DataCell(Text("Sem ${s['semester'] ?? 'N/A'}")),
                DataCell(Text(s['ia_name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text("${s['max_marks'] ?? 0}")),
                DataCell(Text(s['faculty_name'] ?? 'Unassigned')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("$submitted / $eligible", style: TextStyle(fontWeight: FontWeight.bold, color: submitted >= eligible && eligible > 0 ? Colors.green.shade800 : Colors.black87)),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                DataCell(
                  TextButton.icon(
                    onPressed: () => _showTestStudentsDialog(s['test_id'], s['subject_code'] ?? '', s['ia_name'] ?? '', s['max_marks']),
                    icon: const Icon(Icons.people_outline, size: 14),
                    label: const Text("View Marks", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectResultsTab() {
    if (_subjectResults.isEmpty) {
      return const Center(child: Text("No subject marks registered."));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text("Code", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Subject Name", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Semester", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Faculty", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Tests", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Marks Count", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Average %", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Pass %", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Highest", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Lowest", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _subjectResults.map((r) {
            final passPct = (r['pass_percentage'] as num?)?.toDouble() ?? 0.0;
            return DataRow(
              cells: [
                DataCell(Text(r['subject_code'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(r['subject_name'] ?? 'N/A')),
                DataCell(Text("Sem ${r['semester'] ?? 'N/A'}")),
                DataCell(Text(r['faculty_name'] ?? 'Unassigned')),
                DataCell(Text("${r['tests_count'] ?? 0}")),
                DataCell(Text("${r['marks_count'] ?? 0}")),
                DataCell(Text("${r['average_percentage'] ?? 0}%")),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (passPct >= 75 ? Colors.green : (passPct >= 40 ? Colors.orange : Colors.red)).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$passPct%",
                      style: TextStyle(
                        color: passPct >= 75 ? Colors.green.shade800 : (passPct >= 40 ? Colors.orange.shade800 : Colors.red.shade800),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(Text("${r['highest_score'] ?? 0}")),
                DataCell(Text("${r['lowest_score'] ?? 0}")),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNeedingSupportTab() {
    if (_needingSupport.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_rounded, size: 54, color: Colors.green.shade600),
            const SizedBox(height: 12),
            const Text("Excellent! No students scored below 40% in internal tests.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
        columns: const [
          DataColumn(label: Text("USN", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Semester", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("IA Test", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Obtained", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Percentage", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _needingSupport.map((s) {
          final pct = (s['percentage'] as num?)?.toDouble() ?? 0.0;
          return DataRow(
            cells: [
              DataCell(Text(s['usn'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(s['student_name'] ?? 'N/A')),
              DataCell(Text("Sem ${s['semester'] ?? 'N/A'}")),
              DataCell(Text("${s['subject_code']} - ${s['subject_name']}")),
              DataCell(Text(s['ia_name'] ?? 'N/A')),
              DataCell(Text("${s['obtained_marks']} / ${s['max_marks']}")),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text("$pct%", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Academic counselling notice scheduled for student ${s['usn']}.")),
                    );
                  },
                  icon: const Icon(Icons.support_agent_rounded, size: 14),
                  label: const Text("Support Notice", style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuspiciousMarksTab() {
    if (_suspiciousMarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, size: 48, color: Colors.blue.shade600),
            const SizedBox(height: 12),
            const Text("No suspicious marks or missing entries detected.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _suspiciousMarks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _suspiciousMarks[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Icon(Icons.flag_rounded, color: Colors.orange.shade800),
          ),
          title: Text("${item['student_usn']} - ${item['student_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Subject: ${item['subject_code']} | Test: ${item['ia_name']} | Reason: ${item['reason']}"),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(6)),
            child: Text(
              "0 / ${item['max_marks']}",
              style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
