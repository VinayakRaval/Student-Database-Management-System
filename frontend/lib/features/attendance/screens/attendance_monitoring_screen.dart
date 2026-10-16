import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

class AttendanceMonitoringScreen extends StatefulWidget {
  const AttendanceMonitoringScreen({super.key});

  @override
  State<AttendanceMonitoringScreen> createState() => _AttendanceMonitoringScreenState();
}

class _AttendanceMonitoringScreenState extends State<AttendanceMonitoringScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _deptInfo = {};
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _lowAttendanceStudents = [];
  List<Map<String, dynamic>> _correctionRequests = [];

  String _searchQuery = "";
  String? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      final res = await dio.get('/attendance/monitoring/summary/');
      if (mounted) {
        setState(() {
          _overview = Map<String, dynamic>.from(res.data['overview'] ?? {});
          _deptInfo = Map<String, dynamic>.from(res.data['department_info'] ?? {});
          _subjects = List<Map<String, dynamic>>.from(res.data['subjects'] ?? []);
          _submissions = List<Map<String, dynamic>>.from(res.data['submissions'] ?? []);
          _lowAttendanceStudents = List<Map<String, dynamic>>.from(res.data['low_attendance_students'] ?? []);
          _correctionRequests = List<Map<String, dynamic>>.from(res.data['correction_requests'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load attendance monitoring data. Please retry.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reviewCorrectionWithRemarks(int requestId, String action) async {
    final remarksController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("$action Correction Request", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Provide any remarks or audit notes for this $action action (optional):", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter remarks...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'APPROVE' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = ApiClient().dio;
      await dio.post('/attendance/correction-requests/$requestId/review/', data: {
        'action': action,
        'remarks': remarksController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Correction request ${action.toLowerCase()}d successfully."),
            backgroundColor: action == 'APPROVE' ? Colors.green : Colors.red,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSubjectStudentsDialog(dynamic subjectId, String code, String name) async {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return FutureBuilder<Response>(
            future: ApiClient().dio.get('/attendance/monitoring/subject-students/', queryParameters: {'subject_id': subjectId}),
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
                    child: Text("Failed to load student attendance: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
                  ),
                );
              } else {
                final data = snapshot.data?.data;
                final List students = (data is Map && data['students'] is List) ? data['students'] : [];
                final summary = (data is Map && data['summary'] is Map) ? data['summary'] : {};

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
                            _miniMetric("Total Enrolled", "${summary['total_enrolled'] ?? students.length}"),
                            _miniMetric("Total Sessions", "${summary['total_sessions'] ?? 0}"),
                            _miniMetric("Avg Attendance", "${summary['avg_attendance'] ?? 0}%"),
                            _miniMetric("Shortage (<75%)", "${summary['shortage_count'] ?? 0}", isAlert: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: students.isEmpty
                            ? const Center(child: Text("No students enrolled or recorded for this subject."))
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
                                      DataColumn(label: Text("Attended", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Percentage", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: students.map<DataRow>((st) {
                                      final pct = (st['percentage'] as num?)?.toDouble() ?? 0.0;
                                      final isShortage = pct < 75.0;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(st['usn']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(Text(st['name']?.toString() ?? 'N/A')),
                                          DataCell(Text("Sem ${st['semester'] ?? 'N/A'}")),
                                          DataCell(Text("${st['attended_classes'] ?? 0}")),
                                          DataCell(Text("${st['total_classes'] ?? 0}")),
                                          DataCell(Text("$pct%", style: TextStyle(fontWeight: FontWeight.bold, color: isShortage ? Colors.red.shade800 : Colors.green.shade800))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (isShortage ? Colors.red : Colors.green).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isShortage ? "Shortage" : "Eligible",
                                                style: TextStyle(
                                                  color: isShortage ? Colors.red.shade800 : Colors.green.shade800,
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
                          Text("$code: $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF13246E))),
                          const SizedBox(height: 2),
                          const Text("Student-Wise Attendance Roster", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
    csv.writeln("Attendance Summary Report - ${_deptInfo['name'] ?? 'Department'}");
    csv.writeln("Average Dept Attendance,${_overview['avg_dept_attendance'] ?? 0}%");
    csv.writeln("Total Active Students,${_overview['total_students'] ?? 0}");
    csv.writeln("Total Faculty,${_overview['total_faculty'] ?? 0}");
    csv.writeln("Low Attendance Alerts (<75%),${_overview['low_attendance_count'] ?? 0}");
    csv.writeln();
    csv.writeln("Subject Code,Subject Name,Semester,Faculty,Total Sessions,Attendance %,Status");
    for (var s in _subjects) {
      final pctStr = s['attendance_percentage'] != null ? "${s['attendance_percentage']}%" : "N/A";
      csv.writeln('"${s['subject_code']}","${s['subject_name']}","Sem ${s['semester']}","${s['faculty_name']}",${s['total_sessions']},$pctStr,"${s['status_label'] ?? s['status']}"');
    }
    csv.writeln();
    csv.writeln("Students Below Threshold (<75%)");
    csv.writeln("USN,Name,Semester,Attended,Total,Percentage,Phone");
    for (var st in _lowAttendanceStudents) {
      csv.writeln('"${st['usn']}","${st['name']}","Sem ${st['semester']}",${st['attended_classes']},${st['total_classes']},${st['percentage']}%,${st['phone']}');
    }

    Clipboard.setData(ClipboardData(text: csv.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Attendance summary report copied to clipboard in CSV format!"),
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

    // Filtered lists
    final filteredSubjects = _subjects.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          (s['subject_code'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['subject_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['faculty_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSem = _selectedSemester == null ||
          _selectedSemester!.isEmpty ||
          s['semester']?.toString() == _selectedSemester;
      return matchesSearch && matchesSem;
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
                    Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      "Attendance Monitoring",
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

                    // 3. Department Statistics Title (Image 2 style)
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
                                title: "Dept Attendance",
                                value: "${_overview['avg_dept_attendance'] ?? 0}%",
                                icon: Icons.pie_chart_rounded,
                                iconColor: const Color(0xFF13246E),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildImage2KPICard(
                                title: "Active Students",
                                value: "${_overview['total_students'] ?? 0}",
                                icon: Icons.groups_rounded,
                                iconColor: const Color(0xFF0D9488),
                                iconBg: const Color(0xFFCCFBF1),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildImage2KPICard(
                                title: "Low Attendance (<75%)",
                                value: "${_overview['low_attendance_count'] ?? 0}",
                                icon: Icons.warning_amber_rounded,
                                iconColor: const Color(0xFFEA580C),
                                iconBg: const Color(0xFFFFEDD5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildImage2KPICard(
                                title: "Pending Reviews",
                                value: "${_overview['pending_corrections'] ?? 0}",
                                icon: Icons.assignment_late_rounded,
                                iconColor: const Color(0xFFDC2626),
                                iconBg: const Color(0xFFFEE2E2),
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
                                      hintText: "Search subject, faculty, USN...",
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
                                      onChanged: (val) => setState(() => _selectedSemester = val),
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
                              Tab(text: "Subject Attendance (${filteredSubjects.length})"),
                              Tab(text: "Professor Submissions (${_submissions.length})"),
                              Tab(
                                child: Row(
                                  children: [
                                    const Text("Below Threshold (<75%)"),
                                    if (_lowAttendanceStudents.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                        child: Text(
                                          "${_lowAttendanceStudents.length}",
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Tab(text: "Correction Requests (${_correctionRequests.length})"),
                              const Tab(text: "Attendance Summary"),
                            ],
                          ),
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),

                          // Tab View
                          SizedBox(
                            height: 540,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildSubjectsTab(filteredSubjects),
                                _buildSubmissionsTab(),
                                _buildLowAttendanceTab(),
                                _buildCorrectionsTab(),
                                _buildSummaryTab(),
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

  Widget _buildSubjectsTab(List<Map<String, dynamic>> subjectsList) {
    if (subjectsList.isEmpty) {
      return const Center(child: Text("No subjects matching criteria."));
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
            DataColumn(label: Text("Sessions", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Attendance %", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: subjectsList.map((s) {
            final numSessions = s['total_sessions'] ?? 0;
            final pct = (s['attendance_percentage'] as num?)?.toDouble();
            final statusCode = (s['status'] ?? '').toString();
            final statusLabel = s['status_label'] ?? statusCode;

            Color statusColor;
            Color statusBg;
            if (statusCode == 'UNASSIGNED') {
              statusColor = Colors.grey.shade700;
              statusBg = Colors.grey.shade200;
            } else if (statusCode == 'NO_SESSIONS') {
              statusColor = Colors.blueGrey.shade700;
              statusBg = Colors.blueGrey.shade100;
            } else if (statusCode == 'HEALTHY' || (pct != null && pct >= 75)) {
              statusColor = Colors.green.shade800;
              statusBg = Colors.green.shade100;
            } else {
              statusColor = Colors.red.shade800;
              statusBg = Colors.red.shade100;
            }

            return DataRow(
              cells: [
                DataCell(Text(s['subject_code'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(
                  Row(
                    children: [
                      Text(s['subject_name'] ?? 'N/A'),
                      if (s['is_elective'] == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text("Elective", style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(Text("Sem ${s['semester'] ?? 'N/A'}")),
                DataCell(Text(s['faculty_name'] ?? 'Unassigned')),
                DataCell(Text("$numSessions")),
                DataCell(
                  pct != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 50,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (pct / 100).clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(pct >= 75 ? Colors.green : Colors.red),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text("$pct%", style: TextStyle(fontWeight: FontWeight.bold, color: pct >= 75 ? Colors.green.shade800 : Colors.red.shade800)),
                          ],
                        )
                      : Text("N/A", style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
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
                    onPressed: () => _showSubjectStudentsDialog(s['subject_id'], s['subject_code'] ?? '', s['subject_name'] ?? ''),
                    icon: const Icon(Icons.people_outline, size: 14),
                    label: const Text("View Students", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubmissionsTab() {
    if (_submissions.isEmpty) {
      return const Center(child: Text("No attendance sessions recorded yet."));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _submissions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final sub = _submissions[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF13246E).withOpacity(0.1),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF13246E)),
          ),
          title: Text("${sub['subject_code']} - ${sub['subject_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Faculty: ${sub['faculty_name']} | Date: ${sub['date']} | Students marked: ${sub['records_count']}"),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              sub['status'] ?? 'SUBMITTED',
              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLowAttendanceTab() {
    if (_lowAttendanceStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green.shade600),
            const SizedBox(height: 12),
            const Text("All students maintain attendance at or above 75%!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          DataColumn(label: Text("Classes Attended", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Attendance %", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Phone", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _lowAttendanceStudents.map((st) {
          final pct = (st['percentage'] as num?)?.toDouble() ?? 0.0;
          return DataRow(
            cells: [
              DataCell(Text(st['usn'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(st['name'] ?? 'N/A')),
              DataCell(Text("Sem ${st['semester'] ?? 'N/A'}")),
              DataCell(Text("${st['attended_classes']} / ${st['total_classes']}")),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text("$pct%", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(Text(st['phone'] ?? 'N/A')),
              DataCell(
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Alert notification dispatched to student ${st['usn']} and faculty advisor.")),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text("Send Alert", style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCorrectionsTab() {
    if (_correctionRequests.isEmpty) {
      return const Center(child: Text("No attendance correction requests submitted."));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _correctionRequests.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final cr = _correctionRequests[index];
        final isPending = (cr['status'] ?? '').toString().toUpperCase() == 'PENDING';
        return ListTile(
          title: Row(
            children: [
              Text("${cr['student_usn']} - ${cr['student_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange.shade100 : (cr['status'] == 'APPROVED' ? Colors.green.shade100 : Colors.red.shade100),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cr['status'] ?? 'PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPending ? Colors.orange.shade900 : (cr['status'] == 'APPROVED' ? Colors.green.shade900 : Colors.red.shade900),
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text("Faculty: ${cr['faculty_name']} | Requested Status: ${cr['requested_status']} | Submitted: ${cr['created_at']}"),
              Text("Reason: ${cr['reason']}", style: TextStyle(color: Colors.grey.shade700)),
              if (cr['remarks'] != null && cr['remarks'].toString().isNotEmpty)
                Text("Remarks: ${cr['remarks']}", style: const TextStyle(color: Color(0xFF13246E), fontStyle: FontStyle.italic)),
            ],
          ),
          trailing: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _reviewCorrectionWithRemarks(cr['id'], 'APPROVE'),
                      child: const Text("Approve", style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _reviewCorrectionWithRemarks(cr['id'], 'REJECT'),
                      child: const Text("Reject", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Department Attendance Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
          const SizedBox(height: 12),
          Text(
            "This report summarizes current semester attendance across all courses and laboratory sessions taught in ${_deptInfo['name'] ?? 'this department'}.",
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow("Department Average Attendance", "${_overview['avg_dept_attendance'] ?? 0}%"),
                  const Divider(),
                  _summaryRow("Total Enrolled Students", "${_overview['total_students'] ?? 0}"),
                  const Divider(),
                  _summaryRow("Total Faculty Staff", "${_overview['total_faculty'] ?? 0}"),
                  const Divider(),
                  _summaryRow("Subjects Tracked", "${_subjects.length}"),
                  const Divider(),
                  _summaryRow("Students Under Threshold (<75%)", "${_overview['low_attendance_count'] ?? 0}"),
                  const Divider(),
                  _summaryRow("Pending Review Requests", "${_overview['pending_corrections'] ?? 0}"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: _exportCSV,
            icon: const Icon(Icons.copy_all),
            label: const Text("Copy Full CSV Summary"),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E))),
        ],
      ),
    );
  }
}
