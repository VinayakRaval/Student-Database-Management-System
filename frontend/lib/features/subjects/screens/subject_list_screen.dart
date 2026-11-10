import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart' as p;

class SubjectSimple {
  final int id;
  final String name;
  final String code;
  final String semester;
  final String? department;
  final bool isElective;
  final bool isAssignedToMe;
  final String? academicYear;
  final bool hasTheory;
  final bool hasLab;
  final String subjectType;
  final int credits;
  final int theoryHours;
  final int tutorialHours;
  final int practicalHours;
  final String practicalDisplay;
  final int totalTeachingHours;
  final String? assignedFacultyName;
  final bool isAssigned;

  SubjectSimple({
    required this.id,
    required this.name,
    required this.code,
    required this.semester,
    this.department,
    this.isElective = false,
    this.isAssignedToMe = true,
    this.academicYear,
    this.hasTheory = true,
    this.hasLab = false,
    this.subjectType = 'THEORY',
    this.credits = 4,
    this.theoryHours = 3,
    this.tutorialHours = 0,
    this.practicalHours = 0,
    this.practicalDisplay = '0',
    this.totalTeachingHours = 3,
    this.assignedFacultyName,
    this.isAssigned = false,
  });

  factory SubjectSimple.fromJson(Map<String, dynamic> json) {
    final bool rawHasTheory = json['has_theory'] ?? (json['subject_type'] == 'LAB' ? false : true);
    final bool rawHasLab = json['has_lab'] ?? (json['subject_type'] == 'LAB' || json['subject_type'] == 'BOTH');
    final String type = json['subject_type']?.toString().toUpperCase() ??
        (rawHasLab && rawHasTheory ? 'BOTH' : (rawHasLab ? 'LAB' : 'THEORY'));

    return SubjectSimple(
      id: json['subject_id'] ?? json['id'] ?? 0,
      name: json['subject_name'] ?? json['name'] ?? 'Unknown Subject',
      code: json['subject_code'] ?? json['code'] ?? '',
      semester: (json['semester_no'] ?? json['semester'] ?? json['semester_id'] ?? '').toString(),
      department: json['department_name']?.toString() ?? json['department']?.toString(),
      isElective: json['is_elective'] == true,
      isAssignedToMe: json['is_assigned_to_me'] != false,
      academicYear: json['academic_year']?.toString(),
      hasTheory: rawHasTheory,
      hasLab: rawHasLab,
      subjectType: type,
      credits: json['credits'] is int ? json['credits'] : (int.tryParse(json['credits']?.toString() ?? '4') ?? 4),
      theoryHours: json['theory_hours'] is int ? json['theory_hours'] : (int.tryParse(json['theory_hours']?.toString() ?? '3') ?? 3),
      tutorialHours: json['tutorial_hours'] is int ? json['tutorial_hours'] : (int.tryParse(json['tutorial_hours']?.toString() ?? '0') ?? 0),
      practicalHours: json['practical_hours'] is int ? json['practical_hours'] : (int.tryParse(json['practical_hours']?.toString() ?? '0') ?? 0),
      practicalDisplay: json['practical_display']?.toString() ?? (json['practical_hours']?.toString() ?? '0'),
      totalTeachingHours: json['total_teaching_hours'] is int ? json['total_teaching_hours'] : (int.tryParse(json['total_teaching_hours']?.toString() ?? '3') ?? 3),
      assignedFacultyName: json['assigned_faculty_name']?.toString(),
      isAssigned: json['is_assigned'] == true,
    );
  }
}

class _PastelTheme {
  final Color bg;
  final Color border;
  final Color iconBg;
  final IconData icon;

  const _PastelTheme({
    required this.bg,
    required this.border,
    required this.iconBg,
    required this.icon,
  });
}

final List<_PastelTheme> _pastelThemes = const [
  _PastelTheme(
    bg: Color(0xFFEFF6FF), // Blue
    border: Color(0xFFBFDBFE),
    iconBg: Color(0xFF3B82F6),
    icon: Icons.menu_book_rounded,
  ),
  _PastelTheme(
    bg: Color(0xFFF0FDF4), // Green
    border: Color(0xFFBBF7D0),
    iconBg: Color(0xFF22C55E),
    icon: Icons.code_rounded,
  ),
  _PastelTheme(
    bg: Color(0xFFFFF7ED), // Orange
    border: Color(0xFFFED7AA),
    iconBg: Color(0xFFF97316),
    icon: Icons.hub_rounded,
  ),
  _PastelTheme(
    bg: Color(0xFFFAF5FF), // Purple
    border: Color(0xFFE9D5FF),
    iconBg: Color(0xFFA855F7),
    icon: Icons.psychology_rounded,
  ),
  _PastelTheme(
    bg: Color(0xFFFFF1F2), // Rose
    border: Color(0xFFFECDD3),
    iconBg: Color(0xFFF43F5E),
    icon: Icons.terminal_rounded,
  ),
  _PastelTheme(
    bg: Color(0xFFF0FDFA), // Teal
    border: Color(0xFF99F6E4),
    iconBg: Color(0xFF14B8A6),
    icon: Icons.devices_rounded,
  ),
];

class SubjectListScreen extends ConsumerStatefulWidget {
  final bool isDepartmentView;
  const SubjectListScreen({super.key, this.isDepartmentView = false});

  @override
  ConsumerState<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends ConsumerState<SubjectListScreen> {
  List<SubjectSimple> _subjects = [];
  List<Map<String, dynamic>> _academicYears = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedSemester;
  String? _selectedAcademicYear;
  final String _typeFilter = 'ALL'; // 'ALL', 'CORE', 'ELECTIVE'
  String? _viewMode; // 'ALL_DEPT' or 'MY_SUBJECTS'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubjects();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _availableSemesters => const ['1', '2', '3', '4', '5', '6', '7', '8'];

  List<SubjectSimple> get _filteredSubjects {
    final seenMasterIds = <int>{};
    return _subjects.where((s) {
      if (_selectedSemester != null && s.semester != _selectedSemester) {
        return false;
      }
      if (_selectedAcademicYear != null && s.academicYear != null && s.academicYear != _selectedAcademicYear) {
        return false;
      }
      // When All Academic Years is selected, show each unique Subject Master record only once
      if (_selectedAcademicYear == null) {
        if (seenMasterIds.contains(s.id)) {
          return false;
        }
        seenMasterIds.add(s.id);
      }
      if (_typeFilter == 'ELECTIVE' && !s.isElective) {
        return false;
      }
      if (_typeFilter == 'CORE' && s.isElective) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final name = s.name.toLowerCase();
        final code = s.code.toLowerCase();
        final dept = (s.department ?? '').toLowerCase();
        return name.contains(q) || code.contains(q) || dept.contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = p.Provider.of<AuthProvider>(context, listen: false);
      final role = (auth.role ?? '').toUpperCase();
      final isHod = role == AppRoles.hod;
      final isProf = role == AppRoles.professor || role == 'FACULTY';

      if (_viewMode == null) {
        if (widget.isDepartmentView && (isHod || (!isProf && !isHod))) {
          _viewMode = 'ALL_DEPT';
        } else {
          _viewMode = 'MY_SUBJECTS';
        }
      }
      if (isProf) {
        _viewMode = 'MY_SUBJECTS';
      }

      final dio = ApiClient().dio;

      // 1. Fetch academic years
      try {
        final ayRes = await dio.get('/academics/academic-years/');
        final List rawAy = ayRes.data is List ? ayRes.data : [];
        _academicYears = rawAy.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}

      dynamic response;
      final bool isDept = _viewMode == 'ALL_DEPT';
      final Map<String, dynamic> qParams = {};
      if (_selectedAcademicYear != null) {
        qParams['academic_year'] = _selectedAcademicYear;
      }
      if (isDept) {
        response = await dio.get('/subjects/getSubjects/', queryParameters: qParams);
      } else {
        response = await dio.get('/subjects/professor/subjects/', queryParameters: qParams);
      }

      List rawList = [];
      if (response.data is List) {
        rawList = response.data;
      } else if (response.data is Map && response.data['results'] is List) {
        rawList = response.data['results'];
      }

      final items = rawList.map((e) => SubjectSimple.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _subjects = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = (auth.role ?? '').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _buildBody(role),
    );
  }

  Widget _buildBody(String role) {
    final isHod = role == AppRoles.hod;
    final isHodOrAdmin = isHod || role == AppRoles.principal || role == AppRoles.system;
    final isDept = _viewMode == 'ALL_DEPT';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text("Error loading subjects: $_errorMessage", textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadSubjects,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredSubjects;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF13246E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF13246E).withValues(alpha: 0.2),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDept ? "Department Curriculum" : "My Assigned Subjects",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isDept
                                    ? "Manage department academic subjects and faculty assignments"
                                    : "Subjects allocated to you for teaching",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isDept && isHodOrAdmin) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.assignment_ind, size: 16),
                            label: const Text("Assign Faculty", style: TextStyle(fontSize: 13)),
                            onPressed: () => context.push('/subjects/assign').then((_) => _loadSubjects()),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF13246E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Add Subject", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            onPressed: () => context.push('/subjects/add').then((_) => _loadSubjects()),
                          ),
                        ],
                      ],
                    ),
                    if (isHod && widget.isDepartmentView) ...[
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                if (_viewMode != 'ALL_DEPT') {
                                  setState(() => _viewMode = 'ALL_DEPT');
                                  _loadSubjects();
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _viewMode == 'ALL_DEPT' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "All Department Subjects",
                                  style: TextStyle(
                                    color: _viewMode == 'ALL_DEPT' ? const Color(0xFF13246E) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (_viewMode != 'MY_SUBJECTS') {
                                  setState(() => _viewMode = 'MY_SUBJECTS');
                                  _loadSubjects();
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _viewMode == 'MY_SUBJECTS' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "My Teaching Subjects",
                                  style: TextStyle(
                                    color: _viewMode == 'MY_SUBJECTS' ? const Color(0xFF13246E) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. SEARCH & FILTER BAR (Image 1)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;
                    if (isMobile) {
                      return Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search subject name...",
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildAcademicYearDropdown()),
                              const SizedBox(width: 8),
                              Expanded(child: _buildSemesterDropdown()),
                              const SizedBox(width: 8),
                              _buildRefreshButton(),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: "Search subject name...",
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildAcademicYearDropdown(),
                        const SizedBox(width: 12),
                        _buildSemesterDropdown(),
                        const SizedBox(width: 12),
                        _buildRefreshButton(),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 3. RESULTS COUNT & ACTIVE FILTER SUMMARY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Showing ${filtered.length} of ${_subjects.length} subjects",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (_selectedSemester != null || _selectedAcademicYear != null || _searchQuery.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text("Reset Filters", style: TextStyle(fontSize: 12, color: Color(0xFF13246E))),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedSemester = null;
                          _selectedAcademicYear = null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. 2-COLUMN PASTEL GRID (Image 1)
              if (_subjects.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          !isDept
                              ? "No subjects assigned to you for teaching yet."
                              : "No department subjects found.",
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                _buildEmptyFilteredView()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSingleCol = constraints.maxWidth < 680;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isSingleCol ? 1 : 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 96,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final subject = filtered[index];
                        final theme = _pastelThemes[index % _pastelThemes.length];
                        return _buildPastelSubjectCard(subject, theme, isHodOrAdmin);
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicYearDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedAcademicYear,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E)),
          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
          hint: const Text("Academic Year", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text("All Academic Years"),
            ),
            ..._academicYears.map((ay) {
              final yName = ay['year_name']?.toString() ?? '';
              return DropdownMenuItem<String?>(
                value: yName,
                child: Text(yName),
              );
            }),
          ],
          onChanged: (val) {
            setState(() => _selectedAcademicYear = val);
            _loadSubjects();
          },
        ),
      ),
    );
  }

  Widget _buildSemesterDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedSemester,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E)),
          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
          hint: const Text("Semester", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text("All Semesters"),
            ),
            ..._availableSemesters.map((sem) {
              final count = _subjects.where((s) => s.semester == sem).length;
              return DropdownMenuItem<String?>(
                value: sem,
                child: Text("Semester $sem ($count)"),
              );
            }),
          ],
          onChanged: (val) => setState(() => _selectedSemester = val),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF13246E)),
        tooltip: "Refresh",
        onPressed: _loadSubjects,
      ),
    );
  }

  Widget _buildPastelSubjectCard(SubjectSimple subject, _PastelTheme theme, bool isHodOrAdmin) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSubjectDetailsModal(context, subject),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(theme.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${subject.code} • Sem ${subject.semester}${subject.department != null ? ' • ${subject.department}' : ''}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _buildSubjectTypeBadge(subject),
                        if (subject.isElective)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.purple.shade300),
                            ),
                            child: Text(
                              "Elective",
                              style: TextStyle(
                                color: Colors.purple.shade800,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isHodOrAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: "Delete Subject",
                  onPressed: () => _confirmDeleteSubject(subject),
                ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFF13246E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectTypeBadge(SubjectSimple subject) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    if (subject.subjectType == 'PROJECT') {
      bg = Colors.purple.shade50;
      border = Colors.purple.shade300;
      text = Colors.purple.shade800;
      icon = Icons.assignment_outlined;
      label = "Project";
    } else if (subject.subjectType == 'LAB') {
      bg = Colors.teal.shade50;
      border = Colors.teal.shade300;
      text = Colors.teal.shade800;
      icon = Icons.biotech_rounded;
      label = "Lab";
    } else if (subject.subjectType == 'BOTH') {
      bg = Colors.indigo.shade50;
      border = Colors.indigo.shade300;
      text = const Color(0xFF13246E);
      icon = Icons.layers_rounded;
      label = "Theory + Lab";
    } else {
      bg = Colors.blueGrey.shade50;
      border = Colors.blueGrey.shade200;
      text = Colors.blueGrey.shade800;
      icon = Icons.menu_book_rounded;
      label = "Theory";
    }

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyFilteredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "No subjects found matching your filters",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try adjusting your search query or choosing a different semester.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text("Clear Filters"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedSemester = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSubject(SubjectSimple subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Delete Subject", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete '${subject.code} - ${subject.name}'?\n\nThis will permanently delete this subject and its faculty assignments.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final dio = ApiClient().dio;
        final response = await dio.delete('/subjects/delete/${subject.id}/');
        if (!mounted) return;
        final msg = (response.data is Map && (response.data as Map).containsKey('message'))
            ? response.data['message'].toString()
            : "Subject deleted successfully.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
        _loadSubjects();
      } on DioException catch (e) {
        if (!mounted) return;
        String err = "Failed to delete subject";
        if (e.response?.data != null) {
          if (e.response!.data is Map && (e.response!.data as Map).containsKey('error')) {
            err = (e.response!.data as Map)['error'].toString();
          } else {
            err = e.response?.data.toString() ?? err;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSubjectDetailsModal(BuildContext context, SubjectSimple subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubjectDetailsSheet(
        subject: subject,
        onRefreshNeeded: _loadSubjects,
        onDelete: (s) => _confirmDeleteSubject(s),
      ),
    );
  }
}

class _SubjectDetailsSheet extends StatefulWidget {
  final SubjectSimple subject;
  final VoidCallback onRefreshNeeded;
  final Function(SubjectSimple) onDelete;

  const _SubjectDetailsSheet({
    required this.subject,
    required this.onRefreshNeeded,
    required this.onDelete,
  });

  @override
  State<_SubjectDetailsSheet> createState() => _SubjectDetailsSheetState();
}

class _SubjectDetailsSheetState extends State<_SubjectDetailsSheet> {
  bool _loadingFaculty = true;
  List<Map<String, dynamic>> _assignedFaculty = [];

  @override
  void initState() {
    super.initState();
    _loadAssignedFaculty();
  }

  Future<void> _loadAssignedFaculty() async {
    try {
      final dio = ApiClient().dio;
      final response = await dio.get(
        '/subjects/getAssignedProfessors/',
        queryParameters: {'subject_id': widget.subject.id},
      );

      List raw = [];
      if (response.data is List) {
        raw = response.data;
      } else if (response.data is Map && response.data['results'] is List) {
        raw = response.data['results'];
      }

      if (mounted) {
        final distinctFacultyMap = <dynamic, Map<String, dynamic>>{};
        for (final item in raw) {
          final m = Map<String, dynamic>.from(item as Map);
          final key = m['faculty_id'] ?? m['professor_name'] ?? m['name'];
          if (key != null && !distinctFacultyMap.containsKey(key)) {
            distinctFacultyMap[key] = m;
          }
        }
        setState(() {
          _assignedFaculty = distinctFacultyMap.values.toList();
          _loadingFaculty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFaculty = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? '').toUpperCase();
    final isHodOrAdmin = role == AppRoles.hod || role == AppRoles.principal || role == AppRoles.system;

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                child: Text(
                  widget.subject.semester.isNotEmpty ? "S${widget.subject.semester}" : "S",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subject.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Code: ${widget.subject.code}",
                      style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if (widget.subject.department != null)
                      Text(
                        "Dept: ${widget.subject.department}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    _buildTypePill(widget.subject),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            "Assigned Faculty",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF13246E)),
          ),
          const SizedBox(height: 8),
          if (_loadingFaculty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_assignedFaculty.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  const Text("No faculty assigned to this subject yet.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          else
            ..._assignedFaculty.map((fac) {
              final name = fac['professor_name'] ?? fac['faculty_name'] ?? fac['name'] ?? 'Assigned Faculty';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Color(0xFF13246E)),
                    const SizedBox(width: 8),
                    Text(name.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          // Action Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isHodOrAdmin) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.assignment_ind, size: 18),
                  label: const Text("Assign Faculty"),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/subjects/assign').then((_) => widget.onRefreshNeeded());
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Delete Subject"),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete(widget.subject);
                  },
                ),
              ],
              if (role != AppRoles.professor || widget.subject.isAssignedToMe)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.grade, size: 18),
                  label: const Text("IA Marks"),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/ia/create/${widget.subject.id}',
                      extra: widget.subject.name,
                    );
                  },
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text("Timetable"),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/timetable/list');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill(SubjectSimple s) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    if (s.subjectType == 'PROJECT') {
      bg = Colors.purple.shade50;
      border = Colors.purple.shade300;
      text = Colors.purple.shade800;
      icon = Icons.assignment_outlined;
      label = "Subject Type: Project";
    } else if (s.subjectType == 'LAB') {
      bg = Colors.teal.shade50;
      border = Colors.teal.shade300;
      text = Colors.teal.shade800;
      icon = Icons.biotech_rounded;
      label = "Subject Type: Lab Only";
    } else if (s.subjectType == 'BOTH') {
      bg = Colors.indigo.shade50;
      border = Colors.indigo.shade300;
      text = const Color(0xFF13246E);
      icon = Icons.layers_rounded;
      label = "Subject Type: Both Theory & Lab";
    } else {
      bg = Colors.blueGrey.shade50;
      border = Colors.blueGrey.shade200;
      text = Colors.blueGrey.shade800;
      icon = Icons.menu_book_rounded;
      label = "Subject Type: Theory Only";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}