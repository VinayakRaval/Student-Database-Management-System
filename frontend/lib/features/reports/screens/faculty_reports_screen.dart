import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/app_pagination_bar.dart';

class FacultyReportsScreen extends StatefulWidget {
  const FacultyReportsScreen({super.key});

  @override
  State<FacultyReportsScreen> createState() => _FacultyReportsScreenState();
}

class _FacultyReportsScreenState extends State<FacultyReportsScreen> {
  // Report Types:
  // ATTENDANCE: Subject Attendance Report
  // LOW_ATTENDANCE: Attendance Shortage Alert (<75%)
  // IA_PERFORMANCE: Internal Assessment Performance
  // LOW_MARKS: Academic Support Alert (<40%)
  // STUDENTS: Student Roster
  String _selectedReportType = 'ATTENDANCE';
  String? _selectedSubjectId;
  String? _selectedSemesterId;
  String _searchQuery = '';
  int _currentPage = 1;
  final int _pageSize = 10;

  List<Map<String, dynamic>> _assignedSubjects = [];
  List<Map<String, dynamic>> _semesters = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _reportTitle = 'Faculty Attendance Report';
  List<String> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _facultyInfo = {};

  final TextEditingController _searchController = TextEditingController();
  double _shortageThreshold = 75.0;

  List<Map<String, dynamic>> get _reportOptions => [
    {
      'type': 'ATTENDANCE',
      'label': 'Attendance Report',
      'subtitle': 'Class attendance and participation',
      'icon': Icons.fact_check_rounded,
      'color': const Color(0xFF13246E),
    },
    {
      'type': 'LOW_ATTENDANCE',
      'label': 'Attendance Alert (<${_shortageThreshold.toInt()}%)',
      'subtitle': 'Students below ${_shortageThreshold.toInt()}% attendance threshold',
      'icon': Icons.warning_amber_rounded,
      'color': const Color(0xFFD97706),
    },
    {
      'type': 'IA_PERFORMANCE',
      'label': 'IA Marks & Results',
      'subtitle': 'Internal assessment marks and evaluation',
      'icon': Icons.grade_rounded,
      'color': const Color(0xFF3B38A0),
    },
    {
      'type': 'LOW_MARKS',
      'label': 'Academic Support (<40%)',
      'subtitle': 'Students requiring extra academic assistance',
      'icon': Icons.help_outline_rounded,
      'color': const Color(0xFFDC2626),
    },
    {
      'type': 'STUDENTS',
      'label': 'Class Student Roster',
      'subtitle': 'Students enrolled in assigned classes',
      'icon': Icons.people_alt_rounded,
      'color': const Color(0xFF0D9488),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final dio = ApiClient().dio;
      // Fetch semesters
      try {
        final semRes = await dio.get('/academics/semesters/');
        final semData = semRes.data is List ? semRes.data : (semRes.data['results'] ?? []);
        _semesters = List<Map<String, dynamic>>.from(semData);
      } catch (_) {}

      // Fetch subjects assigned to faculty
      try {
        final subRes = await dio.get('/subjects/professor/subjects/');
        final subData = subRes.data is List ? subRes.data : (subRes.data['results'] ?? []);
        _assignedSubjects = List<Map<String, dynamic>>.from(subData);
      } catch (_) {}

      await _fetchReport();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load initial report: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{
        'report_type': _selectedReportType,
      };

      if (_selectedSubjectId != null && _selectedSubjectId!.isNotEmpty) {
        queryParams['subject_id'] = _selectedSubjectId;
      }
      if (_selectedSemesterId != null && _selectedSemesterId!.isNotEmpty) {
        queryParams['semester_id'] = _selectedSemesterId;
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['q'] = _searchQuery.trim();
      }
      if (_selectedReportType == 'LOW_ATTENDANCE') {
        queryParams['threshold'] = _shortageThreshold.toInt();
      }

      final res = await dio.get('/academics/reports/faculty/', queryParameters: queryParams);

      if (mounted) {
        final List colData = res.data['columns'] ?? [];
        final List rowData = res.data['rows'] ?? [];

        // If backend passed assigned subjects and we don't have them yet, grab them
        final List backendSubjects = res.data['assigned_subjects'] ?? [];
        if (_assignedSubjects.isEmpty && backendSubjects.isNotEmpty) {
          _assignedSubjects = List<Map<String, dynamic>>.from(backendSubjects);
        }

        final parsedRows = rowData.map((r) => Map<String, dynamic>.from(r as Map)).toList();
        parsedRows.sort((a, b) {
          final usnA = (a['USN'] ?? a['usn'] ?? '').toString();
          final usnB = (b['USN'] ?? b['usn'] ?? '').toString();
          if (usnA.isNotEmpty && usnB.isNotEmpty) {
            return usnA.compareTo(usnB);
          }
          return 0;
        });

        setState(() {
          _reportTitle = res.data['title'] ?? 'Academic Report';
          _columns = colData.map((c) => c.toString()).toList();
          _rows = parsedRows;
          _summary = Map<String, dynamic>.from(res.data['summary'] ?? {});
          _facultyInfo = Map<String, dynamic>.from(res.data['department_info'] ?? {});
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Unable to generate report. Please verify connection and retry.";
          _isLoading = false;
        });
      }
    }
  }

  void _exportCSV() {
    if (_rows.isEmpty || _columns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No records available to export.")),
      );
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln('"$_reportTitle - CampusFlow SDMS"');
    csv.writeln('"Generated for: ${_facultyInfo['faculty_name'] ?? 'Faculty'}"');
    csv.writeln(_columns.map((c) => '"$c"').join(','));

    for (var r in _rows) {
      final rowVals = r.values.map((v) => '"${v.toString().replaceAll('"', '""')}"').join(',');
      csv.writeln(rowVals);
    }

    Clipboard.setData(ClipboardData(text: csv.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Report exported and copied to clipboard as CSV (Excel compatible)!"),
        backgroundColor: Color(0xFF13246E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Banner
            _buildHeaderBanner(context, isDark),
            const SizedBox(height: 24),

            // Report Type Selector Cards
            _buildReportTypeSelector(isDark),
            const SizedBox(height: 24),

            // Configurable Threshold for Image 2 (Attendance Alert)
            if (_selectedReportType == 'LOW_ATTENDANCE') ...[
              _buildThresholdConfigCard(isDark),
              const SizedBox(height: 24),
            ],

            // Filter Bar
            _buildFilterBar(isDark),
            const SizedBox(height: 24),

            // Summary Metric Cards
            if (_summary.isNotEmpty) ...[
              _buildSummaryCards(isDark),
              const SizedBox(height: 24),
            ],

            // Report Data Table Card
            _buildReportTableCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF13246E), const Color(0xFF2E3D8F)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Academic Reports & Analytics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Faculty Academic Performance Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Monitor student attendance records, internal assessment scores, identify low-attendance alerts (<75%), and export official grade sheets.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _exportCSV,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export CSV / Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF13246E),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Report Module',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _reportOptions.map((opt) {
              final isSelected = _selectedReportType == opt['type'];
              final optColor = opt['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedReportType = opt['type'];
                      _selectedSubjectId = null;
                      _selectedSemesterId = null;
                    });
                    _fetchReport();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? optColor.withOpacity(isDark ? 0.25 : 0.08)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      border: Border.all(
                        color: isSelected
                            ? optColor
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? optColor
                                    : optColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                opt['icon'] as IconData,
                                size: 18,
                                color: isSelected ? Colors.white : optColor,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, size: 18, color: optColor),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          opt['label'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt['subtitle'],
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdConfigCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD97706).withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Customize Shortage Threshold (Image 3 Configuration)",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Adjust the threshold to customize the Attendance Alert card and filter students below this percentage",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD97706)),
                ),
                child: Text(
                  "< ${_shortageThreshold.toInt()}%",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD97706)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("Threshold: ", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(
                "${_shortageThreshold.toInt()}%",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 14),
              ),
              Expanded(
                child: Slider(
                  value: _shortageThreshold,
                  min: 50.0,
                  max: 90.0,
                  divisions: 8,
                  activeColor: const Color(0xFFD97706),
                  label: "${_shortageThreshold.toInt()}%",
                  onChanged: (val) {
                    setState(() => _shortageThreshold = val);
                  },
                  onChangeEnd: (_) => _fetchReport(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Quick Presets:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
              ...[60.0, 65.0, 70.0, 75.0, 80.0, 85.0].map((t) {
                final isCurrent = _shortageThreshold.toInt() == t.toInt();
                return ChoiceChip(
                  label: Text("${t.toInt()}%"),
                  selected: isCurrent,
                  selectedColor: const Color(0xFFD97706),
                  labelStyle: TextStyle(
                    color: isCurrent ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _shortageThreshold = t);
                      _fetchReport();
                    }
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Subject Filter Dropdown
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              value: _selectedSubjectId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Assigned Subject',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.book_outlined, size: 18),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Assigned Subjects'),
                ),
                ..._assignedSubjects.map((sub) {
                  final idStr = (sub['id'] ?? sub['subject_id'] ?? '').toString();
                  final code = sub['code'] ?? sub['subject_code'] ?? '';
                  final name = sub['name'] ?? sub['subject_name'] ?? 'Subject';
                  return DropdownMenuItem<String>(
                    value: idStr,
                    child: Text(
                      code.isNotEmpty ? '$code - $name' : name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedSubjectId = val);
                _fetchReport();
              },
            ),
          ),

          // Semester Filter Dropdown
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              value: _selectedSemesterId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Semester',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Semesters'),
                ),
                ..._semesters.map((sem) {
                  final idStr = (sem['id'] ?? '').toString();
                  final num = sem['sem_number'] ?? sem['number'] ?? '';
                  return DropdownMenuItem<String>(
                    value: idStr,
                    child: Text('Semester $num'),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedSemesterId = val);
                _fetchReport();
              },
            ),
          ),

          // Search Field
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search USN or Name',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchReport();
                        },
                      )
                    : null,
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _fetchReport();
              },
            ),
          ),

          // Refresh / Apply Button
          ElevatedButton.icon(
            onPressed: _fetchReport,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Apply Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    final card1Label = _summary['card1_label'] ?? 'Records';
    final card1Val = _summary['card1_value']?.toString() ?? '0';

    final card2Label = _summary['card2_label'] ?? 'Average';
    final card2Val = _summary['card2_value']?.toString() ?? '0%';

    final card3Label = _summary['card3_label'] ?? 'Eligible / Passed';
    final card3Val = _summary['card3_value']?.toString() ?? '0';

    final card4Label = _summary['card4_label'] ?? 'Alerts';
    final card4Val = _summary['card4_value']?.toString() ?? '0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(card1Label, card1Val, Icons.storage_rounded, const Color(0xFF13246E), cardWidth, isDark),
            _buildStatCard(card2Label, card2Val, Icons.analytics_outlined, const Color(0xFF0D9488), cardWidth, isDark),
            _buildStatCard(card3Label, card3Val, Icons.check_circle_outline, const Color(0xFF16A34A), cardWidth, isDark),
            _buildStatCard(card4Label, card4Val, Icons.warning_amber_rounded, const Color(0xFFDC2626), cardWidth, isDark),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, double width, bool isDark) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTableCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reportTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total records: ${_rows.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportCSV,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchReport,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No matching records found.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try adjusting your subject or semester filters.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Builder(
              builder: (context) {
                final int totalItems = _rows.length;
                final int totalPages = (totalItems / _pageSize).ceil();
                final int safePage = _currentPage.clamp(1, math.max(1, totalPages));
                final int startIndex = (safePage - 1) * _pageSize;
                final paginatedRows = _rows.skip(startIndex).take(_pageSize).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        ),
                        columns: _columns.map((col) {
                          return DataColumn(
                            label: Text(
                              col,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          );
                        }).toList(),
                        rows: paginatedRows.map((row) {
                          final values = row.values.toList();
                          return DataRow(
                            cells: values.map((val) {
                              final strVal = val?.toString() ?? '-';
                              return DataCell(_buildTableCellWidget(strVal, isDark));
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppPaginationBar(
                      currentPage: safePage,
                      totalPages: totalPages,
                      totalItems: totalItems,
                      pageSize: _pageSize,
                      onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTableCellWidget(String value, bool isDark) {
    final lower = value.toLowerCase();

    // Attendance badges
    if (lower.contains('shortage') || lower.contains('<75%')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (lower.contains('eligible') || lower.contains('>=75%')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFF16A34A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // IA result badges
    if (lower.contains('needs support') || lower.contains('<40%')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD97706),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (lower == 'pass') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Pass',
          style: TextStyle(
            color: Color(0xFF16A34A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Text(
      value,
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
    );
  }
}
