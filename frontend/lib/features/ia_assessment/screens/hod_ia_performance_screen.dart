import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/app_pagination_bar.dart';

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

  int _submissionsPage = 1;
  int _resultsPage = 1;
  int _supportPage = 1;
  int _suspiciousPage = 1;
  final int _pageSize = 10;

  String _searchQuery = "";
  String? _selectedSemester;
  String? _selectedIAType;
  String? _selectedAcademicYear;
  String? _selectedDepartment;
  List<Map<String, dynamic>> _academicYears = [];
  List<Map<String, dynamic>> _departments = [];

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

      if (_academicYears.isEmpty) {
        try {
          final ayRes = await dio.get('/academics/academic-years/');
          final List rawAy = ayRes.data is List ? ayRes.data : [];
          _academicYears = rawAy.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }

      if (_departments.isEmpty) {
        try {
          final deptRes = await dio.get('/academics/departments/');
          final List rawD = deptRes.data is List ? deptRes.data : [];
          _departments = rawD.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }

      final queryParams = <String, dynamic>{};
      if (_selectedDepartment != null && _selectedDepartment!.isNotEmpty) {
        queryParams['department_id'] = _selectedDepartment;
      }
      if (_selectedSemester != null && _selectedSemester!.isNotEmpty) {
        queryParams['semester_id'] = _selectedSemester;
      }
      if (_selectedIAType != null && _selectedIAType!.isNotEmpty) {
        queryParams['ia_type'] = _selectedIAType;
      }
      if (_selectedAcademicYear != null && _selectedAcademicYear!.isNotEmpty) {
        queryParams['academic_year_id'] = _selectedAcademicYear;
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
          _submissionsPage = 1;
          _resultsPage = 1;
          _supportPage = 1;
          _suspiciousPage = 1;
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

  Widget _buildPreLockMetricCard(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isAlert = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isAlert ? Colors.red.shade800 : const Color(0xFF1E293B))),
      ],
    );
  }

  Future<void> _showLockSemesterIADialog() async {
    String currentSem = _selectedSemester ?? '1';
    bool applyException = false;
    final reasonController = TextEditingController(text: "Semester-end IA Locked by HOD");
    final exceptionReasonController = TextEditingController();
    Future<Response>? summaryFuture;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          summaryFuture ??= ApiClient().dio.get(
            '/ia/hod/pre-lock-summary/',
            queryParameters: {'semester_id': currentSem},
          );

          return FutureBuilder<Response>(
            future: summaryFuture,
            builder: (context, snapshot) {
              Widget body;

              if (snapshot.connectionState == ConnectionState.waiting) {
                body = const SizedBox(
                  height: 350,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Verifying assessment completion & records integrity...", style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                final err = snapshot.error;
                String msg = "Failed to load pre-lock summary.";
                if (err is DioException && err.response?.data is Map && err.response!.data['error'] != null) {
                  msg = err.response!.data['error'].toString();
                }
                body = SizedBox(
                  height: 250,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text(msg, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              summaryFuture = ApiClient().dio.get(
                                '/ia/hod/pre-lock-summary/',
                                queryParameters: {'semester_id': currentSem},
                              );
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                final data = Map<String, dynamic>.from(snapshot.data?.data ?? {});
                final counts = Map<String, dynamic>.from(data['counts'] ?? {});
                final bool isLocked = data['is_locked'] == true;
                final bool canLock = data['can_lock'] == true;
                final List blockingReasons = data['blocking_reasons'] as List? ?? [];
                final int totalTests = counts['total_tests'] ?? 0;
                final int verifiedTests = counts['verified_tests'] ?? 0;
                final int draftTests = counts['draft_tests'] ?? 0;
                final int returnedTests = counts['returned_tests'] ?? 0;
                final int missingMarks = counts['missing_marks_count'] ?? 0;
                final int unresolvedCorrections = counts['unresolved_corrections_count'] ?? 0;

                body = SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF13246E), size: 20),
                            const SizedBox(width: 10),
                            const Text("Target Semester:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(width: 12),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentSem,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E), fontSize: 14),
                                items: List.generate(8, (i) => DropdownMenuItem(value: "${i + 1}", child: Text("Semester ${i + 1}"))),
                                onChanged: (val) {
                                  if (val != null && val != currentSem) {
                                    setModalState(() {
                                      currentSem = val;
                                      summaryFuture = ApiClient().dio.get(
                                        '/ia/hod/pre-lock-summary/',
                                        queryParameters: {'semester_id': currentSem},
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLocked ? Colors.red.shade100 : (canLock ? Colors.green.shade100 : Colors.amber.shade100),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLocked ? Icons.lock_rounded : (canLock ? Icons.check_circle_rounded : Icons.pending_rounded),
                                    size: 14,
                                    color: isLocked ? Colors.red.shade900 : (canLock ? Colors.green.shade900 : Colors.amber.shade900),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isLocked ? "LOCKED" : (canLock ? "ELIGIBLE TO LOCK" : "ACTION REQUIRED"),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isLocked ? Colors.red.shade900 : (canLock ? Colors.green.shade900 : Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildPreLockMetricCard("Total Assessments", "$totalTests", Icons.quiz_outlined, const Color(0xFF13246E), const Color(0xFFEEF2FF)),
                          _buildPreLockMetricCard("Verified / Approved", "$verifiedTests", Icons.verified_outlined, Colors.green.shade800, Colors.green.shade50),
                          _buildPreLockMetricCard("In Draft", "$draftTests", Icons.edit_note_rounded, draftTests > 0 ? Colors.red.shade800 : Colors.grey.shade700, draftTests > 0 ? Colors.red.shade50 : Colors.grey.shade100),
                          _buildPreLockMetricCard("Returned", "$returnedTests", Icons.replay_rounded, returnedTests > 0 ? Colors.orange.shade800 : Colors.grey.shade700, returnedTests > 0 ? Colors.orange.shade50 : Colors.grey.shade100),
                          _buildPreLockMetricCard("Missing Marks", "$missingMarks", Icons.person_off_outlined, missingMarks > 0 ? Colors.red.shade800 : Colors.grey.shade700, missingMarks > 0 ? Colors.red.shade50 : Colors.grey.shade100),
                          _buildPreLockMetricCard("Pending Corrections", "$unresolvedCorrections", Icons.rule_folder_outlined, unresolvedCorrections > 0 ? Colors.purple.shade800 : Colors.grey.shade700, unresolvedCorrections > 0 ? Colors.purple.shade50 : Colors.grey.shade100),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (isLocked) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_rounded, color: Color(0xFF991B1B), size: 28),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Semester IA Records Are Fully Finalized & Locked", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B))),
                                    SizedBox(height: 4),
                                    Text("All student IA marks for this semester are locked in permanent read-only mode across all roles. Any emergency corrections require a formal, audited academic correction request.", style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (canLock) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text("All semester subjects, theory IA, and lab batch assessments are complete and verified. Ready to lock.", style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: reasonController,
                          decoration: const InputDecoration(
                            labelText: "Lock Reason / Academic Council Reference",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
                                  SizedBox(width: 8),
                                  Text("Pre-Lock Integrity Check: Unmet Requirements", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...blockingReasons.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("• ", style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                                    Expanded(child: Text(r.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)))),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: applyException,
                                onChanged: (val) {
                                  setModalState(() {
                                    applyException = val ?? false;
                                  });
                                },
                                title: const Text("Apply Institutional Exception Override", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                subtitle: const Text("Requires formal authorization from the Dean / Principal. An unalterable security audit log entry will be created.", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                              if (applyException) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: exceptionReasonController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: "Mandatory Exception Justification & Memo No. *",
                                    hintText: "E.g., Special approval by Academic Dean Memo #AD/2026/412",
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(10),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF991B1B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_rounded, color: Color(0xFF991B1B), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Semester-End IA Marks Lock", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF13246E))),
                          Text("Pre-lock integrity check & permanent immutability", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 720,
                  child: body,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CANCEL"),
                  ),
                  if (snapshot.hasData) ...[
                    Builder(
                      builder: (context) {
                        final data = Map<String, dynamic>.from(snapshot.data?.data ?? {});
                        final bool isLocked = data['is_locked'] == true;
                        final bool canLock = data['can_lock'] == true;

                        if (isLocked) {
                          return const SizedBox.shrink();
                        }

                        if (!canLock && !applyException) {
                          return ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.lock_outline, size: 16),
                            label: const Text("Cannot Lock (Incomplete)"),
                          );
                        }

                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF991B1B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final reason = applyException
                                ? exceptionReasonController.text.trim()
                                : reasonController.text.trim();

                            if (applyException && reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Exception justification reason is mandatory for override."), backgroundColor: Colors.red),
                              );
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (confirmCtx) => AlertDialog(
                                title: const Text("Confirm Permanent Semester IA Lock"),
                                content: Text(
                                  "Are you sure you want to permanently lock Semester $currentSem IA marks?\n\n"
                                  "Once locked, NO PROFESSOR OR HOD will be able to edit, create, or delete marks for this semester.",
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text("CANCEL")),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF991B1B), foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(confirmCtx, true),
                                    child: const Text("YES, LOCK PERMANENTLY"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm != true) return;

                            try {
                              final dio = ApiClient().dio;
                              final res = await dio.post('/ia/hod/lock-semester-ia/', data: {
                                'semester_id': currentSem,
                                'lock_reason': reason.isNotEmpty ? reason : "Semester-end IA Locked by HOD",
                                'allow_exception': applyException,
                              });

                              if (mounted) {
                                Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res.data['message']?.toString() ?? "Semester IA marks successfully locked."),
                                    backgroundColor: Colors.green.shade800,
                                  ),
                                );
                                _loadData();
                              }
                            } catch (e) {
                              String err = "Failed to lock semester IA.";
                              if (e is DioException && e.response?.data is Map) {
                                err = e.response!.data['error']?.toString() ?? e.response!.data['message']?.toString() ?? err;
                              }
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(err), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.lock_rounded, size: 16),
                          label: Text(applyException ? "Override & Lock Semester IA" : "Proceed to Lock Semester IA"),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showReviewTestDialog(Map<String, dynamic> s) async {
    final bool isOwnTest = s['is_own_test'] == true;
    final bool isLocked = s['is_locked'] == true;
    final String currentStatus = s['workflow_status'] ?? s['status'] ?? 'DRAFT';
    final TextEditingController remarksController = TextEditingController(text: s['hod_remarks'] ?? '');
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("${s['subject_code']}: ${s['ia_name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF13246E))),
                          const SizedBox(width: 8),
                          if (s['component_type'] == 'LAB')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF0D9488).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                              child: Text(s['batch_name'] != null ? "LAB: ${s['batch_name']}" : "LAB", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF13246E).withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                              child: const Text("THEORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text("Department Review & Verification • Faculty: ${s['faculty_name'] ?? 'Unassigned'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOwnTest) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, color: Color(0xFFB45309), size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Self-Approval Prohibited (SDMS Integrity Policy)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13)),
                                  SizedBox(height: 3),
                                  Text("You are assigned as the instructor for this course. Department heads cannot review or approve their own IA assessments. This assessment must be reviewed and approved by the Principal or Administrator.", style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (isLocked) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_rounded, color: Color(0xFF991B1B), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text("Assessment is locked. Marks are permanently finalized and cannot be modified or re-reviewed.", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _infoRow("Subject:", "${s['subject_code']} - ${s['subject_name']}"),
                              _infoRow("Semester:", "Semester ${s['semester']}"),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _infoRow("Submissions:", "${s['submitted_count']} / ${s['eligible_count']} students", isAlert: (s['missing_marks'] ?? 0) > 0),
                              _infoRow("Max Marks:", "${s['max_marks']}"),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _infoRow("Current Status:", currentStatus),
                              _infoRow(
                                "Publication:",
                                (s['is_published'] == true || currentStatus == 'PUBLISHED')
                                    ? "Published to Students"
                                    : "Unpublished (Draft / Internal)",
                                isAlert: !(s['is_published'] == true || currentStatus == 'PUBLISHED'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text("Department Remarks / Instructions:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: remarksController,
                      enabled: !isOwnTest && !isLocked && !isSubmitting,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Enter remarks or instructions for faculty (mandatory when returning for correction)...",
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isOwnTest || isLocked ? Colors.grey.shade100 : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CLOSE"),
              ),
              if (!isOwnTest && !isLocked) ...[
                if (currentStatus != 'PUBLISHED')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade900,
                      side: BorderSide(color: Colors.orange.shade800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSubmitting ? null : () async {
                      final remarks = remarksController.text.trim();
                      if (remarks.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Remarks are mandatory when returning an assessment for correction."), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      setModalState(() => isSubmitting = true);
                      try {
                        final dio = ApiClient().dio;
                        await dio.post('/ia/ia-tests/${s['test_id']}/review/', data: {
                          'action': 'RETURN',
                          'remarks': remarks,
                        });

                        if (mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text("Assessment '${s['ia_name']}' returned to faculty with remarks."),
                              backgroundColor: Colors.orange.shade800,
                            ),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        String err = "Failed to return assessment.";
                        if (e is DioException && e.response?.data is Map) {
                          err = e.response!.data['error']?.toString() ?? err;
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.reply_rounded, size: 16),
                    label: const Text("Return for Correction"),
                  ),
                if (currentStatus != 'VERIFIED' && currentStatus != 'APPROVED' && currentStatus != 'PUBLISHED')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166534),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSubmitting ? null : () async {
                      final remarks = remarksController.text.trim();
                      final messenger = ScaffoldMessenger.of(context);
                      setModalState(() => isSubmitting = true);
                      try {
                        final dio = ApiClient().dio;
                        await dio.post('/ia/ia-tests/${s['test_id']}/review/', data: {
                          'action': 'VERIFY',
                          'remarks': remarks,
                        });

                        if (mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text("Assessment '${s['ia_name']}' verified and approved successfully."),
                              backgroundColor: Colors.green.shade800,
                            ),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        String err = "Failed to verify assessment.";
                        if (e is DioException && e.response?.data is Map) {
                          err = e.response!.data['error']?.toString() ?? err;
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text("Verify & Approve"),
                  ),
                if ((currentStatus == 'VERIFIED' || currentStatus == 'APPROVED') && s['is_published'] != true)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2577),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSubmitting ? null : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (cctx) => AlertDialog(
                          title: const Text("Publish Marks to Students"),
                          content: const Text(
                            "Are you sure you want to publish these marks to students?\n\n"
                            "• Marks will become instantly visible to all enrolled students.\n"
                            "• In-app notifications will be delivered to enrolled students.\n"
                            "• Final IA Calculation Engine will recalculate aggregate scores.",
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(cctx, false), child: const Text("CANCEL")),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F2577),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(cctx, true),
                              child: const Text("CONFIRM & PUBLISH"),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;

                      final messenger = ScaffoldMessenger.of(context);
                      setModalState(() => isSubmitting = true);
                      try {
                        final dio = ApiClient().dio;
                        await dio.post('/ia/ia-tests/${s['test_id']}/publish/', data: {'action': 'PUBLISH'});

                        if (mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text("Marks for '${s['ia_name']}' published to students!"),
                              backgroundColor: const Color(0xFF0F2577),
                            ),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        String err = "Failed to publish marks.";
                        if (e is DioException && e.response?.data is Map) {
                          err = e.response!.data['error']?.toString() ?? err;
                        }
                        if (mounted) {
                          messenger.showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                        }
                      }
                    },
                    icon: const Icon(Icons.send_and_archive_rounded, size: 16),
                    label: const Text("Publish to Students"),
                  ),
                if (s['is_published'] == true || currentStatus == 'PUBLISHED')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSubmitting ? null : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (cctx) => AlertDialog(
                          title: const Text("Unpublish Marks"),
                          content: const Text(
                            "Are you sure you want to unpublish these marks? Students will no longer see them on their portals.",
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(cctx, false), child: const Text("CANCEL")),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(cctx, true),
                              child: const Text("UNPUBLISH"),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;

                      final messenger = ScaffoldMessenger.of(context);
                      setModalState(() => isSubmitting = true);
                      try {
                        final dio = ApiClient().dio;
                        await dio.post('/ia/ia-tests/${s['test_id']}/publish/', data: {'action': 'UNPUBLISH'});

                        if (mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Marks unpublished from student portal successfully."),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        String err = "Failed to unpublish marks.";
                        if (e is DioException && e.response?.data is Map) {
                          err = e.response!.data['error']?.toString() ?? err;
                        }
                        if (mounted) {
                          messenger.showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                        }
                      }
                    },
                    icon: const Icon(Icons.visibility_off_rounded, size: 16),
                    label: const Text("Unpublish"),
                  ),
              ],
            ],
          );
        },
      ),
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
          // 1. Top White Header Bar (Image 1 style)
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assessment_rounded, color: Color(0xFF13246E), size: 22),
                    SizedBox(width: 10),
                    Text(
                      "IA & Academic Performance",
                      style: TextStyle(
                        color: Color(0xFF13246E),
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
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF13246E)),
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
                                if (_departments.isNotEmpty)
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
                                        value: _selectedDepartment,
                                        hint: const Text("All Departments", style: TextStyle(fontSize: 13)),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text("All Departments")),
                                          ..._departments.map((d) => DropdownMenuItem(
                                            value: d['id'].toString(),
                                            child: Text(d['name']?.toString() ?? 'Department'),
                                          )),
                                        ],
                                        onChanged: (val) {
                                          setState(() => _selectedDepartment = val);
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
                                      value: _selectedAcademicYear,
                                      hint: const Text("All Academic Years", style: TextStyle(fontSize: 13)),
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text("All Academic Years")),
                                        ..._academicYears.map((ay) => DropdownMenuItem(
                                          value: ay['id'].toString(),
                                          child: Text(ay['year_name']?.toString() ?? 'Year'),
                                        )),
                                      ],
                                      onChanged: (val) {
                                        setState(() => _selectedAcademicYear = val);
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
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF991B1B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: _showLockSemesterIADialog,
                                  icon: const Icon(Icons.lock_rounded, size: 18),
                                  label: const Text("Lock Semester IA"),
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
                            height: 660,
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
    final totalItems = submissionsList.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
    final safePage = _submissionsPage > totalPages ? totalPages : (_submissionsPage < 1 ? 1 : _submissionsPage);
    final pageItems = totalItems == 0 ? <Map<String, dynamic>>[] : submissionsList.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                  DataColumn(label: Text("Workflow Status", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: pageItems.map((s) {
                  final submitted = s['submitted_count'] ?? 0;
                  final eligible = s['eligible_count'] ?? 0;
                  final workflowStatus = (s['workflow_status'] ?? s['status'] ?? 'DRAFT').toString().toUpperCase();
                  final isLocked = s['is_locked'] == true;
                  final isOwnTest = s['is_own_test'] == true;

                  Color statusColor;
                  Color statusBg;
                  IconData statusIcon;
                  String statusText;

                  if (isLocked || workflowStatus == 'LOCKED') {
                    statusColor = const Color(0xFF991B1B);
                    statusBg = const Color(0xFFFEE2E2);
                    statusIcon = Icons.lock_rounded;
                    statusText = "Locked";
                  } else if (s['is_published'] == true || workflowStatus == 'PUBLISHED') {
                    statusColor = const Color(0xFF1D4ED8);
                    statusBg = const Color(0xFFDBEAFE);
                    statusIcon = Icons.public_rounded;
                    statusText = "Published";
                  } else if (workflowStatus == 'VERIFIED' || workflowStatus == 'APPROVED') {
                    statusColor = const Color(0xFF166534);
                    statusBg = const Color(0xFFDCFCE7);
                    statusIcon = Icons.check_circle_rounded;
                    statusText = "Approved";
                  } else if (workflowStatus == 'RETURNED') {
                    statusColor = const Color(0xFFC2410C);
                    statusBg = const Color(0xFFFFEDD5);
                    statusIcon = Icons.replay_rounded;
                    statusText = "Returned";
                  } else if (workflowStatus == 'SUBMITTED') {
                    statusColor = const Color(0xFFB45309);
                    statusBg = const Color(0xFFFEF3C7);
                    statusIcon = Icons.hourglass_top_rounded;
                    statusText = "Submitted";
                  } else {
                    statusColor = const Color(0xFF475569);
                    statusBg = const Color(0xFFF1F5F9);
                    statusIcon = Icons.edit_note_rounded;
                    statusText = "Draft";
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s['subject_code'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                if (s['component_type'] == 'LAB')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: const Color(0xFF0D9488).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                    child: Text(s['batch_name'] != null ? "LAB: ${s['batch_name']}" : "LAB", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: const Color(0xFF13246E).withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                    child: const Text("THEORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                                  ),
                              ],
                            ),
                            Text(s['subject_name'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                      DataCell(Text("Sem ${s['semester'] ?? 'N/A'}")),
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['ia_name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (s['assessment_date'] != null)
                              Text(s['assessment_date'], style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(Text("${s['max_marks'] ?? 0}")),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s['faculty_name'] ?? 'Unassigned'),
                            if (isOwnTest) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text("You", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("$submitted / $eligible", style: TextStyle(fontWeight: FontWeight.bold, color: submitted >= eligible && eligible > 0 ? Colors.green.shade800 : Colors.black87)),
                            if ((s['missing_marks'] ?? 0) > 0)
                              Text("${s['missing_marks']} missing", style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 13, color: statusColor),
                              const SizedBox(width: 4),
                              Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 32),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              onPressed: () => _showTestStudentsDialog(
                                s['test_id'],
                                s['subject_code'] ?? '',
                                s['ia_name'] ?? '',
                                s['max_marks'],
                              ),
                              icon: const Icon(Icons.people_outline, size: 14),
                              label: const Text("Marks", style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOwnTest
                                    ? Colors.amber.shade700
                                    : const Color(0xFF13246E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _showReviewTestDialog(s),
                              icon: Icon(
                                isOwnTest ? Icons.shield_outlined : Icons.rate_review_rounded,
                                size: 14,
                              ),
                              label: Text(
                                isOwnTest ? "Self-Test" : "Review",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        AppPaginationBar(
          currentPage: safePage,
          totalPages: totalPages,
          totalItems: totalItems,
          pageSize: _pageSize,
          activeColor: const Color(0xFF13246E),
          onPageChanged: (newPage) {
            setState(() {
              _submissionsPage = newPage;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubjectResultsTab() {
    if (_subjectResults.isEmpty) {
      return const Center(child: Text("No subject marks registered."));
    }
    final totalItems = _subjectResults.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
    final safePage = _resultsPage > totalPages ? totalPages : (_resultsPage < 1 ? 1 : _resultsPage);
    final pageItems = totalItems == 0 ? <Map<String, dynamic>>[] : _subjectResults.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                rows: pageItems.map((r) {
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
          ),
        ),
        AppPaginationBar(
          currentPage: safePage,
          totalPages: totalPages,
          totalItems: totalItems,
          pageSize: _pageSize,
          activeColor: const Color(0xFF13246E),
          onPageChanged: (newPage) {
            setState(() {
              _resultsPage = newPage;
            });
          },
        ),
      ],
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
    final totalItems = _needingSupport.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
    final safePage = _supportPage > totalPages ? totalPages : (_supportPage < 1 ? 1 : _supportPage);
    final pageItems = totalItems == 0 ? <Map<String, dynamic>>[] : _needingSupport.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                rows: pageItems.map((s) {
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
            ),
          ),
        ),
        AppPaginationBar(
          currentPage: safePage,
          totalPages: totalPages,
          totalItems: totalItems,
          pageSize: _pageSize,
          activeColor: const Color(0xFF13246E),
          onPageChanged: (newPage) {
            setState(() {
              _supportPage = newPage;
            });
          },
        ),
      ],
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
    final totalItems = _suspiciousMarks.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
    final safePage = _suspiciousPage > totalPages ? totalPages : (_suspiciousPage < 1 ? 1 : _suspiciousPage);
    final pageItems = totalItems == 0 ? <Map<String, dynamic>>[] : _suspiciousMarks.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pageItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = pageItems[index];
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
          ),
        ),
        AppPaginationBar(
          currentPage: safePage,
          totalPages: totalPages,
          totalItems: totalItems,
          pageSize: _pageSize,
          activeColor: const Color(0xFF13246E),
          onPageChanged: (newPage) {
            setState(() {
              _suspiciousPage = newPage;
            });
          },
        ),
      ],
    );
  }
}
