import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class FacultyScheduleScreen extends ConsumerStatefulWidget {
  const FacultyScheduleScreen({super.key});

  @override
  ConsumerState<FacultyScheduleScreen> createState() =>
      _FacultyScheduleScreenState();
}

class _FacultyScheduleScreenState extends ConsumerState<FacultyScheduleScreen> {
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _assignedSubjects = [];
  List<Map<String, dynamic>> _academicYears = [];
  String _facultyName = '';
  bool _isLoading = true;
  bool _isGridView = true;
  String _userRole = '';
  bool _isHod = false;
  bool _showDepartmentSchedule = true;

  int? _selectedSemester = 6;
  String? _selectedAcademicYear;
  String? _classTeacherName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Exact Grid Dimensions matching TimetableDetailScreen (HOD Department Timetable)
  final double _rowHeight = 92.0;
  final double _headerHeight = 52.0;
  final double _baseSlotWidth = 140.0;
  final double _dayColWidth = 55.0;
  final double _breakColWidth = 40.0;
  final double _lunchColWidth = 65.0;

  final List<Map<String, dynamic>> _templateColumns = [
    {"start": "09:30", "end": "10:30", "type": "CLASS"},
    {"start": "10:30", "end": "11:30", "type": "CLASS"},
    {"start": "11:30", "end": "12:30", "type": "CLASS"},
    {"start": "12:30", "end": "13:30", "type": "CLASS"},
    {
      "start": "13:30",
      "end": "14:00",
      "type": "LUNCH",
      "label": "LUNCH",
    },
    {"start": "14:00", "end": "15:00", "type": "CLASS"},
    {"start": "15:00", "end": "16:00", "type": "CLASS"},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_academicYears.isEmpty) {
        try {
          final dio = ref.read(dioProvider);
          final ayRes = await dio.get('/academics/academic-years/');
          final List rawAy = ayRes.data is List ? ayRes.data : [];
          _academicYears = rawAy.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }

      if (_userRole.isEmpty) {
        final r = await SecureStorage().read('role');
        _userRole = (r ?? '').trim().toUpperCase();
        _isHod = _userRole == 'HOD' ||
            _userRole == 'HEAD OF DEPARTMENT' ||
            _userRole == 'PRINCIPAL' ||
            _userRole == 'SYSTEM';
      }

      final bool isPersonal = _isHod ? !_showDepartmentSchedule : true;

      var data = await ref
          .read(timetableProvider.notifier)
          .fetchScheduleDetails(
            semester: _selectedSemester,
            search: _searchQuery,
            personal: isPersonal,
            academicYear: _selectedAcademicYear,
          );

      var slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
      var assigned = List<Map<String, dynamic>>.from(data['assigned_subjects'] ?? []);
      var facultyName = data['faculty_name']?.toString() ?? '';
      var classTeacherName = data['class_teacher_name']?.toString();

      // Auto retry once if empty (handles async auth token resolution on web/refresh)
      if (slots.isEmpty && assigned.isEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          data = await ref
              .read(timetableProvider.notifier)
              .fetchScheduleDetails(
                semester: _selectedSemester,
                search: _searchQuery,
                personal: isPersonal,
                academicYear: _selectedAcademicYear,
              );
          slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
          assigned = List<Map<String, dynamic>>.from(data['assigned_subjects'] ?? []);
          facultyName = data['faculty_name']?.toString() ?? '';
          classTeacherName = data['class_teacher_name']?.toString() ?? classTeacherName;
        }
      }

      if (mounted) {
        setState(() {
          _slots = slots;
          _assignedSubjects = assigned;
          _facultyName = facultyName;
          _classTeacherName = classTeacherName;
        });
      }
    } catch (e) {
      debugPrint("Error loading schedule: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSemester = null;
      _selectedAcademicYear = null;
      _searchController.clear();
      _searchQuery = '';
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // Strict filter slots locally
    final filteredSlots = _slots.where((slot) {
      if (_selectedSemester != null) {
        final sem = slot['semester'];
        if (sem == null || sem.toString() != _selectedSemester.toString()) {
          return false;
        }
      }
      if (_selectedAcademicYear != null && _selectedAcademicYear!.isNotEmpty) {
        final slotAy = (slot['academic_year'] ?? slot['academic_year_name'] ?? '').toString();
        if (slotAy.isNotEmpty && slotAy.toLowerCase() != _selectedAcademicYear!.toLowerCase()) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (slot['subject_name'] ?? '').toString().toLowerCase();
        final code = (slot['subject_code'] ?? '').toString().toLowerCase();
        final day = (slot['day'] ?? '').toString().toLowerCase();
        final batch = (slot['batch_name'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !code.contains(q) && !day.contains(q) && !batch.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Strict filter assigned subjects locally
    final filteredAssigned = _assignedSubjects.where((sub) {
      if (_selectedSemester != null) {
        final sem = sub['semester'];
        if (sem == null || sem.toString() != _selectedSemester.toString()) {
          return false;
        }
      }
      return true;
    }).toList();

    final parsedSlots = filteredSlots.map((m) => TimeTableSlot.fromMap(m)).toList();

    // Group slots by Day for List View
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var slot in filteredSlots) {
      final day = (slot['day'] ?? 'Unknown').toString().toUpperCase();
      if (!grouped.containsKey(day)) grouped[day] = [];
      grouped[day]!.add(slot);
    }

    final daysOrder = ["MON", "TUE", "WED", "THU", "FRI", "SAT"];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isHod && _showDepartmentSchedule
              ? "Department Timetable"
              : (_facultyName.isNotEmpty
                  ? "Teaching Schedule - $_facultyName"
                  : "My Teaching Schedule"),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Schedule",
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // --- FILTER BAR ---
            _buildFilterBar(),

            // --- MAIN CONTENT ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 1. ASSIGNED SUBJECTS CARD (Only shown in personal schedule view, hidden in Department Timetable)
                        if (!(_isHod && _showDepartmentSchedule) && filteredAssigned.isNotEmpty) ...[
                          _buildAssignedSubjectsCard(filteredAssigned),
                          const SizedBox(height: 16),
                        ],

                        // 2. CLASS TEACHER & TIMETABLE HEADER BANNER
                        _buildClassTeacherBanner(),

                        // 3. TIMETABLE SLOTS
                        if (filteredSlots.isEmpty)
                          _buildEmptyState()
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isGridView ? "Official Timetable Grid" : "Weekly Schedule List",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF13246E),
                                ),
                              ),
                              Row(
                                children: [
                                  if (_isGridView) ...[
                                    Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Scroll horizontally to view all periods",
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    "${filteredSlots.length} classes scheduled",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isGridView)
                            _buildTimetableGridCard(parsedSlots)
                          else
                            ...daysOrder.map((day) {
                              if (!grouped.containsKey(day)) {
                                return const SizedBox.shrink();
                              }

                              final daySlots = grouped[day]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: Color(0xFF13246E),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          day,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF13246E),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF13246E).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            "${daySlots.length} sessions",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF13246E),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...daySlots.expand((slot) => _buildListViewSlotCards(slot)),
                                  const SizedBox(height: 6),
                                ],
                              );
                            }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FILTER BAR WIDGET ---
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (_isHod) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      if (!_showDepartmentSchedule) {
                        setState(() => _showDepartmentSchedule = true);
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showDepartmentSchedule ? const Color(0xFF13246E) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Department Timetable",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _showDepartmentSchedule ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (_showDepartmentSchedule) {
                        setState(() => _showDepartmentSchedule = false);
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_showDepartmentSchedule ? const Color(0xFF13246E) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "My Schedule",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: !_showDepartmentSchedule ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Search Field
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search subject, code, or day...",
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadData();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              onSubmitted: (_) => _loadData(),
            ),
          ),
          const SizedBox(width: 12),

          // Academic Year Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedAcademicYear,
                  isExpanded: true,
                  hint: const Text(
                    "All Academic Years",
                    style: TextStyle(fontSize: 13),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        "All Academic Years",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    ..._academicYears.map((ay) {
                      final yName = ay['year_name']?.toString() ?? '';
                      return DropdownMenuItem<String?>(
                        value: yName,
                        child: Text(
                          yName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedAcademicYear = val);
                    _loadData();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Semester Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedSemester,
                  isExpanded: true,
                  hint: const Text(
                    "All Semesters",
                    style: TextStyle(fontSize: 13),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        "All Semesters",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    ...List.generate(8, (i) => i + 1).map((sem) {
                      return DropdownMenuItem<int?>(
                        value: sem,
                        child: Text(
                          "Semester $sem",
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedSemester = val);
                    _loadData();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // View Mode Switcher
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isGridView = true),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isGridView ? const Color(0xFF13246E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_on_rounded,
                          size: 15,
                          color: _isGridView ? Colors.white : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Grid View",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isGridView ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isGridView = false),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isGridView ? const Color(0xFF13246E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.view_agenda_outlined,
                          size: 15,
                          color: !_isGridView ? Colors.white : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "List View",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_isGridView ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CLASS TEACHER & TIMETABLE BANNER ---
  Widget _buildClassTeacherBanner() {
    final activeAy = _selectedAcademicYear ?? (_academicYears.isNotEmpty ? _academicYears.first['year_name']?.toString() : '2026-2027');
    final semText = _selectedSemester != null ? "Semester $_selectedSemester" : "All Semesters";
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF13246E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_pin,
              color: Color(0xFF13246E),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "$semText Class Teacher",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (activeAy != null && activeAy.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activeAy,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _classTeacherName != null && _classTeacherName!.isNotEmpty
                      ? _classTeacherName!
                      : "Class teacher not assigned for this semester",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _classTeacherName != null && _classTeacherName!.isNotEmpty
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF16A34A)),
                SizedBox(width: 4),
                Text(
                  "Active Timetable",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ASSIGNED SUBJECTS CARD ---
  Widget _buildAssignedSubjectsCard([List<Map<String, dynamic>>? subjectsList]) {
    final list = subjectsList ?? _assignedSubjects;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in, size: 18, color: Color(0xFF13246E)),
                  SizedBox(width: 8),
                  Text(
                    "My Assigned Subjects",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${list.length} subjects",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((sub) {
              final slotsCount = sub['slots_count'] ?? 0;
              final isScheduled = slotsCount > 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isScheduled
                      ? const Color(0xFFE8EAF6)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isScheduled
                        ? const Color(0xFFC5CAE9)
                        : Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sub['subject_code'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isScheduled
                                    ? const Color(0xFF13246E)
                                    : Colors.brown.shade800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sub['subject_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Sem ${sub['semester'] ?? 'N/A'}",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isScheduled
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isScheduled
                                    ? "$slotsCount classes scheduled"
                                    : "Not yet in timetable",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isScheduled
                                      ? Colors.green.shade800
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedSemester != null || _searchQuery.isNotEmpty
                  ? "No teaching slots found matching filters."
                  : "No classes currently scheduled in active timetables.",
              style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_selectedSemester != null || _searchQuery.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text("Clear Filters"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                ),
                onPressed: _clearFilters,
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Refresh Schedule"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadData,
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // LIST VIEW IMPLEMENTATION: Multi-batch breakdown (2:00 PM – 4:00 PM)
  // Format: 2:00 PM – 4:00 PM | IoT | Batch A | Dr. Faculty Name | Lab 1
  // ===========================================================================
  bool _isAssignedToThisFaculty(String? targetFaculty) {
    if (_facultyName.isEmpty || targetFaculty == null || targetFaculty.trim().isEmpty) return true;
    final cur = _facultyName.toLowerCase().replaceAll('dr.', '').replaceAll('dr', '').trim();
    final target = targetFaculty.toLowerCase().replaceAll('dr.', '').replaceAll('dr', '').trim();
    return cur == target || cur.contains(target) || target.contains(cur);
  }

  List<Widget> _buildListViewSlotCards(Map<String, dynamic> slot) {
    final rawBatches = slot['batches'] is List ? List<dynamic>.from(slot['batches']) : [];
    final isBatchWise = slot['is_batch_wise'] == true || rawBatches.isNotEmpty;

    if (isBatchWise && rawBatches.isNotEmpty) {
      final filteredBatches = rawBatches.where((b) {
        final bMap = Map<String, dynamic>.from(b as Map);
        final info = bMap['assignment_info'] is Map ? Map<String, dynamic>.from(bMap['assignment_info'] as Map) : <String, dynamic>{};
        final fName = (info['faculty_name'] ?? bMap['faculty_name'] ?? slot['faculty_name'] ?? '').toString();
        return _isAssignedToThisFaculty(fName);
      }).toList();
      final toIterate = filteredBatches.isNotEmpty ? filteredBatches : rawBatches;

      return toIterate.map((b) {
        final bMap = Map<String, dynamic>.from(b as Map);
        final info = bMap['assignment_info'] is Map ? Map<String, dynamic>.from(bMap['assignment_info'] as Map) : <String, dynamic>{};

        final String rawBatchName = (bMap['batch_name']?.toString().trim() ?? '');
        final String batchName = rawBatchName.isNotEmpty ? rawBatchName : "Batch Not Assigned";

        final String subjectName = (info['subject_name'] ?? slot['subject_name'] ?? "Unknown Subject").toString();
        final String subjectCode = (info['subject_code'] ?? slot['subject_code'] ?? "").toString();
        final String facultyName = (info['faculty_name'] ?? slot['faculty_name'] ?? "Faculty Not Assigned").toString();
        final String labRoom = (bMap['lab_room']?.toString().trim().isNotEmpty ?? false)
            ? bMap['lab_room'].toString().trim()
            : ((slot['lab_room']?.toString().trim().isNotEmpty ?? false) ? slot['lab_room'].toString().trim() : "Lab 1");
        final String branchName = (info['subject_department'] ?? slot['branch_name'] ?? "").toString();
        final String semester = (info['semester'] ?? slot['semester'] ?? "").toString();

        final String startTime = (bMap['start_time'] ?? bMap['effective_start_time'] ?? slot['start_time'] ?? "").toString();
        final String endTime = (bMap['end_time'] ?? bMap['effective_end_time'] ?? slot['end_time'] ?? "").toString();

        return _buildClassCard(
          startTime: startTime,
          endTime: endTime,
          subjectName: subjectName,
          subjectCode: subjectCode,
          batchName: batchName,
          facultyName: facultyName,
          labRoom: labRoom,
          branchName: branchName,
          semester: semester,
          isLab: true,
        );
      }).toList();
    }

    if (isBatchWise) {
      final String rawBatchName = (slot['batch_name']?.toString().trim() ?? '');
      final String batchName = rawBatchName.isNotEmpty ? rawBatchName : "Batch Not Assigned";

      final String subjectName = (slot['subject_name'] ?? "Unknown Subject").toString();
      final String subjectCode = (slot['subject_code'] ?? "").toString();
      final String facultyName = (slot['faculty_name'] ?? "Faculty Not Assigned").toString();
      final String labRoom = (slot['lab_room']?.toString().trim().isNotEmpty ?? false)
          ? slot['lab_room'].toString().trim()
          : "Lab 1";
      final String branchName = (slot['branch_name'] ?? "").toString();
      final String semester = (slot['semester'] ?? "").toString();
      final String startTime = (slot['start_time'] ?? "").toString();
      final String endTime = (slot['end_time'] ?? "").toString();

      return [
        _buildClassCard(
          startTime: startTime,
          endTime: endTime,
          subjectName: subjectName,
          subjectCode: subjectCode,
          batchName: batchName,
          facultyName: facultyName,
          labRoom: labRoom,
          branchName: branchName,
          semester: semester,
          isLab: true,
        )
      ];
    }

    // Standard Theory Lecture Slot
    final String subjectName = (slot['subject_name'] ?? "Unknown Subject").toString();
    final String subjectCode = (slot['subject_code'] ?? "").toString();
    final String facultyName = (slot['faculty_name'] ?? "Faculty Not Assigned").toString();
    final String room = (slot['room'] ?? slot['lab_room'] ?? "").toString().trim();
    final String branchName = (slot['branch_name'] ?? "").toString();
    final String semester = (slot['semester'] ?? "").toString();
    final String startTime = (slot['start_time'] ?? "").toString();
    final String endTime = (slot['end_time'] ?? "").toString();

    return [
      _buildClassCard(
        startTime: startTime,
        endTime: endTime,
        subjectName: subjectName,
        subjectCode: subjectCode,
        batchName: null,
        facultyName: facultyName,
        labRoom: room,
        branchName: branchName,
        semester: semester,
        isLab: false,
      )
    ];
  }

  Widget _buildClassCard({
    required String startTime,
    required String endTime,
    required String subjectName,
    required String subjectCode,
    required String? batchName,
    required String facultyName,
    required String labRoom,
    required String branchName,
    required String semester,
    required bool isLab,
  }) {
    final tRange12 = TimeTable.formatTimeRange12(startTime, endTime);
    final sTime12 = TimeTable.formatTime12(startTime);
    final eTime12 = TimeTable.formatTime12(endTime);
    final isUnassignedBatch = batchName == "Batch Not Assigned";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isLab ? const Color(0xFFBFDBFE) : Colors.grey.shade300,
          width: isLab ? 1.2 : 1.0,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Time Column
                Container(
                  width: 95,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLab ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLab ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        sTime12,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF13246E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(Icons.arrow_downward, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(height: 2),
                      Text(
                        eTime12,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF13246E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isLab ? const Color(0xFFDBEAFE) : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLab ? "2 hrs" : "1 hr",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isLab ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Name
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Badges Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (subjectCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subjectCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isLab) ...[
                            if (batchName != null && !isUnassignedBatch)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.group, size: 12, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 3),
                                    Text(
                                      batchName,
                                      style: const TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isUnassignedBatch)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFCD34D)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFF92400E)),
                                    SizedBox(width: 3),
                                    Text(
                                      "Batch Not Assigned",
                                      style: TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: const Text(
                                "LAB / PRACTICAL",
                                style: TextStyle(
                                  color: Color(0xFF6B21A8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Text(
                                "THEORY",
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Faculty & Room
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Color(0xFF13246E)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              facultyName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF13246E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (labRoom.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(isLab ? Icons.computer : Icons.meeting_room_outlined, size: 14, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text(
                              labRoom,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                          if (semester.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.school_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              "Sem $semester",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Highlighted Pipe-Delimited Summary Bar (Requirement 4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isLab
                          ? "$tRange12  |  $subjectName  |  ${batchName ?? 'Batch Not Assigned'}  |  $facultyName  |  ${labRoom.isNotEmpty ? labRoom : 'Lab'}"
                          : "$tRange12  |  $subjectName  |  $facultyName  |  ${labRoom.isNotEmpty ? labRoom : 'Room'}",
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // OFFICIAL TIMETABLE GRID VIEW (100% Exact Parity with TimetableDetailScreen)
  // ===========================================================================
  Widget _buildTimetableGridCard(List<TimeTableSlot> slots) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildFixedTemplateGrid(context, slots, availableWidth: constraints.maxWidth),
          );
        },
      ),
    );
  }

  Widget _buildFixedTemplateGrid(
    BuildContext context,
    List<TimeTableSlot> slots, {
    double? availableWidth,
  }) {
    final fixedColsWidth = _dayColWidth + _lunchColWidth;
    final double remainingWidth = (availableWidth != null && availableWidth > fixedColsWidth)
        ? (availableWidth - fixedColsWidth)
        : (6 * _baseSlotWidth);
    final double slotWidth = (remainingWidth / 6.0).clamp(135.0, 320.0);
    final double totalWidth = math.max(availableWidth ?? 0, fixedColsWidth + (6 * slotWidth));
    final double totalHeight = _headerHeight + (_rowHeight * 6);

    return SizedBox(
      height: totalHeight,
      width: totalWidth,
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeaderRow(_templateColumns, slotWidth),
              ...["MON", "TUE", "WED", "THU", "FRI", "SAT"].asMap().entries.map(
                (e) {
                  return _buildDayRow(context, e.value, e.key, _templateColumns, slots, slotWidth);
                },
              ),
            ],
          ),
          ..._buildOverlays(_templateColumns, totalHeight, slotWidth),
        ],
      ),
    );
  }

  List<Widget> _buildOverlays(
    List<Map<String, dynamic>> columns,
    double height,
    double slotWidth,
  ) {
    List<Widget> overlays = [];
    double currentX = _dayColWidth;
    for (var col in columns) {
      double width = slotWidth;
      if (col['type'] == 'BREAK') width = _breakColWidth;
      if (col['type'] == 'LUNCH') width = _lunchColWidth;
      if (col['type'] == 'BREAK' || col['type'] == 'LUNCH') {
        overlays.add(
          Positioned(
            left: currentX,
            top: _headerHeight,
            child: _buildVerticalBar(
              col['label'] as String,
              width,
              height - _headerHeight,
              const Color(0xFFFEF3C7),
            ),
          ),
        );
      }
      currentX += width;
    }
    return overlays;
  }

  Widget _buildVerticalBar(
    String text,
    double width,
    double height,
    Color color,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: const Text(
              "LUNCH",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: Color(0xFF92400E),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "BREAK",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 9,
              color: Color(0xFFB45309),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(List<Map<String, dynamic>> columns, double slotWidth) {
    return Row(
      children: [
        _buildFixedHeaderCell("TIME", width: _dayColWidth),
        ...columns.map((col) {
          double width = slotWidth;
          if (col['type'] == 'BREAK') width = _breakColWidth;
          if (col['type'] == 'LUNCH') {
            return _buildLunchHeaderCell(_lunchColWidth);
          }
          return _buildHeaderCell(col['start'] as String, col['end'] as String, width);
        }),
      ],
    );
  }

  Widget _buildLunchHeaderCell(double width) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "LUNCH",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF92400E),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 2),
          Text(
            "13:30-14:00",
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF78350F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String start, String end, double width) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Text(
        "$start\nTo\n$end",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF1E293B),
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildFixedHeaderCell(String text, {required double width}) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF0F172A),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDayRow(
    BuildContext context,
    String day,
    int idx,
    List<Map<String, dynamic>> columns,
    List<TimeTableSlot> allSlots,
    double slotWidth,
  ) {
    return Container(
      height: _rowHeight,
      color: idx % 2 == 0 ? Colors.white : Colors.grey[50],
      child: Row(
        children: [
          _buildDayCell(day),
          ..._buildRowCells(context, day, columns, allSlots, slotWidth),
        ],
      ),
    );
  }

  Widget _buildDayCell(String day) {
    return Container(
      width: _dayColWidth,
      height: _rowHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Text(
        day,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
      ),
    );
  }

  static bool _timeMatches(String? t1, String? t2) {
    if (t1 == null || t2 == null) return false;
    String norm1 = t1.trim();
    String norm2 = t2.trim();
    if (norm1.length == 4 && norm1.indexOf(':') == 1) norm1 = '0$norm1';
    if (norm2.length == 4 && norm2.indexOf(':') == 1) norm2 = '0$norm2';
    final len = math.min(5, math.min(norm1.length, norm2.length));
    return norm1.substring(0, len) == norm2.substring(0, len);
  }

  static int _compareTime(String t1, String t2) {
    String norm1 = t1.trim();
    String norm2 = t2.trim();
    if (norm1.length == 4 && norm1.indexOf(':') == 1) norm1 = '0$norm1';
    if (norm2.length == 4 && norm2.indexOf(':') == 1) norm2 = '0$norm2';
    final sub1 = norm1.substring(0, math.min(5, norm1.length));
    final sub2 = norm2.substring(0, math.min(5, norm2.length));
    return sub1.compareTo(sub2);
  }

  List<Widget> _buildRowCells(
    BuildContext context,
    String day,
    List<Map<String, dynamic>> columns,
    List<TimeTableSlot> allSlots,
    double slotWidth,
  ) {
    List<Widget> cells = [];
    int i = 0;
    while (i < columns.length) {
      final col = columns[i];
      if (col['type'] == 'BREAK') {
        cells.add(SizedBox(width: _breakColWidth));
        i++;
        continue;
      }
      if (col['type'] == 'LUNCH') {
        cells.add(SizedBox(width: _lunchColWidth));
        i++;
        continue;
      }

      final cellSlots = allSlots.where(
        (s) => s.day.toUpperCase() == day.toUpperCase() && _timeMatches(s.startTime, col['start'] as String),
      ).toList();

      if (cellSlots.isNotEmpty) {
        final primarySlot = cellSlots.first;
        double mergeWidth = 0;
        int span = 0;
        for (int k = i; k < columns.length; k++) {
          double w = slotWidth;
          if (columns[k]['type'] == 'BREAK') w = _breakColWidth;
          if (columns[k]['type'] == 'LUNCH') w = _lunchColWidth;
          mergeWidth += w;
          span++;
          if (_compareTime(primarySlot.endTime, columns[k]['end'] as String) <= 0) {
            break;
          }
        }

        final tRange = "${primarySlot.startTime.substring(0, math.min(5, primarySlot.startTime.length))} - ${primarySlot.endTime.substring(0, math.min(5, primarySlot.endTime.length))}";
        cells.add(_buildClassCell(context, cellSlots, mergeWidth, day: day, timeRange: tRange));
        i += span;
      } else {
        cells.add(_buildEmptyCell(slotWidth));
        i++;
      }
    }
    return cells;
  }

  Widget _buildClassCell(
    BuildContext context,
    List<TimeTableSlot> slots,
    double width, {
    required String day,
    required String timeRange,
  }) {
    final hasBatches = slots.any((s) => s.isBatchWise || s.batches.isNotEmpty);
    List<_DisplayItem> items = [];

    if (hasBatches) {
      for (var s in slots) {
        if (s.batches.isNotEmpty) {
          final myBatches = s.batches.where((b) => _isAssignedToThisFaculty(b.facultyName)).toList();
          final listToUse = myBatches.isNotEmpty ? myBatches : s.batches;
          for (var b in listToUse) {
            items.add(_DisplayItem(
              subjectCode: (b.subjectCode != null && b.subjectCode!.isNotEmpty) ? b.subjectCode! : (s.subjectCode ?? 'Code'),
              subjectName: (b.subjectName != null && b.subjectName!.isNotEmpty) ? b.subjectName! : (s.subjectName ?? 'Subject'),
              facultyName: (b.facultyName != null && b.facultyName!.isNotEmpty) ? b.facultyName! : (s.facultyName ?? 'Faculty'),
              batchName: b.batchName,
              labRoom: b.labRoom,
              semester: s.semester?.toString(),
              credits: b.credits,
              theoryHours: b.theoryHours,
              practicalHours: b.practicalHours,
            ));
          }
        } else {
          items.add(_DisplayItem(
            subjectCode: s.subjectCode ?? 'Code',
            subjectName: s.subjectName ?? 'Subject',
            facultyName: s.facultyName ?? 'Faculty',
            batchName: s.batchName,
            labRoom: s.labRoom,
            semester: s.semester?.toString(),
            credits: s.credits,
            theoryHours: s.theoryHours,
            practicalHours: s.practicalHours,
          ));
        }
      }
    } else {
      for (var s in slots) {
        items.add(_DisplayItem(
          subjectCode: s.subjectCode ?? 'Code',
          subjectName: s.subjectName ?? 'Subject',
          facultyName: s.facultyName ?? 'Faculty',
          batchName: s.batchName,
          labRoom: s.labRoom,
          semester: s.semester?.toString(),
          credits: s.credits,
          theoryHours: s.theoryHours,
          practicalHours: s.practicalHours,
        ));
      }
    }

    final tooltipText = items.map((it) {
      final bStr = it.batchName != null && it.batchName!.isNotEmpty ? " [${it.batchName}]" : "";
      final rStr = it.labRoom.isNotEmpty ? " (Room: ${it.labRoom})" : "";
      return "$day $timeRange$bStr\n${it.subjectCode}: ${it.subjectName}\nFaculty: ${it.facultyName}$rStr";
    }).join("\n---\n");

    return Tooltip(
      message: tooltipText,
      padding: const EdgeInsets.all(8),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSlotDetailsDialog(context, day, timeRange, items),
          child: Container(
            width: width,
            height: _rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: _buildCellContent(items, width),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(List<_DisplayItem> items, double width) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (items.length == 1) {
      final item = items.first;
      final hasBatch = item.batchName != null && item.batchName!.isNotEmpty;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasBatch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
              ),
              child: Text(
                item.batchName!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF1D4ED8)),
              ),
            ),
          Text(
            item.subjectCode,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF13246E),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            item.subjectName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              color: Color(0xFF334155),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.facultyName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 9.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      );
    }

    // Multiple batches: side-by-side display for 2-hour lab slots
    if (width >= 230) {
      return Row(
        children: items.map((it) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13246E),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          it.batchName ?? "B",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          it.subjectCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF13246E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    it.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF334155)),
                  ),
                  Text(
                    it.facultyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                  ),
                  if (it.labRoom.isNotEmpty)
                    Text(
                      it.labRoom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.map((it) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (it.batchName != null && it.batchName!.isNotEmpty) ...[
                  Text(
                    "${it.batchName}: ",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF13246E)),
                  ),
                ],
                Expanded(
                  child: Text(
                    "${it.subjectCode} (${it.facultyName})",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyCell(double width) {
    return Container(
      width: width,
      height: _rowHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: Text(
        "—",
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showSlotDetailsDialog(
    BuildContext context,
    String day,
    String timeRange,
    List<_DisplayItem> items,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: Color(0xFF13246E), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$day Schedule Details",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    timeRange,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.map((it) {
              final isBatch = it.batchName != null && it.batchName!.isNotEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                it.subjectCode,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            if (it.semester != null && it.semester!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  "Sem ${it.semester}",
                                  style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (isBatch)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              it.batchName!,
                              style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      it.subjectName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          it.facultyName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                        if (it.labRoom.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.meeting_room, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            it.labRoom,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _DisplayItem {
  final String subjectCode;
  final String subjectName;
  final String facultyName;
  final String? batchName;
  final String labRoom;
  final String? semester;
  final int credits;
  final int theoryHours;
  final int practicalHours;

  _DisplayItem({
    required this.subjectCode,
    required this.subjectName,
    required this.facultyName,
    this.batchName,
    this.labRoom = '',
    this.semester,
    this.credits = 4,
    this.theoryHours = 3,
    this.practicalHours = 0,
  });
}
