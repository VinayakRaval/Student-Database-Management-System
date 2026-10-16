import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/network/api_client.dart';

class HODReportsScreen extends StatefulWidget {
  const HODReportsScreen({super.key});

  @override
  State<HODReportsScreen> createState() => _HODReportsScreenState();
}

class _HODReportsScreenState extends State<HODReportsScreen> {
  String _selectedReportType = 'STUDENTS';
  String? _selectedSemester;
  String? _selectedAcademicYear;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _academicYears = [];

  bool _isLoadingFilters = true;
  bool _isLoadingReport = false;
  String? _errorMessage;

  String _reportTitle = 'Department Student Report';
  List<String> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _deptInfo = {};

  final List<Map<String, String>> _reportTypes = const [
    {'type': 'STUDENTS', 'title': 'Department Student Report', 'icon': 'people'},
    {'type': 'FACULTY_WORKLOAD', 'title': 'Faculty Workload Report', 'icon': 'work'},
    {'type': 'ATTENDANCE', 'title': 'Attendance Report', 'icon': 'fact_check'},
    {'type': 'IA_PERFORMANCE', 'title': 'IA Performance Report', 'icon': 'grade'},
    {'type': 'TIMETABLE', 'title': 'Subject & Timetable Report', 'icon': 'calendar_month'},
    {'type': 'PROGRESSION', 'title': 'Semester Progression Report', 'icon': 'trending_up'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFiltersAndInitialReport();
  }

  Future<void> _loadFiltersAndInitialReport() async {
    setState(() => _isLoadingFilters = true);
    try {
      final dio = ApiClient().dio;
      final semRes = await dio.get('/academics/semesters/');
      final ayRes = await dio.get('/academics/academic-years/');

      final semData = semRes.data is List ? semRes.data : (semRes.data['results'] ?? []);
      final ayData = ayRes.data is List ? ayRes.data : (ayRes.data['results'] ?? []);

      if (mounted) {
        setState(() {
          _semesters = List<Map<String, dynamic>>.from(semData);
          _academicYears = List<Map<String, dynamic>>.from(ayData);
          _isLoadingFilters = false;
        });
        _loadReportData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFilters = false);
        _loadReportData();
      }
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoadingReport = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{
        'report_type': _selectedReportType,
      };
      if (_selectedSemester != null && _selectedSemester!.isNotEmpty) {
        queryParams['semester_id'] = _selectedSemester;
      }
      if (_selectedAcademicYear != null && _selectedAcademicYear!.isNotEmpty) {
        queryParams['academic_year_id'] = _selectedAcademicYear;
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['q'] = _searchQuery.trim();
      }
      if (_startDate != null) {
        queryParams['start_date'] = _startDate!.toIso8601String().split('T')[0];
      }
      if (_endDate != null) {
        queryParams['end_date'] = _endDate!.toIso8601String().split('T')[0];
      }

      final res = await dio.get('/academics/reports/department/', queryParameters: queryParams);
      if (mounted) {
        final List colData = res.data['columns'] ?? [];
        final List rowData = res.data['rows'] ?? [];
        setState(() {
          _reportTitle = res.data['title'] ?? 'Report';
          _columns = colData.map((c) => c.toString()).toList();
          _rows = rowData.map((r) => Map<String, dynamic>.from(r as Map)).toList();
          _summary = Map<String, dynamic>.from(res.data['summary'] ?? {});
          _deptInfo = Map<String, dynamic>.from(res.data['department_info'] ?? {});
          _isLoadingReport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to generate report. Please check filters and retry.";
          _isLoadingReport = false;
        });
      }
    }
  }

  void _exportCSV() {
    if (_rows.isEmpty || _columns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No report rows to export.")),
      );
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln('"$_reportTitle - ${_deptInfo['name'] ?? 'Department'}"');
    csv.writeln(_columns.map((c) => '"$c"').join(','));

    for (var r in _rows) {
      final rowVals = r.values.map((v) => '"${v.toString().replaceAll('"', '""')}"').join(',');
      csv.writeln(rowVals);
    }

    Clipboard.setData(ClipboardData(text: csv.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$_reportTitle exported to clipboard in CSV format (${_rows.length} rows)!"),
        backgroundColor: const Color(0xFF13246E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFilters) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Role detection
    final roleTag = (_deptInfo['user_role'] ?? '').toString().toUpperCase() == 'PRINCIPAL'
        ? 'CAMPUS ADMINISTRATION'
        : 'HEAD OF DEPARTMENT';
    final deptName = _deptInfo['name'] ?? 'Department of Computer Science';
    final userEmail = _deptInfo['user_email'] ?? 'hod@department.college.edu';

    // Image 2 Statistics cards data
    final card1Label = _summary['card1_label']?.toString() ?? 'Total Count';
    final card1Value = _summary['card1_value']?.toString() ?? '${_rows.length}';
    final card2Label = _summary['card2_label']?.toString() ?? 'Primary Metric';
    final card2Value = _summary['card2_value']?.toString() ?? '—';
    final card3Label = _summary['card3_label']?.toString() ?? 'Secondary Metric';
    final card3Value = _summary['card3_value']?.toString() ?? '—';
    final card4Label = _summary['card4_label']?.toString() ?? 'Attention Metric';
    final card4Value = _summary['card4_value']?.toString() ?? '—';

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
                    Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      "Department Reports Dashboard",
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
                  onPressed: _loadReportData,
                  tooltip: "Refresh Report Data",
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // Main Scrollable Area
          Expanded(
            child: SingleChildScrollView(
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
                              title: card1Label,
                              value: card1Value,
                              icon: Icons.people_alt_rounded,
                              iconColor: const Color(0xFF13246E),
                              iconBg: const Color(0xFFEEF2FF),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildImage2KPICard(
                              title: card2Label,
                              value: card2Value,
                              icon: Icons.task_alt_rounded,
                              iconColor: const Color(0xFF0D9488),
                              iconBg: const Color(0xFFCCFBF1),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildImage2KPICard(
                              title: card3Label,
                              value: card3Value,
                              icon: Icons.insights_rounded,
                              iconColor: const Color(0xFFEA580C),
                              iconBg: const Color(0xFFFFEDD5),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildImage2KPICard(
                              title: card4Label,
                              value: card4Value,
                              icon: Icons.warning_amber_rounded,
                              iconColor: const Color(0xFFDC2626),
                              iconBg: const Color(0xFFFEE2E2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // 5. Controls Toolbar & Table Card
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
                        // Report Type Selector Chips
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Select Report",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _reportTypes.map((rt) {
                                  final isSelected = _selectedReportType == rt['type'];
                                  return ChoiceChip(
                                    label: Text(rt['title']!),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF13246E),
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _selectedReportType = rt['type']!);
                                        _loadReportData();
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // Filters Toolbar
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
                                    hintText: "Search USN, name, subject...",
                                    hintStyle: const TextStyle(fontSize: 13),
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                  ),
                                  onSubmitted: (val) {
                                    setState(() => _searchQuery = val);
                                    _loadReportData();
                                  },
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
                                      ..._semesters.map((s) => DropdownMenuItem(
                                            value: s['id'].toString(),
                                            child: Text("Semester ${s['sem_number']}"),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedSemester = val);
                                      _loadReportData();
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
                                            child: Text(ay['year_name'] ?? 'Year'),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedAcademicYear = val);
                                      _loadReportData();
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
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF13246E),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Printing '$_reportTitle' (${_rows.length} rows) ready!"),
                                      backgroundColor: const Color(0xFF13246E),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.print_rounded, size: 18),
                                label: const Text("Print"),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // Table or Empty / Loading State
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _isLoadingReport
                              ? const SizedBox(
                                  height: 250,
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : _errorMessage != null
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                                      ),
                                    )
                                  : _rows.isEmpty
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(40),
                                            child: Text("No records match the selected report criteria."),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                            columns: _columns.map((col) => DataColumn(
                                              label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            )).toList(),
                                            rows: _rows.map((row) {
                                              return DataRow(
                                                cells: _columns.map((col) {
                                                  final key = _findKeyForColumn(col, row);
                                                  final val = row[key]?.toString() ?? '—';
                                                  final isEligible = val.contains("Eligible");
                                                  final isShortage = val.contains("Shortage") || val.contains("Support") || val.contains("Review");

                                                  if (isEligible || isShortage) {
                                                    return DataCell(
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: (isEligible ? Colors.green : Colors.red).withOpacity(0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          val,
                                                          style: TextStyle(
                                                            color: isEligible ? Colors.green.shade800 : Colors.red.shade800,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  return DataCell(Text(val));
                                                }).toList(),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _findKeyForColumn(String column, Map<String, dynamic> row) {
    final lowerCol = column.toLowerCase().replaceAll(' ', '_');
    for (var k in row.keys) {
      if (k.toLowerCase() == lowerCol || k.toLowerCase().contains(lowerCol) || lowerCol.contains(k.toLowerCase())) {
        return k;
      }
    }
    final colTokens = lowerCol.split('_');
    for (var k in row.keys) {
      if (colTokens.any((t) => k.toLowerCase().contains(t))) {
        return k;
      }
    }
    return row.keys.first;
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
}
