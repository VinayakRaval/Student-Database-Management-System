import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';

class StudentAcademicHistoryScreen extends ConsumerStatefulWidget {
  final String? initialSearch;

  const StudentAcademicHistoryScreen({super.key, this.initialSearch});

  @override
  ConsumerState<StudentAcademicHistoryScreen> createState() =>
      _StudentAcademicHistoryScreenState();
}

class _StudentAcademicHistoryScreenState
    extends ConsumerState<StudentAcademicHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _academicYears = [];

  // Filters
  String? _selectedAcademicYear;
  String? _selectedSemester;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Selected student for detailed dossier view
  int? _selectedStudentId;
  Map<String, dynamic>? _studentDossier;
  bool _isLoadingDossier = false;

  // Selected semester number (1 to 8)
  int _selectedSemesterNumber = 1;

  // Avatar palette for student list items
  static const List<Map<String, Color>> _avatarPalettes = [
    {'bg': Color(0xFFEEF2FF), 'fg': Color(0xFF4338CA)}, // Indigo
    {'bg': Color(0xFFECFDF5), 'fg': Color(0xFF059669)}, // Emerald
    {'bg': Color(0xFFF0FDF4), 'fg': Color(0xFF16A34A)}, // Green
    {'bg': Color(0xFFF0FDFA), 'fg': Color(0xFF0D9488)}, // Teal
    {'bg': Color(0xFFF5F3FF), 'fg': Color(0xFF7C3AED)}, // Purple
    {'bg': Color(0xFFFAF5FF), 'fg': Color(0xFF9333EA)}, // Fuchsia
    {'bg': Color(0xFFFFF7ED), 'fg': Color(0xFFEA580C)}, // Orange
    {'bg': Color(0xFFFEF2F2), 'fg': Color(0xFFDC2626)}, // Red
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchQuery = widget.initialSearch!;
      _searchCtrl.text = widget.initialSearch!;
    }
    _loadAcademicYears();
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicYears() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/academics/academic-years/');
      if (res.data is List && mounted) {
        setState(() {
          _academicYears = (res.data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{};
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }
      if (_selectedAcademicYear != null && _selectedAcademicYear!.isNotEmpty) {
        queryParams['academic_year'] = _selectedAcademicYear;
      }
      if (_selectedSemester != null && _selectedSemester!.isNotEmpty) {
        queryParams['semester'] = _selectedSemester;
      }
      if (_selectedStatus != 'ALL') {
        queryParams['status'] = _selectedStatus.toLowerCase();
      }

      final res = await dio.get(
        '/students/academic-history/',
        queryParameters: queryParams,
      );

      final List raw = res.data is List ? res.data : [];
      final students =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });

        // Auto-select first student if available and none selected
        if (_selectedStudentId == null && students.isNotEmpty) {
          _fetchStudentDossier(students.first['id'] as int);
        } else if (_selectedStudentId != null) {
          final exists = students.any((s) => s['id'] == _selectedStudentId);
          if (!exists && students.isNotEmpty) {
            _fetchStudentDossier(students.first['id'] as int);
          } else if (!exists) {
            setState(() {
              _selectedStudentId = null;
              _studentDossier = null;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load student history records: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchStudentDossier(int studentId) async {
    setState(() {
      _selectedStudentId = studentId;
      _isLoadingDossier = true;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/students/$studentId/academic-history/');
      if (mounted) {
        final data = Map<String, dynamic>.from(res.data as Map);
        final student = data['student'] as Map<String, dynamic>? ?? {};
        int defaultSem = 1;
        final curSemNum = student['current_semester']?['sem_number'];
        if (curSemNum is int && curSemNum >= 1 && curSemNum <= 8) {
          defaultSem = curSemNum;
        } else {
          final sems = data['semesters'] as List?;
          if (sems != null && sems.isNotEmpty) {
            final lastNum = sems.last['semester_number'];
            if (lastNum is int && lastNum >= 1 && lastNum <= 8) {
              defaultSem = lastNum;
            }
          }
        }

        setState(() {
          _studentDossier = data;
          _selectedSemesterNumber = defaultSem;
          _isLoadingDossier = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDossier = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load student dossier: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  String _getAcademicYearForSemester(
    int semNum,
    Map<String, dynamic> student,
    List semesters,
  ) {
    for (final s in semesters) {
      if (s is Map && (s['semester_number'] ?? 0) == semNum) {
        final ay = s['academic_year']?.toString();
        if (ay != null && ay.isNotEmpty) return ay;
      }
    }

    // Determine baseline admission year
    int admYear = 2022;
    final usn = (student['usn'] ?? '').toString().toUpperCase();
    final usnMatch = RegExp(r'^[0-9][A-Z]{2}([0-9]{2})').firstMatch(usn);
    if (usnMatch != null) {
      final yrDigits = int.tryParse(usnMatch.group(1)!);
      if (yrDigits != null) {
        admYear = 2000 + yrDigits;
      }
    } else {
      final ayStr = student['academic_year']?['year_name']?.toString() ?? '';
      final yrMatch = RegExp(r'(\d{4})').firstMatch(ayStr);
      if (yrMatch != null) {
        final curYr = int.tryParse(yrMatch.group(1)!) ?? 2025;
        final int curSem = (student['current_semester']?['sem_number'] is num)
            ? (student['current_semester']['sem_number'] as num).toInt()
            : 7;
        admYear = curYr - ((curSem - 1) ~/ 2);
      }
    }

    final semYear = admYear + ((semNum - 1) ~/ 2);
    return "$semYear-${semYear + 1}";
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Page Header (Image 1 top style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Student Academic History",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13246E),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "View complete academic records across all semesters, promotions and graduation",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Refresh Records",
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF13246E)),
                    onPressed: () {
                      _fetchStudents();
                      if (_selectedStudentId != null) {
                        _fetchStudentDossier(_selectedStudentId!);
                      }
                    },
                  ),
                ],
              ),
            ),

            // Main Body: Split View or Mobile Layout
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF13246E)),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : isDesktop
                          ? _buildDesktopSplitLayout()
                          : _buildMobileLayout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E)),
            onPressed: _fetchStudents,
            child: const Text("Retry", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  DESKTOP SPLIT LAYOUT (Matches Image 1)
  // ==========================================
  Widget _buildDesktopSplitLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel: Search & Students List (Width ~340px)
          SizedBox(
            width: 340,
            child: _buildLeftStudentsPanel(),
          ),
          const SizedBox(width: 16),

          // Right Panel: Student Dossier Profile & Records
          Expanded(
            child: _isLoadingDossier
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF13246E)),
                  )
                : _studentDossier == null
                    ? _buildSelectPrompt()
                    : _buildRightDossierPanel(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  LEFT STUDENTS PANEL (Matches Image 1)
  // ==========================================
  Widget _buildLeftStudentsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // 1. Search Box
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: "Search USN, name, ID...",
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                        _fetchStudents();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),
              ),
            ),
            onSubmitted: (val) {
              setState(() => _searchQuery = val.trim());
              _fetchStudents();
            },
          ),
          const SizedBox(height: 10),

          // 2. All Academic Years Dropdown (Full width)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAcademicYear,
                isExpanded: true,
                hint: const Text("All Academic Years", style: TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                items: [
                  const DropdownMenuItem(value: null, child: Text("All Academic Years", style: TextStyle(fontSize: 13))),
                  ..._academicYears.map((ay) {
                    final yr = (ay['year_name'] ?? '').toString();
                    return DropdownMenuItem(value: yr, child: Text(yr, style: const TextStyle(fontSize: 13)));
                  }),
                ],
                onChanged: (val) {
                  setState(() => _selectedAcademicYear = val);
                  _fetchStudents();
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Side-by-side dropdowns: All Semesters & All Statuses
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSemester,
                      isExpanded: true,
                      hint: const Text("All Semesters", style: TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("All Semesters", style: TextStyle(fontSize: 12))),
                        for (int s = 1; s <= 8; s++)
                          DropdownMenuItem(value: "$s", child: Text("Sem $s", style: const TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSemester = val);
                        _fetchStudents();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text("All Statuses", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'ACTIVE', child: Text("Active", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'PROMOTED', child: Text("Promoted", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'GRADUATED', child: Text("Graduated", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'PASSED_OUT', child: Text("Passed Out", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'INACTIVE', child: Text("Inactive", style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          _fetchStudents();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // 4. Student List (Image 1 style with colored circle avatar, name, USN, dept, status pill, chevron)
          Expanded(
            child: _students.isEmpty
                ? const Center(
                    child: Text(
                      "No students match the criteria",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: _students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final isSelected = student['id'] == _selectedStudentId;
                      final name = (student['name'] ?? 'Student').toString();
                      final usn = (student['usn'] ?? '').toString();
                      final sem = student['current_semester_number'] ?? student['semester'] ?? '';
                      final dept = student['department_code'] ?? student['department_name'] ?? 'CSE';
                      final status = (student['status'] ?? 'Active').toString().toUpperCase();

                      // Select color palette based on name/index
                      final palette = _avatarPalettes[index % _avatarPalettes.length];

                      // Status pill styling
                      Color statusBg = const Color(0xFFDCFCE7);
                      Color statusText = const Color(0xFF15803D);
                      if (status == 'PROMOTED') {
                        statusBg = const Color(0xFFDBEAFE);
                        statusText = const Color(0xFF1D4ED8);
                      } else if (status == 'GRADUATED' || status == 'PASSED_OUT' || status == 'PASSED OUT') {
                        statusBg = const Color(0xFFF3E8FF);
                        statusText = const Color(0xFF7E22CE);
                      } else if (status == 'INACTIVE' || status == 'LEFT') {
                        statusBg = const Color(0xFFF1F5F9);
                        statusText = const Color(0xFF64748B);
                      }

                      return InkWell(
                        onTap: () => _fetchStudentDossier(student['id'] as int),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: palette['bg'],
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: palette['fg'],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: statusBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: statusText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "USN: $usn",
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      "$dept • Sem $sem",
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  RIGHT DOSSIER PANEL (Matches Image 1)
  // ==========================================
  Widget _buildRightDossierPanel() {
    final dossier = _studentDossier!;
    final student = dossier['student'] as Map<String, dynamic>? ?? {};
    final summary = dossier['summary'] as Map<String, dynamic>? ?? {};
    final semesters = (dossier['semesters'] as List?) ?? [];

    final name = (student['name'] ?? 'Student').toString();
    final usn = (student['usn'] ?? 'N/A').toString();
    final admissionId = (student['admission_id'] ?? 'N/A').toString();
    final deptName = student['department']?['name'] ?? student['department_name'] ?? 'Computer Science and Engineering';
    final curSem = student['current_semester']?['sem_number'] ?? student['semester'] ?? 7;
    final curAy = student['academic_year']?['year_name'] ?? '2025-2026';
    final email = student['email'] ?? 'student@campusflow.edu';
    final seatType = (student['seat_type'] ?? 'GOVERNMENT').toString().toUpperCase();
    final status = (student['status'] ?? 'Active').toString().toUpperCase();

    // Baseline admission year
    int admYear = 2022;
    final usnMatch = RegExp(r'^[0-9][A-Z]{2}([0-9]{2})').firstMatch(usn.toUpperCase());
    if (usnMatch != null) {
      final yrDigits = int.tryParse(usnMatch.group(1)!);
      if (yrDigits != null) admYear = 2000 + yrDigits;
    } else {
      final yrMatch = RegExp(r'(\d{4})').firstMatch(curAy.toString());
      if (yrMatch != null) {
        final curYr = int.tryParse(yrMatch.group(1)!) ?? 2025;
        final int curSemInt = curSem is int ? curSem : 7;
        admYear = curYr - ((curSemInt - 1) ~/ 2);
      }
    }
    final gradYear = admYear + 4;

    // Filter current semester data for 2x2 grid
    Map<String, dynamic>? semData;
    for (final s in semesters) {
      if (s is Map && (s['semester_number'] ?? 0) == _selectedSemesterNumber) {
        semData = Map<String, dynamic>.from(s);
        break;
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Profile Header Card (Matches Image 1)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Big Circular Avatar with Initial Letter
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFEEF2F6),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF13246E),
                    ),
                  ),
                ),
                const SizedBox(width: 18),

                // Student Identity Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: "USN: "),
                                TextSpan(
                                  text: usn,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: "Admission ID: "),
                                TextSpan(
                                  text: admissionId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          children: [
                            const TextSpan(text: "Department: "),
                            TextSpan(
                              text: "$deptName",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: "Current Semester: "),
                                TextSpan(
                                  text: "Sem $curSem ($curAy)",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: "Academic Year: "),
                                TextSpan(
                                  text: "$curAy",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: "Email: "),
                                TextSpan(
                                  text: email,
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: "Seat Type: "),
                                TextSpan(
                                  text: seatType,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Right 2x2 Mini Stats Block
                Container(
                  padding: const EdgeInsets.only(left: 20),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildProfileStatBox(
                            icon: Icons.people_alt_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: "Total Semesters",
                            value: "${semesters.length} On File",
                          ),
                          const SizedBox(width: 24),
                          _buildProfileStatBox(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF16A34A),
                            title: "Current Status",
                            value: "Active Student",
                            valueColor: const Color(0xFF16A34A),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildProfileStatBox(
                            icon: Icons.calendar_today_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: "Year of Admission",
                            value: "$admYear",
                          ),
                          const SizedBox(width: 24),
                          _buildProfileStatBox(
                            icon: Icons.school_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: "Expected Graduation",
                            value: "$gradYear",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. 6 Metric Boxes Row (Matches Image 1)
          _buildSixMetricBoxes(summary, semesters),
          const SizedBox(height: 18),

          // 3. Exactly 8 Semester Buttons Row (User requested: only add 8 semester button)
          _buildEightSemesterButtons(student, semesters),
          const SizedBox(height: 18),

          // 4. 2x2 Grid of Academic Record Cards (Attendance, IA Marks, VTU Results, Fees)
          _buildRecordCardsGrid(semData),
        ],
      ),
    );
  }

  Widget _buildProfileStatBox({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  //  6 METRIC BOXES ROW (Matches Image 1)
  // ==========================================
  Widget _buildSixMetricBoxes(Map<String, dynamic> summary, List semesters) {
    final semCount = summary['total_semesters_completed'] ?? semesters.length;
    final overallAtt = summary['overall_attendance_pct'];
    final cgpa = summary['cgpa'];
    final credits = summary['total_credits_cleared'] ?? 0;
    final backlogs = summary['active_backlogs'] ?? 0;
    final books = summary['library_books_borrowed'] ?? 0;

    return Row(
      children: [
        // 1. Semesters Archived (Blue)
        Expanded(
          child: _buildMetricBox(
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF1D4ED8),
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFDBEAFE),
            value: "$semCount",
            label: "Semesters Archived",
          ),
        ),
        const SizedBox(width: 10),

        // 2. Overall Attendance (Orange)
        Expanded(
          child: _buildMetricBox(
            icon: Icons.assignment_turned_in_rounded,
            iconColor: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFF7ED),
            borderColor: const Color(0xFFFFEDD5),
            value: overallAtt != null ? "$overallAtt%" : "N/A",
            label: "Overall Attendance",
          ),
        ),
        const SizedBox(width: 10),

        // 3. Cumulative CGPA (Sky Blue)
        Expanded(
          child: _buildMetricBox(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFF0F9FF),
            borderColor: const Color(0xFFE0F2FE),
            value: cgpa != null ? "$cgpa" : "N/A",
            label: "Cumulative CGPA",
          ),
        ),
        const SizedBox(width: 10),

        // 4. Credits Cleared (Green)
        Expanded(
          child: _buildMetricBox(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFDCFCE7),
            value: "$credits",
            label: "Credits Cleared",
          ),
        ),
        const SizedBox(width: 10),

        // 5. Active Backlogs (Amber)
        Expanded(
          child: _buildMetricBox(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFCA8A04),
            bgColor: const Color(0xFFFEFCE8),
            borderColor: const Color(0xFFFEF08A),
            value: "$backlogs",
            label: "Active Backlogs",
          ),
        ),
        const SizedBox(width: 10),

        // 6. Library Books (Purple)
        Expanded(
          child: _buildMetricBox(
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF9333EA),
            bgColor: const Color(0xFFFAF5FF),
            borderColor: const Color(0xFFF3E8FF),
            value: "$books",
            label: "Library Books",
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  EXACTLY 8 SEMESTER BUTTONS (Image 1 Style)
  // ==========================================
  Widget _buildEightSemesterButtons(Map<String, dynamic> student, List semesters) {
    return Row(
      children: List.generate(8, (i) {
        final semNum = i + 1;
        final isSelected = semNum == _selectedSemesterNumber;
        final yearStr = _getAcademicYearForSemester(semNum, student, semesters);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 7 ? 8.0 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedSemesterNumber = semNum),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF13246E) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF13246E) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Semester $semNum",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      yearStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ==========================================
  //  2x2 GRID OF RECORD CARDS (Image 1 Style)
  // ==========================================
  Widget _buildRecordCardsGrid(Map<String, dynamic>? semData) {
    final att = semData?['attendance'] as Map<String, dynamic>?;
    final ia = semData?['ia_marks'] as Map<String, dynamic>?;
    final results = semData?['results'] as Map<String, dynamic>?;
    final fees = semData?['fees'] as Map<String, dynamic>?;

    return Column(
      children: [
        // Row 1: Attendance Records & Internal Assessment (IA Marks)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRecordCard(
                icon: Icons.assignment_outlined,
                title: "Attendance Records",
                hasData: att != null && (att['subjects'] as List? ?? []).isNotEmpty,
                emptyIcon: Icons.description_outlined,
                emptyText: "No attendance sessions recorded for this semester yet.",
                onViewDetails: () => _showAttendanceDetailsModal(att),
                content: _buildAttendanceCardContent(att),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRecordCard(
                icon: Icons.bar_chart_rounded,
                title: "Internal Assessment (IA Marks)",
                hasData: ia != null && (ia['subjects'] as List? ?? []).isNotEmpty,
                emptyIcon: Icons.bar_chart_outlined,
                emptyText: "No IA marks recorded for this semester yet.",
                onViewDetails: () => _showIADetailsModal(ia),
                content: _buildIACardContent(ia),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row 2: Semester Examination & VTU Results & Fee Structure
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRecordCard(
                icon: Icons.military_tech_outlined,
                title: "Semester Examination & VTU Results",
                hasData: results != null && results['sgpa'] != null,
                emptyIcon: Icons.military_tech_outlined,
                emptyText: "No external VTU exam result uploaded for this semester.",
                onViewDetails: () => _showResultsDetailsModal(results),
                content: _buildResultsCardContent(results),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRecordCard(
                icon: Icons.receipt_long_outlined,
                title: "Fee Structure & Payment Receipts",
                hasData: fees != null && (fees['fee_structures'] as List? ?? []).isNotEmpty,
                emptyIcon: Icons.receipt_outlined,
                emptyText: "No fee records registered for this semester.",
                onViewDetails: () => _showFeesDetailsModal(fees),
                content: _buildFeesCardContent(fees),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordCard({
    required IconData icon,
    required String title,
    required bool hasData,
    required IconData emptyIcon,
    required String emptyText,
    required VoidCallback onViewDetails,
    required Widget content,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon, Title, View Details Link
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: const Color(0xFF13246E), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              InkWell(
                onTap: onViewDetails,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "View Details >",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Body: Either Empty State or Populated Content
          if (!hasData)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(emptyIcon, color: const Color(0xFF94A3B8), size: 38),
                  const SizedBox(height: 10),
                  Text(
                    emptyText,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            content,
        ],
      ),
    );
  }

  // --- Card Content: Attendance ---
  Widget _buildAttendanceCardContent(Map<String, dynamic>? att) {
    if (att == null) return const SizedBox.shrink();
    final pct = att['percentage'];
    final tot = att['total_classes'] ?? 0;
    final attd = att['attended_classes'] ?? 0;
    final subjects = (att['subjects'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "$pct% Overall Attendance",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: (pct != null && pct >= 75) ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                ),
              ),
            ),
            Text(
              "$attd / $tot Classes Attended",
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: tot > 0 ? (attd / tot) : 0,
          backgroundColor: const Color(0xFFE2E8F0),
          color: (pct != null && pct >= 75) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),
        Text(
          "${subjects.length} subjects recorded this semester. Tap 'View Details >' for full subject breakdown.",
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // --- Card Content: IA Marks ---
  Widget _buildIACardContent(Map<String, dynamic>? ia) {
    if (ia == null) return const SizedBox.shrink();
    final subjects = (ia['subjects'] as List?) ?? [];
    final totalObtained = ia['total_obtained'];
    final totalMax = ia['total_max'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalMax != null && totalMax > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Marks: $totalObtained / $totalMax",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
              ),
              Text(
                "${subjects.length} Subjects Evaluated",
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        const SizedBox(height: 10),
        ...subjects.take(2).map((s) {
          final code = s['subject_code'] ?? '';
          final name = s['subject_name'] ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text("$code - $name", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- Card Content: Examination Results ---
  Widget _buildResultsCardContent(Map<String, dynamic>? results) {
    if (results == null) return const SizedBox.shrink();
    final sgpa = results['sgpa'];
    final credits = results['credits_cleared'] ?? 0;
    final backlogs = results['backlogs_count'] ?? 0;
    final status = results['status'] ?? 'PASS';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            const Text("SGPA", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text("$sgpa", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
          ],
        ),
        Column(
          children: [
            const Text("Credits", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text("$credits", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
          ],
        ),
        Column(
          children: [
            const Text("Backlogs", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text("$backlogs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: backlogs == 0 ? const Color(0xFF16A34A) : Colors.red)),
          ],
        ),
        Column(
          children: [
            const Text("Status", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text("$status", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
          ],
        ),
      ],
    );
  }

  // --- Card Content: Fee Structure ---
  Widget _buildFeesCardContent(Map<String, dynamic>? fees) {
    if (fees == null) return const SizedBox.shrink();
    final feeList = (fees['fee_structures'] as List?) ?? [];
    if (feeList.isEmpty) return const SizedBox.shrink();
    final f = feeList.first;
    final title = f['title'] ?? 'Semester Fee';
    final total = f['total_amount'] ?? 0;
    final paid = f['paid_amount'] ?? 0;
    final bal = f['balance_amount'] ?? 0;
    final st = f['status'] ?? 'Paid';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bal == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                st,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: bal == 0 ? const Color(0xFF15803D) : const Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text("Total: ₹$total  •  Paid: ₹$paid  •  Balance: ₹$bal", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  // ==========================================
  //  MODAL DETAILS DIALOGS
  // ==========================================
  void _showAttendanceDetailsModal(Map<String, dynamic>? att) {
    final subjects = (att?['subjects'] as List?) ?? [];
    final logs = (att?['recent_logs'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.fact_check_rounded, color: Color(0xFF13246E)),
            const SizedBox(width: 10),
            Text("Semester $_selectedSemesterNumber Attendance Breakdown"),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subjects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text("No attendance sessions recorded for this semester.")),
                  )
                else ...[
                  const Text("Subject Attendance Summary:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: [
                          Padding(padding: EdgeInsets.all(8), child: Text("Code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text("Subject Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text("Attended/Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text("Percentage", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      ...subjects.map((s) {
                        final code = s['subject_code'] ?? '';
                        final name = s['subject_name'] ?? '';
                        final total = s['total'] ?? 0;
                        final attended = s['attended'] ?? 0;
                        final pct = s['percentage'] ?? 0;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(code, style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(name, style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text("$attended / $total", style: const TextStyle(fontSize: 12))),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                "$pct%",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: pct >= 75 ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
                if (logs.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text("Recent Session Logs:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...logs.take(10).map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          "${l['date']} • ${l['subject_code']} • ${l['status']}",
                          style: TextStyle(
                            fontSize: 12,
                            color: l['status'] == 'Present' ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  void _showIADetailsModal(Map<String, dynamic>? ia) {
    final subjects = (ia?['subjects'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: Color(0xFF13246E)),
            const SizedBox(width: 10),
            Text("Semester $_selectedSemesterNumber IA Marks Breakdown"),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: subjects.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text("No IA marks recorded for this semester.")),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: subjects.map<Widget>((s) {
                      final code = s['subject_code'] ?? '';
                      final name = s['subject_name'] ?? '';
                      final tests = (s['tests'] as List?) ?? [];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("$code - $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 6),
                              ...tests.map((t) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("${t['ia_name'] ?? t['ia_type']}:", style: const TextStyle(fontSize: 12)),
                                        Text("${t['obtained_marks']} / ${t['max_marks']} (${t['percentage']}%)",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  void _showResultsDetailsModal(Map<String, dynamic>? results) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.military_tech_rounded, color: Color(0xFF13246E)),
            const SizedBox(width: 10),
            Text("Semester $_selectedSemesterNumber VTU Examination Result"),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: results == null || results['sgpa'] == null
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text("No external VTU exam result uploaded for this semester.")),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.school, color: Color(0xFF13246E)),
                      title: const Text("SGPA / Semester Grade"),
                      trailing: Text("${results['sgpa']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                    ),
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: const Text("Credits Cleared"),
                      trailing: Text("${results['credits_cleared'] ?? 0}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      title: const Text("Active Backlogs"),
                      trailing: Text("${results['backlogs_count'] ?? 0}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.verified, color: Colors.blue),
                      title: const Text("Result Status"),
                      trailing: Text("${results['status'] ?? 'PASS'}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  void _showFeesDetailsModal(Map<String, dynamic>? fees) {
    final structures = (fees?['fee_structures'] as List?) ?? [];
    final payments = (fees?['payments'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF13246E)),
            const SizedBox(width: 10),
            Text("Semester $_selectedSemesterNumber Fee & Payment Receipts"),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (structures.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text("No fee records registered for this semester.")),
                  )
                else ...[
                  const Text("Fee Structures:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...structures.map((s) => Card(
                        child: ListTile(
                          title: Text("${s['title']}"),
                          subtitle: Text("Total: ₹${s['total_amount']}  •  Paid: ₹${s['paid_amount']}  •  Balance: ₹${s['balance_amount']}"),
                          trailing: Chip(label: Text("${s['status']}")),
                        ),
                      )),
                ],
                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text("Payment Receipts:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...payments.map((p) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.receipt, color: Color(0xFF13246E)),
                        title: Text("₹${p['amount']} via ${p['mode']}"),
                        subtitle: Text("Ref: ${p['reference_no'] ?? p['upi_txn_id'] ?? 'N/A'} • ${p['paid_on'] ?? ''}"),
                        trailing: Icon(p['verified'] == true ? Icons.verified : Icons.pending, color: p['verified'] == true ? Colors.green : Colors.amber, size: 18),
                      )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  // --- Empty Prompt when no student is selected ---
  Widget _buildSelectPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_search_rounded, size: 64, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text(
            "Select a student to view academic dossier",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 4),
          Text(
            "Historical marks, attendance, IA, and VTU records will appear here.",
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // --- Mobile Layout ---
  Widget _buildMobileLayout() {
    if (_selectedStudentId != null && _studentDossier != null) {
      return Column(
        children: [
          Container(
            color: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedStudentId = null),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Back to Student List",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildRightDossierPanel(),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: _buildLeftStudentsPanel(),
    );
  }
}
