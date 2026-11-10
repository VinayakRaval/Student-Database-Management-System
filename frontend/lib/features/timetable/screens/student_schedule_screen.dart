import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/timetable_model.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final Dio _dio = ApiClient().dio;

  bool _isLoading = true;
  String? _errorMessage;

  // Student academic context
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _selectedContext;
  List<int> _availableSemesters = [];
  int? _activeSemester;
  String? _activeAcademicYear;

  // Timetable
  TimeTable? _timetable;
  List<TimeTableSlot> _slots = [];
  bool _isGridView = true;

  final List<String> _daysOrder = const [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  final Map<String, String> _dayNames = const {
    'MON': 'Monday',
    'TUE': 'Tuesday',
    'WED': 'Wednesday',
    'THU': 'Thursday',
    'FRI': 'Friday',
    'SAT': 'Saturday',
  };

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
  }

  Future<void> _fetchTimetable({int? semester, String? academicYear}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{};
      if (semester != null) queryParams['semester'] = semester;
      if (academicYear != null) queryParams['academic_year'] = academicYear;

      final res = await _dio.get('/timetable/timetables/student/', queryParameters: queryParams);
      final data = res.data;

      if (data is Map) {
        final stu = data['student'] is Map ? Map<String, dynamic>.from(data['student'] as Map) : null;
        final ctx = data['selected_context'] is Map ? Map<String, dynamic>.from(data['selected_context'] as Map) : null;
        final sems = (data['available_semesters'] as List? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();

        TimeTable? tt;
        List<TimeTableSlot> parsedSlots = [];

        if (data['timetable'] is Map) {
          tt = TimeTable.fromMap(Map<String, dynamic>.from(data['timetable'] as Map));
          parsedSlots = tt.slots;
        } else if (data['results'] is List && (data['results'] as List).isNotEmpty) {
          final first = (data['results'] as List).first;
          if (first is Map) {
            tt = TimeTable.fromMap(Map<String, dynamic>.from(first));
            parsedSlots = tt.slots;
          }
        }

        setState(() {
          _studentData = stu;
          _selectedContext = ctx;
          _availableSemesters = sems;
          _activeSemester = ctx?['semester'] ?? stu?['current_semester'];
          _activeAcademicYear = ctx?['academic_year'] ?? stu?['current_academic_year'];
          _timetable = tt;
          _slots = parsedSlots;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Unexpected response format from timetable service.";
        });
      }
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.response?.data?['error']?.toString() ?? "Failed to connect to timetable service.";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentSem = _selectedContext?['is_current'] != false;
    final String deptName = _studentData?['department_name'] ?? _timetable?.departmentName ?? 'Computer Science and Engineering';
    final int semNo = _activeSemester ?? _timetable?.semesterNo ?? 6;
    final String ay = _activeAcademicYear ?? _timetable?.academicYearLabel ?? '2026–2027';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "My Timetable",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Timetable",
            onPressed: () => _fetchTimetable(semester: _activeSemester, academicYear: _activeAcademicYear),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1250),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Official Header Banner
                          _buildOfficialHeader(deptName, semNo, ay, isCurrentSem),

                          const SizedBox(height: 16),

                          // 2. Semester Switcher / History Pills & View Controls
                          _buildControlsBar(isCurrentSem, semNo),

                          const SizedBox(height: 16),

                          // 3. Timetable Content
                          if (_timetable == null || _slots.isEmpty)
                            _buildEmptyTimetableState(semNo, ay, deptName)
                          else if (_isGridView)
                            _buildTimetableGrid()
                          else
                            _buildTimetableList(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildOfficialHeader(String deptName, int semNo, String ay, bool isCurrentSem) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF13246E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13246E).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      deptName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "Approved Schedule",
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  "Semester $semNo • Academic Year $ay • Weekly Lecture & Laboratory Schedule",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if ((_selectedContext?['class_teacher_name'] ?? _timetable?.classTeacherName ?? _studentData?['class_teacher_name']) != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Class Teacher: ${_selectedContext?['class_teacher_name'] ?? _timetable?.classTeacherName ?? _studentData?['class_teacher_name']}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(bool isCurrentSem, int currentSem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Available Semesters Chips
          const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          const Text(
            "Semesters:",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _availableSemesters.map((s) {
                  final bool isSelected = s == _activeSemester;
                  final bool isCurrentStudentSem = s == _studentData?['current_semester'];

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Semester $s"),
                          if (isCurrentStudentSem) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFF047857),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Active",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF13246E) : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF13246E),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (val) {
                        if (val && s != _activeSemester) {
                          _fetchTimetable(semester: s);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Grid / List Toggle
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  color: _isGridView ? const Color(0xFF13246E) : const Color(0xFF94A3B8),
                  tooltip: "Grid View",
                  onPressed: () => setState(() => _isGridView = true),
                ),
                IconButton(
                  icon: const Icon(Icons.view_agenda_rounded, size: 18),
                  color: !_isGridView ? const Color(0xFF13246E) : const Color(0xFF94A3B8),
                  tooltip: "List View",
                  onPressed: () => setState(() => _isGridView = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid() {
    // Collect unique time slots
    final timeSlotsSet = <String>{};
    for (var s in _slots) {
      final st = s.startTime.length >= 5 ? s.startTime.substring(0, 5) : s.startTime;
      final et = s.endTime.length >= 5 ? s.endTime.substring(0, 5) : s.endTime;
      timeSlotsSet.add("$st - $et");
    }

    final timeSlots = timeSlotsSet.toList()..sort();

    // Group slots by Day and TimeSlot
    final Map<String, Map<String, List<TimeTableSlot>>> matrix = {};
    for (var d in _daysOrder) {
      matrix[d] = {};
      for (var ts in timeSlots) {
        matrix[d]![ts] = [];
      }
    }

    for (var s in _slots) {
      final d = s.day.toUpperCase();
      final st = s.startTime.length >= 5 ? s.startTime.substring(0, 5) : s.startTime;
      final et = s.endTime.length >= 5 ? s.endTime.substring(0, 5) : s.endTime;
      final slotKey = "$st - $et";
      if (matrix.containsKey(d) && matrix[d]!.containsKey(slotKey)) {
        matrix[d]![slotKey]!.add(s);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(175),
            columnWidths: const {
              0: FixedColumnWidth(100), // Day column
            },
            border: TableBorder.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
            children: [
              // Header Row: Days + Time Slots
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    child: Center(
                      child: Text(
                        "DAY / TIME",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  ...timeSlots.map((ts) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        child: Center(
                          child: Text(
                            ts,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)),
                          ),
                        ),
                      )),
                ],
              ),

              // Data Rows for each Day
              ..._daysOrder.map((day) {
                final daySlots = matrix[day] ?? {};
                final hasAnyClass = daySlots.values.any((list) => list.isNotEmpty);

                return TableRow(
                  children: [
                    // Day Cell
                    Container(
                      height: 110,
                      color: const Color(0xFFF8FAFC),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            _dayNames[day] ?? '',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    // Time Slot Cells
                    ...timeSlots.map((ts) {
                      final slotsInCell = daySlots[ts] ?? [];
                      if (slotsInCell.isEmpty) {
                        return Container(
                          height: 110,
                          alignment: Alignment.center,
                          child: Text(
                            hasAnyClass ? "—" : "No Class",
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          ),
                        );
                      }

                      return Container(
                        height: 110,
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: slotsInCell.map((slot) => _buildGridSlotCell(slot)).toList(),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridSlotCell(TimeTableSlot slot) {
    final subCode = slot.subjectCode ?? 'SUB';
    final subName = slot.subjectName ?? 'Subject';
    final facName = slot.facultyName ?? 'Faculty';
    final isLab = slot.isBatchWise || slot.batches.isNotEmpty || subCode.toUpperCase().endsWith('L');
    final room = slot.labRoom.isNotEmpty ? slot.labRoom : "CS-301";

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: isLab ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLab ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subCode,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLab ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isLab ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isLab ? "LAB" : "TH",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isLab ? const Color(0xFF1E40AF) : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              subName,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              facName,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                const Icon(Icons.room_outlined, size: 10, color: Color(0xFF64748B)),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    room,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLab && slot.batchName != null && slot.batchName!.isNotEmpty) ...[
                  Text(
                    slot.batchName!,
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableList() {
    return Column(
      children: _daysOrder.map((day) {
        final daySlots = _slots.where((s) => s.day.toUpperCase() == day).toList();
        if (daySlots.isEmpty) return const SizedBox.shrink();

        daySlots.sort((a, b) => a.startTime.compareTo(b.startTime));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Text(
                      _dayNames[day] ?? day,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13246E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${daySlots.length} sessions",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: daySlots.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final slot = daySlots[idx];
                  final subCode = slot.subjectCode ?? 'SUB';
                  final subName = slot.subjectName ?? 'Subject';
                  final facName = slot.facultyName ?? 'Faculty';
                  final isLab = slot.isBatchWise || slot.batches.isNotEmpty || subCode.toUpperCase().endsWith('L');
                  final st = slot.startTime.length >= 5 ? slot.startTime.substring(0, 5) : slot.startTime;
                  final et = slot.endTime.length >= 5 ? slot.endTime.substring(0, 5) : slot.endTime;
                  final room = slot.labRoom.isNotEmpty ? slot.labRoom : "CS-301";

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLab ? const Color(0xFFF0F7FF) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13246E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$st - $et",
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    subCode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isLab ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    facName,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.room_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    room,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyTimetableState(int semNo, String ay, String deptName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No approved timetable is available for your current semester yet.",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Department of $deptName has not yet published an approved timetable for Semester $semNo ($ay).",
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Check Again"),
            onPressed: () => _fetchTimetable(semester: semNo, academicYear: ay),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? "Unable to load timetable",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
              onPressed: () => _fetchTimetable(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
