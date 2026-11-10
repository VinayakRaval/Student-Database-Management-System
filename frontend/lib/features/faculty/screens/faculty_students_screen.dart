import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/app_pagination_bar.dart';

class FacultyStudentsScreen extends ConsumerStatefulWidget {
  const FacultyStudentsScreen({super.key});

  @override
  ConsumerState<FacultyStudentsScreen> createState() => _FacultyStudentsScreenState();
}

class _FacultyStudentsScreenState extends ConsumerState<FacultyStudentsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _assignedSubjects = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _academicYears = [];

  // Filters
  int? _selectedSubjectId;
  String? _selectedSemester;
  String? _selectedAcademicYear;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  int _currentPage = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchAssignedSubjectsAndStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAssignedSubjectsAndStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;

      // 1. Fetch assigned subjects for this professor
      final subRes = await dio.get('/subjects/professor/subjects/');
      final List rawSubs = subRes.data is List ? subRes.data : [];
      final subjects = rawSubs.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // 2. Fetch academic years
      try {
        final ayRes = await dio.get('/academics/academic-years/');
        final List rawAy = ayRes.data is List ? ayRes.data : [];
        _academicYears = rawAy.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}

      // 3. Fetch students for assigned classes (assigned_only ensures HOD gets only their teaching students)
      final stuRes = await dio.get('/students/list/', queryParameters: {'assigned_only': 'true'});
      final List rawStu = stuRes.data is List
          ? stuRes.data
          : (stuRes.data is Map && stuRes.data['results'] is List ? stuRes.data['results'] : []);
      final students = rawStu.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Sort students by USN in ascending order (lowest to highest)
      students.sort((a, b) => (a['usn'] ?? '').toString().trim().compareTo((b['usn'] ?? '').toString().trim()));

      if (mounted) {
        setState(() {
          _assignedSubjects = subjects;
          _students = students;
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load students: $e";
          _isLoading = false;
        });
      }
    }
  }

  String _extractDept(Map<String, dynamic> st) {
    final dName = st['department_name'];
    if (dName != null && dName.toString().isNotEmpty) return dName.toString();
    final d = st['department'];
    if (d is Map) return d['name']?.toString() ?? '';
    return d != null ? d.toString() : '';
  }

  String _extractSem(Map<String, dynamic> st) {
    final sName = st['semester_name'];
    if (sName != null && sName.toString().isNotEmpty) {
      return sName.toString().replaceAll(RegExp(r'[^\d]'), '');
    }
    final sNo = st['semester_no'];
    if (sNo != null && sNo.toString().isNotEmpty) {
      return sNo.toString().replaceAll(RegExp(r'[^\d]'), '');
    }
    final s = st['semester'];
    if (s is Map) return s['sem_number']?.toString() ?? '';
    if (s != null) return s.toString().replaceAll(RegExp(r'[^\d]'), '');
    return '';
  }

  List<String> get _availableSemesters {
    final sems = <String>{};
    for (final s in _assignedSubjects) {
      final sem = s['semester']?.toString();
      if (sem != null && sem.isNotEmpty) sems.add(sem);
    }
    for (final st in _students) {
      final sem = _extractSem(st);
      if (sem.isNotEmpty) sems.add(sem);
    }
    return sems.toList()..sort();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    return _students.where((st) {
      final usn = (st['usn'] ?? '').toString().toLowerCase();
      final name = (st['name'] ?? '').toString().toLowerCase();
      final dept = _extractDept(st);
      final sem = _extractSem(st);

      // Search
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        if (!usn.contains(q) && !name.contains(q)) {
          return false;
        }
      }

      // Semester filter
      if (_selectedSemester != null && sem != _selectedSemester) {
        return false;
      }

      // Academic Year filter
      if (_selectedAcademicYear != null) {
        final ay = (st['academic_year_name'] ?? st['academic_year'] ?? '').toString();
        if (ay.isNotEmpty && ay != _selectedAcademicYear) {
          return false;
        }
      }

      // Under Faculty Access, only students belonging to assigned teaching subjects are shown
      if (_assignedSubjects.isEmpty) {
        return false;
      }

      // Subject filter
      if (_selectedSubjectId != null) {
        final foundSub = _assignedSubjects.firstWhere(
          (s) => s['id'] == _selectedSubjectId || s['subject_id'] == _selectedSubjectId,
          orElse: () => {},
        );
        if (foundSub.isNotEmpty) {
          final subDept = (foundSub['department_name'] ?? '').toString().toLowerCase();
          final subSem = (foundSub['semester'] ?? '').toString();
          if (subDept.isNotEmpty && dept.isNotEmpty && dept.toLowerCase() != subDept) return false;
          if (subSem.isNotEmpty && sem.isNotEmpty && sem != subSem) return false;
        }
      } else {
        // When no single subject is filtered, student must still match one of the assigned subjects
        final matchesAny = _assignedSubjects.any((sub) {
          final subDept = (sub['department_name'] ?? '').toString().toLowerCase();
          final subSem = (sub['semester'] ?? '').toString();
          bool deptMatch = subDept.isEmpty || dept.isEmpty || dept.toLowerCase() == subDept;
          bool semMatch = subSem.isEmpty || sem.isEmpty || sem == subSem;
          return deptMatch && semMatch;
        });
        if (!matchesAny) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("My Students Directory"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Student List",
            onPressed: _fetchAssignedSubjectsAndStudents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 54, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
              onPressed: _fetchAssignedSubjectsAndStudents,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredStudents;
    final totalItems = filtered.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
    final safePage = _currentPage > totalPages ? totalPages : (_currentPage < 1 ? 1 : _currentPage);
    final pageStudents = totalItems == 0 ? <Map<String, dynamic>>[] : filtered.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        // 1. Top Filter and Search Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              // Search input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search by USN or student name...",
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF13246E)),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _currentPage = 1;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 1;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Dropdowns
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Academic Year Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedAcademicYear,
                          hint: const Text("All Academic Years", style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text("All Academic Years", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            ..._academicYears.map((ay) {
                              final yName = ay['year_name']?.toString() ?? '';
                              return DropdownMenuItem<String?>(
                                value: yName,
                                child: Text(yName, style: const TextStyle(fontSize: 13)),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedAcademicYear = val;
                            _currentPage = 1;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Subject Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedSubjectId,
                          hint: const Text("All Assigned Subjects", style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text("All Assigned Subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            ..._assignedSubjects.map((sub) {
                              final subId = (sub['id'] ?? sub['subject_id']) as int;
                              final code = sub['subject_code'] ?? '';
                              final name = sub['subject_name'] ?? '';
                              final sem = sub['semester'] ?? '';
                              return DropdownMenuItem<int?>(
                                value: subId,
                                child: Text("$code - $name (Sem $sem)", style: const TextStyle(fontSize: 13)),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedSubjectId = val;
                            _currentPage = 1;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Semester Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedSemester,
                          hint: const Text("All Semesters", style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text("All Semesters", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            ..._availableSemesters.map((sem) {
                              return DropdownMenuItem<String?>(
                                value: sem,
                                child: Text("Semester $sem", style: const TextStyle(fontSize: 13)),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedSemester = val;
                            _currentPage = 1;
                          }),
                        ),
                      ),
                    ),

                    // Clear Filters
                    if (_selectedSubjectId != null || _selectedSemester != null || _selectedAcademicYear != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text("Reset", style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _selectedSubjectId = null;
                            _selectedSemester = null;
                            _selectedAcademicYear = null;
                            _currentPage = 1;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Metrics Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt, size: 16, color: Color(0xFF13246E)),
                  const SizedBox(width: 6),
                  Text(
                    "Showing ${filtered.length} Student${filtered.length == 1 ? '' : 's'}",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                  ),
                ],
              ),
              Text(
                "Assigned Classes: ${_assignedSubjects.length} Subject(s)",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // 3. Students List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: pageStudents.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = pageStudents[index];
                    return _buildStudentCard(student);
                  },
                ),
        ),
        if (!_isLoading && filtered.isNotEmpty)
          AppPaginationBar(
            currentPage: safePage,
            totalPages: totalPages,
            totalItems: totalItems,
            pageSize: _pageSize,
            activeColor: const Color(0xFF13246E),
            onPageChanged: (newPage) {
              setState(() {
                _currentPage = newPage;
              });
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "No students found matching your criteria",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            "Try clearing filters or searching by a different name/USN.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final usn = student['usn']?.toString() ?? 'N/A';
    final name = student['name']?.toString() ?? 'Unknown Student';
    final dept = _extractDept(student).isNotEmpty ? _extractDept(student) : 'N/A';
    final sem = _extractSem(student).isNotEmpty ? _extractSem(student) : 'N/A';
    final status = (student['status'] ?? student['registration_status'] ?? 'Active').toString().toUpperCase();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E), fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),

            // Student Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'ACTIVE' || status == 'VERIFIED'
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: status == 'ACTIVE' || status == 'VERIFIED' ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "USN: $usn · Sem $sem",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF13246E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dept,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Action / Details & History buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_edu_rounded, size: 16),
                  label: const Text("History", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF13246E),
                    side: const BorderSide(color: Color(0xFF13246E)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final usn = student['usn']?.toString() ?? '';
                    context.push('/faculty/academic-history?search=$usn');
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.badge_outlined, size: 16),
                  label: const Text("Details", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showStudentDialog(student),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDialog(Map<String, dynamic> student) {
    final usn = student['usn']?.toString() ?? 'N/A';
    final name = student['name']?.toString() ?? 'Unknown Student';
    final dept = _extractDept(student).isNotEmpty ? _extractDept(student) : 'N/A';
    final rawSem = _extractSem(student);
    final sem = rawSem.isNotEmpty ? "Semester $rawSem" : 'Semester N/A';
    final email = student['email']?.toString() ?? 'N/A';
    final phone = student['phone']?.toString() ?? 'N/A';
    final seatType = student['seat_type']?.toString() ?? 'Regular';

    // Extract initials
    final nameParts = name.trim().split(RegExp(r'\s+'));
    final initials = nameParts.isEmpty || nameParts.first.isEmpty
        ? 'S'
        : (nameParts.length == 1
            ? nameParts.first[0].toUpperCase()
            : '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase());

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 520,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Premium Dark Navy Gradient Header with Avatar & USN pill
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Circle
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Name & Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              // USN Chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_rounded, size: 13, color: Color(0xFF67E8F9)),
                                    const SizedBox(width: 5),
                                    Text(
                                      usn,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Status Chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF34D399)),
                                    SizedBox(width: 4),
                                    Text(
                                      "Enrolled & Active",
                                      style: TextStyle(
                                        color: Color(0xFF6EE7B7),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Close Icon Button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      splashRadius: 18,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              // 2. Body Details in Card Tiles
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
                child: Column(
                  children: [
                    // Row 1: Department & Semester
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.account_balance_rounded,
                            iconColor: const Color(0xFF2563EB),
                            iconBg: const Color(0xFFEFF6FF),
                            label: "DEPARTMENT",
                            value: dept,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.school_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            iconBg: const Color(0xFFF5F3FF),
                            label: "SEMESTER",
                            value: sem,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Seat Type & Contact Phone
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.verified_user_rounded,
                            iconColor: const Color(0xFF0D9488),
                            iconBg: const Color(0xFFF0FDFA),
                            label: "ADMISSION SEAT",
                            value: seatType,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.phone_rounded,
                            iconColor: const Color(0xFFEA580C),
                            iconBg: const Color(0xFFFFF7ED),
                            label: "CONTACT NUMBER",
                            value: phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 3: Official Email (Full width)
                    _buildInfoCard(
                      icon: Icons.mail_rounded,
                      iconColor: const Color(0xFF4F46E5),
                      iconBg: const Color(0xFFEEF2FF),
                      label: "REGISTERED EMAIL",
                      value: email,
                    ),
                    const SizedBox(height: 14),

                    // Info callout banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Academic record visible under assigned faculty teaching authorization.",
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("Close", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.history_edu_rounded, size: 18),
                      label: const Text(
                        "View Full Academic History",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.push('/faculty/academic-history?search=${student['usn'] ?? ''}');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
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
}
