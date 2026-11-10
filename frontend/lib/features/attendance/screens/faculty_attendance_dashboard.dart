import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/app_pagination_bar.dart';
import '../../timetable/providers/timetable_provider.dart';

class _AttendancePastelTheme {
  final Color bg;
  final Color border;
  final Color iconBg;
  final IconData icon;

  const _AttendancePastelTheme({
    required this.bg,
    required this.border,
    required this.iconBg,
    required this.icon,
  });
}

class _AttendanceTabItem {
  final String label;
  final IconData icon;
  const _AttendanceTabItem(this.label, this.icon);
}

final List<_AttendancePastelTheme> _attendancePastelThemes = const [
  _AttendancePastelTheme(
    bg: Color(0xFFEFF6FF), // Blue
    border: Color(0xFFBFDBFE),
    iconBg: Color(0xFF3B82F6),
    icon: Icons.menu_book_rounded,
  ),
  _AttendancePastelTheme(
    bg: Color(0xFFF0FDF4), // Green
    border: Color(0xFFBBF7D0),
    iconBg: Color(0xFF22C55E),
    icon: Icons.code_rounded,
  ),
  _AttendancePastelTheme(
    bg: Color(0xFFFFF7ED), // Orange
    border: Color(0xFFFED7AA),
    iconBg: Color(0xFFF97316),
    icon: Icons.hub_rounded,
  ),
  _AttendancePastelTheme(
    bg: Color(0xFFFAF5FF), // Purple
    border: Color(0xFFE9D5FF),
    iconBg: Color(0xFFA855F7),
    icon: Icons.psychology_rounded,
  ),
  _AttendancePastelTheme(
    bg: Color(0xFFFFF1F2), // Rose
    border: Color(0xFFFECDD3),
    iconBg: Color(0xFFF43F5E),
    icon: Icons.terminal_rounded,
  ),
  _AttendancePastelTheme(
    bg: Color(0xFFF0FDFA), // Teal
    border: Color(0xFF99F6E4),
    iconBg: Color(0xFF14B8A6),
    icon: Icons.devices_rounded,
  ),
];

class FacultyAttendanceDashboard extends ConsumerStatefulWidget {
  const FacultyAttendanceDashboard({super.key});

  @override
  ConsumerState<FacultyAttendanceDashboard> createState() =>
      _FacultyAttendanceDashboardState();
}

class _FacultyAttendanceDashboardState
    extends ConsumerState<FacultyAttendanceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Schedule Tab State ---
  List<Map<String, dynamic>> _allSlots = [];
  bool _isLoadingSchedule = true;
  String _selectedFilter = 'ALL';
  String _scheduleSearchQuery = '';
  String? _selectedFaculty;
  final TextEditingController _scheduleSearchCtrl = TextEditingController();

  final List<String> _weekDays = const [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  // --- Subject Attendance Tab State ---
  List<Map<String, dynamic>> _professorSubjects = [];
  int? _selectedSubjectId;
  Map<String, dynamic>? _selectedSubject;
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingSubjectStudents = false;
  bool _isSavingAttendance = false;
  String? _subjectAttendanceError;
  bool _isAlreadyRecorded = false;
  int? _subjectSessionId;
  bool _isSubjectScheduledToday = true;
  String? _subjectNotScheduledReason;
  bool _hasSubjectApprovedExtra = false;
  int? _subjectExtraClassId;

  bool get _isPastDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isBefore(today);
  }

  List<Map<String, dynamic>> _eligibleStudents = [];
  String _studentSearchQuery = '';
  final TextEditingController _studentSearchCtrl = TextEditingController();

  // --- Lab Attendance Tab State ---
  List<Map<String, dynamic>> _labBatches = [];
  int? _selectedLabSubjectId;
  Map<String, dynamic>? _selectedLabSubject;
  int? _selectedLabBatchId;
  Map<String, dynamic>? _selectedLabBatch;
  DateTime _selectedLabDate = DateTime.now();
  bool _isLoadingLabStudents = false;
  bool _isSavingLabAttendance = false;
  String? _labAttendanceError;
  bool _isLabAlreadyRecorded = false;
  int? _labSessionId;
  bool _isLabScheduledToday = true;
  String? _labNotScheduledReason;
  bool _hasLabApprovedExtra = false;
  int? _labExtraClassId;

  bool get _isLabPastDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedLabDate.year, _selectedLabDate.month, _selectedLabDate.day);
    return selected.isBefore(today);
  }

  List<Map<String, dynamic>> _labStudents = [];
  String _labStudentSearchQuery = '';
  final TextEditingController _labStudentSearchCtrl = TextEditingController();

  // --- Extra Classes State ---
  List<Map<String, dynamic>> _extraClasses = [];
  bool _isLoadingExtraClasses = false;
  String? _extraClassError;

  // --- Shortage Report Tab State ---
  double _shortageThreshold = 75.0;
  int? _shortageSubjectFilter;
  bool _isLoadingShortage = false;
  List<Map<String, dynamic>> _shortageList = [];
  String _shortageSearchQuery = '';
  final TextEditingController _shortageSearchCtrl = TextEditingController();

  // --- Academic Years and Filtering State ---
  List<Map<String, dynamic>> _academicYears = [];

  // Theory Attendance Filters
  String _theorySubjectSearch = '';
  final TextEditingController _theorySubjectSearchCtrl = TextEditingController();
  String? _selectedTheoryAcademicYear;
  String? _selectedTheorySemester;

  // Lab Attendance Filters
  String _labBatchSearch = '';
  final TextEditingController _labBatchSearchCtrl = TextEditingController();
  String? _selectedLabAcademicYear;
  String? _selectedLabSemester;

  // Shortage Report Filters
  String? _shortageAcademicYear;
  String? _shortageSemester;
  int _shortageCurrentPage = 1;
  final int _shortagePageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAcademicYears();
      _loadSchedule();
      _loadProfessorSubjects();
      _loadLabBatches();
      _loadShortageReport();
      _loadExtraClasses();
    });
  }

  Future<void> _loadAcademicYears() async {
    try {
      final dio = ApiClient().dio;
      final ayRes = await dio.get('/academics/academic-years/');
      final List rawAy = ayRes.data is List ? ayRes.data : [];
      if (mounted) {
        setState(() {
          _academicYears = rawAy.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scheduleSearchCtrl.dispose();
    _studentSearchCtrl.dispose();
    _labStudentSearchCtrl.dispose();
    _shortageSearchCtrl.dispose();
    _theorySubjectSearchCtrl.dispose();
    _labBatchSearchCtrl.dispose();
    super.dispose();
  }

  String get _todayDay =>
      DateFormat('EEE').format(DateTime.now()).toUpperCase();

  // ==========================================
  //  1. LOAD PROFESSOR SUBJECTS & ATTENDANCE
  // ==========================================
  Future<void> _loadProfessorSubjects() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/subjects/professor/subjects/');
      final List raw = res.data is List ? res.data : [];
      final subjects = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (mounted) {
        setState(() {
          _professorSubjects = subjects;
          if (subjects.isNotEmpty && _selectedSubjectId == null) {
            _selectedSubjectId = (subjects.first['id'] ?? subjects.first['subject_id']) as int;
            _selectedSubject = subjects.first;
          }
          final labSubs = subjects.where((s) =>
            s['has_lab'] == true ||
            s['subject_type']?.toString().toUpperCase() == 'LAB' ||
            s['subject_type']?.toString().toUpperCase() == 'BOTH'
          ).toList();
          if (labSubs.isNotEmpty && _selectedLabSubjectId == null) {
            _selectedLabSubjectId = (labSubs.first['id'] ?? labSubs.first['subject_id']) as int;
            _selectedLabSubject = labSubs.first;
          }
        });

        if (_selectedSubjectId != null) {
          _loadSubjectStudents(_selectedSubjectId!, _selectedDate);
        }
        _loadLabBatches();
      }
    } catch (e) {
      debugPrint("Error loading professor subjects: $e");
    }
  }

  Future<void> _loadSubjectStudents(int subjectId, DateTime date) async {
    setState(() {
      _isLoadingSubjectStudents = true;
      _subjectAttendanceError = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      final dio = ApiClient().dio;
      final res = await dio.get(
        '/attendance/fetch_students_for_subject/',
        queryParameters: {
          'subject_id': subjectId,
          'date': dateStr,
        },
      );

      final data = Map<String, dynamic>.from(res.data as Map);
      final rawStudents = data['students'] is List ? (data['students'] as List) : [];
      final students = rawStudents.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      students.sort((a, b) => (a['usn']?.toString() ?? '').compareTo(b['usn']?.toString() ?? ''));

      if (mounted) {
        setState(() {
          _eligibleStudents = students;
          _isAlreadyRecorded = data['is_already_recorded'] == true;
          _subjectSessionId = data['session_id'];
          _isSubjectScheduledToday = data['is_scheduled_today'] ?? true;
          _subjectNotScheduledReason = data['not_scheduled_reason'];
          _hasSubjectApprovedExtra = data['has_approved_extra'] == true;
          _subjectExtraClassId = data['extra_class_id'];
          _isLoadingSubjectStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subjectAttendanceError = "Failed to load eligible students: $e";
          _isLoadingSubjectStudents = false;
        });
      }
    }
  }

  Future<void> _saveSubjectAttendance() async {
    if (_selectedSubjectId == null || _eligibleStudents.isEmpty) return;

    // Rule 3 Validation: Ensure date is not in future
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selectedOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (selectedOnly.isAfter(todayOnly)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Cannot mark attendance for future dates."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedOnly.isBefore(todayOnly)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Previous day attendance cannot be modified or added. Past attendance is strictly read-only."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Timetable Schedule check for today
    if (!_isPastDate && !_isSubjectScheduledToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_subjectNotScheduledReason ?? "No class or lab session is scheduled for today."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Rule 4 Validation: Ensure all eligible students have a valid status
    for (final st in _eligibleStudents) {
      final status = st['status']?.toString();
      if (status != 'Present' && status != 'Absent') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Missing status for student: ${st['name']} (${st['usn']})"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSavingAttendance = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final recordsPayload = _eligibleStudents.map((s) => {
      'student_id': s['id'],
      'status': s['status'] ?? 'Present',
    }).toList();

    try {
      final dio = ApiClient().dio;
      final Map<String, dynamic> postData = {
        'subject_id': _selectedSubjectId,
        'date': dateStr,
        'records': recordsPayload,
      };
      if (_hasSubjectApprovedExtra && _subjectExtraClassId != null) {
        postData['extra_class_id'] = _subjectExtraClassId;
      }
      await dio.post(
        '/attendance/save_subject_attendance/',
        data: postData,
      );

      if (mounted) {
        setState(() {
          _isSavingAttendance = false;
          _isAlreadyRecorded = true;
        });

        final presentCount = _eligibleStudents.where((s) => s['status'] == 'Present').length;
        final absentCount = _eligibleStudents.length - presentCount;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Attendance Saved! Present: $presentCount | Absent: $absentCount",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );

        // Refresh shortage report in background
        _loadShortageReport();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingAttendance = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save attendance: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markAllStudents(String status) {
    setState(() {
      for (var s in _eligibleStudents) {
        s['status'] = status;
      }
    });
  }

  // ==========================================
  //  LAB BATCH ATTENDANCE METHODS
  // ==========================================
  List<Map<String, dynamic>> get _assignedLabSubjects {
    return _professorSubjects.where((s) {
      return s['has_lab'] == true ||
          s['subject_type']?.toString().toUpperCase() == 'LAB' ||
          s['subject_type']?.toString().toUpperCase() == 'BOTH';
    }).toList();
  }

  void _onLabSubjectChanged(int newSubjectId) {
    if (newSubjectId == _selectedLabSubjectId) return;
    setState(() {
      _selectedLabSubjectId = newSubjectId;
      final found = _assignedLabSubjects.where((s) => (s['id'] ?? s['subject_id']) == newSubjectId).toList();
      _selectedLabSubject = found.isNotEmpty ? found.first : null;
      if (_selectedLabSubject != null) {
        final subSem = (_selectedLabSubject!['semester_name'] ?? _selectedLabSubject!['semester'] ?? '').toString();
        if (subSem.isNotEmpty && _selectedLabSemester != null && _selectedLabSemester != subSem) {
          _selectedLabSemester = subSem;
        }
      }
      _selectedLabBatchId = null;
      _selectedLabBatch = null;
      _labStudents = [];
    });
    _loadLabBatches();
  }

  Future<void> _loadLabBatches() async {
    try {
      if (_assignedLabSubjects.isNotEmpty && _selectedLabSubjectId == null) {
        final firstLab = _assignedLabSubjects.first;
        _selectedLabSubjectId = (firstLab['id'] ?? firstLab['subject_id']) as int;
        _selectedLabSubject = firstLab;
      }

      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{
        'assigned_only': 'true',
      };
      if (_selectedLabSubjectId != null) {
        queryParams['subject_id'] = _selectedLabSubjectId;
      }
      final res = await dio.get('/attendance/batches/', queryParameters: queryParams);
      final List raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      final batches = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (mounted) {
        setState(() {
          _labBatches = batches;
          if (batches.isNotEmpty) {
            if (_selectedLabBatchId == null || !batches.any((b) => b['id'] == _selectedLabBatchId)) {
              _selectedLabBatchId = batches.first['id'] as int;
              _selectedLabBatch = batches.first;
            } else {
              _selectedLabBatch = batches.firstWhere((b) => b['id'] == _selectedLabBatchId);
            }
          } else {
            _selectedLabBatchId = null;
            _selectedLabBatch = null;
            _labStudents = [];
          }
        });

        if (_selectedLabBatchId != null) {
          _loadLabBatchStudents(_selectedLabBatchId!, _selectedLabDate);
        }
      }
    } catch (e) {
      debugPrint("Error loading lab batches: $e");
    }
  }

  Future<void> _loadLabBatchStudents(int batchId, DateTime date) async {
    setState(() {
      _isLoadingLabStudents = true;
      _labAttendanceError = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      final dio = ApiClient().dio;
      final qParams = <String, dynamic>{
        'batch_id': batchId,
        'date': dateStr,
      };
      if (_selectedLabSubjectId != null) {
        qParams['subject_id'] = _selectedLabSubjectId;
      }
      final res = await dio.get(
        '/attendance/fetch_students_for_lab_batch/',
        queryParameters: qParams,
      );

      final data = Map<String, dynamic>.from(res.data as Map);
      final rawStudents = data['students'] is List ? (data['students'] as List) : [];
      final students = rawStudents.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      students.sort((a, b) => (a['usn']?.toString() ?? '').compareTo(b['usn']?.toString() ?? ''));

      if (mounted) {
        setState(() {
          if (data['batch'] != null && data['batch'] is Map) {
            final bData = Map<String, dynamic>.from(data['batch'] as Map);
            _selectedLabBatch = {
              ...?_selectedLabBatch,
              ...bData,
            };
          }
          _labStudents = students;
          _isLabAlreadyRecorded = data['is_already_recorded'] == true;
          _labSessionId = data['session_id'];
          _isLabScheduledToday = data['is_scheduled_today'] ?? true;
          _labNotScheduledReason = data['not_scheduled_reason'];
          _hasLabApprovedExtra = data['has_approved_extra'] == true;
          _labExtraClassId = data['extra_class_id'];
          _isLoadingLabStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _labAttendanceError = "Failed to load lab batch students: $e";
          _isLoadingLabStudents = false;
        });
      }
    }
  }

  Future<void> _saveLabAttendance() async {
    if (_selectedLabBatchId == null || _labStudents.isEmpty) return;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selectedOnly = DateTime(_selectedLabDate.year, _selectedLabDate.month, _selectedLabDate.day);
    if (selectedOnly.isAfter(todayOnly)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Cannot mark lab attendance for future dates."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedOnly.isBefore(todayOnly)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Past date lab attendance is strictly read-only."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Timetable Schedule check for today
    if (!_isLabPastDate && !_isLabScheduledToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_labNotScheduledReason ?? "No class or lab session is scheduled for today."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingLabAttendance = true);

    try {
      final dio = ApiClient().dio;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedLabDate);

      final Map<String, dynamic> payload = {
        'batch_id': _selectedLabBatchId,
        if (_selectedLabSubjectId != null) 'subject_id': _selectedLabSubjectId,
        'date': dateStr,
        'session_count': 1,
        'records': _labStudents.map((s) => {
          'student_id': s['id'],
          'status': s['status'] ?? 'Present',
        }).toList(),
      };
      if (_hasLabApprovedExtra && _labExtraClassId != null) {
        payload['extra_class_id'] = _labExtraClassId;
      }

      final res = await dio.post('/attendance/save_lab_attendance/', data: payload);
      final respData = res.data is Map ? (res.data as Map) : {};

      if (mounted) {
        setState(() {
          _isSavingLabAttendance = false;
          _isLabAlreadyRecorded = true;
        });

        final present = respData['present_count'] ?? 0;
        final absent = respData['absent_count'] ?? 0;
        final batchName = _selectedLabBatch?['name'] ?? 'Batch';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Lab Attendance Saved for $batchName! Present: $present | Absent: $absent.",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );

        _loadLabBatchStudents(_selectedLabBatchId!, _selectedLabDate);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingLabAttendance = false);
        String errMsg = "Failed to save lab attendance: $e";
        if (e is DioException && e.response?.data is Map && e.response?.data['error'] != null) {
          errMsg = e.response?.data['error'];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _markAllLabStudents(String status) {
    setState(() {
      for (var s in _labStudents) {
        s['status'] = status;
      }
    });
  }

  // ==========================================
  //  ATTENDANCE CORRECTION REQUEST DIALOG
  // ==========================================
  Future<void> _showCorrectionRequestDialog(
      Map<String, dynamic> student, int? sessionId, bool isLab) async {
    final currentStatus = student['status']?.toString() ?? 'Present';
    String requestedStatus = currentStatus == 'Present' ? 'Absent' : 'Present';
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    final subjectName = isLab
        ? (_selectedLabBatch?['subject_code'] != null
            ? "${_selectedLabBatch!['subject_code']} - ${_selectedLabBatch!['name']}"
            : "Lab Batch")
        : (_selectedSubject?['subject_code'] != null
            ? "${_selectedSubject!['subject_code']} - ${_selectedSubject!['subject_name']}"
            : "Subject");
    final sessionDate = isLab ? _selectedLabDate : _selectedDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: Colors.orange.shade800),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Request Attendance Correction",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Past attendance is read-only. Submit this correction request with mandatory reason for HOD review.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Student: ${student['name']} (${student['usn']})",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF13246E)),
                        ),
                        const SizedBox(height: 4),
                        Text("Subject: $subjectName", style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                            "Session Date: ${DateFormat('yyyy-MM-dd').format(sessionDate)}",
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text("Current Status: ", style: TextStyle(fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: currentStatus == 'Present'
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentStatus,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: currentStatus == 'Present'
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Requested Status:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: requestedStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Present', child: Text("Present")),
                      DropdownMenuItem(value: 'Absent', child: Text("Absent")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => requestedStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text("Reason for Correction (Required):",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          "State clearly why this attendance record needs modification...",
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "A valid reason is required for attendance correction."),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          final dio = ApiClient().dio;
                          await dio.post('/attendance/correction-requests/submit/', data: {
                            'student_id': student['id'],
                            'session_id': sessionId,
                            'requested_status': requestedStatus,
                            'reason': reason,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Attendance correction request submitted to HOD successfully! Status: Pending Approval."),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          String err = "Submission failed: $e";
                          if (e is DioException &&
                              e.response?.data is Map &&
                              e.response?.data['error'] != null) {
                            err = e.response?.data['error'];
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(err), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("SUBMIT TO HOD"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  //  EXTRA CLASS MANAGEMENT METHODS & TAB
  // ==========================================
  Future<void> _loadExtraClasses() async {
    setState(() => _isLoadingExtraClasses = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/attendance/extra-classes/');
      final raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      final List<Map<String, dynamic>> list =
          (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          _extraClasses = list;
          _isLoadingExtraClasses = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading extra classes: $e");
      if (mounted) {
        setState(() {
          _extraClassError = "Failed to load extra classes: $e";
          _isLoadingExtraClasses = false;
        });
      }
    }
  }

  Future<void> _cancelExtraClass(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Extra Class Request"),
        content: const Text("Are you sure you want to cancel this pending extra class request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("NO")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("YES, CANCEL"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = ApiClient().dio;
      await dio.post('/attendance/extra-classes/$id/cancel/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Extra class request cancelled successfully."),
            backgroundColor: Colors.blueGrey,
          ),
        );
        _loadExtraClasses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel request: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRequestExtraClassDialog() async {
    int? selectedSubId = _selectedSubjectId ??
        (_professorSubjects.isNotEmpty
            ? (_professorSubjects.first['id'] ?? _professorSubjects.first['subject_id']) as int?
            : null);
    String sessionType = 'THEORY';
    int? selectedBatchId;
    DateTime sessionDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
    int durationMinutes = 60;
    final roomController = TextEditingController();
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final batchesForSubject = _labBatches.where((b) {
            final subId = b['subject'] ?? b['subject_id'];
            return selectedSubId == null || subId == null || subId == selectedSubId;
          }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_alarm_rounded, color: Color(0xFF13246E), size: 24),
                ),
                const SizedBox(width: 12),
                const Text("Schedule Extra Class",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Schedule an extra theory or lab session outside regular timetable hours. Session is activated immediately and HOD will be automatically notified.",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    // Subject Dropdown
                    const Text("Assigned Subject:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selectedSubId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _professorSubjects.map((s) {
                        final id = (s['id'] ?? s['subject_id']) as int;
                        final code = s['subject_code'] ?? '';
                        final name = s['subject_name'] ?? '';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text("$code - $name", overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedSubId = val;
                          selectedBatchId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Session Type: Theory vs Lab
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text("Theory", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            value: 'THEORY',
                            groupValue: sessionType,
                            activeColor: const Color(0xFF13246E),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) setDialogState(() => sessionType = val);
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text("Laboratory", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            value: 'LAB',
                            groupValue: sessionType,
                            activeColor: const Color(0xFF13246E),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) setDialogState(() => sessionType = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    if (sessionType == 'LAB') ...[
                      const SizedBox(height: 6),
                      const Text("Select Lab Batch:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedBatchId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: batchesForSubject.isEmpty
                              ? "No lab batches found for this subject"
                              : "Choose batch",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: batchesForSubject.map((b) {
                          final id = b['id'] as int;
                          final bName = b['name'] ?? 'Batch';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(bName),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedBatchId = val),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Session Date Picker
                    const Text("Scheduled Date:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: sessionDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setDialogState(() => sessionDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 18, color: Color(0xFF13246E)),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(sessionDate),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time Range & Duration
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Start Time:",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1E293B),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF13246E)),
                                label: Text(startTime.format(context),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                onPressed: () async {
                                  final t = await showTimePicker(
                                      context: context, initialTime: startTime);
                                  if (t != null) {
                                    setDialogState(() => startTime = t);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("End Time:",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1E293B),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF13246E)),
                                label: Text(endTime.format(context),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                onPressed: () async {
                                  final t = await showTimePicker(
                                      context: context, initialTime: endTime);
                                  if (t != null) {
                                    setDialogState(() => endTime = t);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Room & Reason
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Room / Laboratory:",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              TextField(
                                controller: roomController,
                                decoration: InputDecoration(
                                  hintText: "e.g. Room 204 / Lab 3",
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Duration (mins):",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              TextFormField(
                                initialValue: "$durationMinutes",
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onChanged: (val) {
                                  final d = int.tryParse(val);
                                  if (d != null && d > 0) durationMinutes = d;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text("Reason for Extra Session (Required):",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "State academic reason (e.g. syllabus catch-up, lab test revision)",
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 1,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (selectedSubId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Please select a subject."),
                                backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (sessionType == 'LAB' && selectedBatchId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Please select a lab batch for lab session."),
                                backgroundColor: Colors.red),
                          );
                          return;
                        }
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("A valid reason is required for extra class request."),
                                backgroundColor: Colors.red),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        final startStr =
                            "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
                        final endStr =
                            "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";
                        final dateStr = DateFormat('yyyy-MM-dd').format(sessionDate);

                        final payload = <String, dynamic>{
                          'subject': selectedSubId,
                          'session_type': sessionType,
                          'date': dateStr,
                          'start_time': startStr,
                          'end_time': endStr,
                          'duration_minutes': durationMinutes,
                          'room': roomController.text.trim(),
                          'reason': reason,
                        };
                        if (sessionType == 'LAB' && selectedBatchId != null) {
                          payload['batch'] = selectedBatchId;
                        }

                        try {
                          final dio = ApiClient().dio;
                          await dio.post('/attendance/extra-classes/', data: payload);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Extra class scheduled successfully! HOD has been notified."),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadExtraClasses();
                            if (_selectedSubjectId != null) {
                              _loadSubjectStudents(_selectedSubjectId!, _selectedDate);
                            }
                            if (_selectedLabBatchId != null) {
                              _loadLabBatchStudents(_selectedLabBatchId!, _selectedLabDate);
                            }
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          String err = "Request failed: $e";
                          if (e is DioException &&
                              e.response?.data is Map &&
                              e.response?.data['error'] != null) {
                            err = e.response?.data['error'];
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("SUBMIT REQUEST"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExtraClassesTab() {
    final pendingCount = _extraClasses.where((e) => e['status'] == 'PENDING').length;
    final approvedCount = _extraClasses.where((e) => e['status'] == 'APPROVED').length;
    final completedCount = _extraClasses.where((e) => e['status'] == 'COMPLETED').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13246E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.more_time_rounded,
                            color: Color(0xFF13246E), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Extra Class Scheduling & Attendance",
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF13246E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Conduct additional theory or laboratory sessions outside regular timetable slots. HOD is automatically notified.",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13246E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Schedule Extra Class"),
                        onPressed: _showRequestExtraClassDialog,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // KPI Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Total Extra Classes",
                      value: "${_extraClasses.length}",
                      icon: Icons.layers_rounded,
                      color: const Color(0xFF13246E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Approved & Active",
                      value: "$approvedCount",
                      icon: Icons.check_circle_rounded,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Pending Review",
                      value: "$pendingCount",
                      icon: Icons.hourglass_top_rounded,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Completed",
                      value: "$completedCount",
                      icon: Icons.task_alt_rounded,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // List of Extra Classes
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Extra Class Requests & Attendance Status",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            onPressed: _loadExtraClasses,
                            tooltip: "Refresh Extra Classes",
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_extraClassError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(_extraClassError!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_isLoadingExtraClasses)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_extraClasses.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.event_available_rounded,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                "No extra classes requested yet.",
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Click '+ Schedule Extra Class' to conduct an extra session. HOD will be notified automatically.",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _extraClasses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final ec = _extraClasses[idx];
                            final status = (ec['status'] ?? 'PENDING').toString().toUpperCase();
                            final isLab = ec['session_type'] == 'LAB';
                            final isPending = status == 'PENDING';
                            final isApproved = status == 'APPROVED';

                            Color statusColor;
                            Color statusBg;
                            IconData statusIcon;

                            switch (status) {
                              case 'APPROVED':
                                statusColor = Colors.green.shade800;
                                statusBg = Colors.green.shade100;
                                statusIcon = Icons.check_circle_rounded;
                                break;
                              case 'COMPLETED':
                                statusColor = Colors.blue.shade800;
                                statusBg = Colors.blue.shade100;
                                statusIcon = Icons.task_alt_rounded;
                                break;
                              case 'REJECTED':
                                statusColor = Colors.red.shade800;
                                statusBg = Colors.red.shade100;
                                statusIcon = Icons.cancel_rounded;
                                break;
                              case 'CANCELLED':
                                statusColor = Colors.grey.shade700;
                                statusBg = Colors.grey.shade200;
                                statusIcon = Icons.block_rounded;
                                break;
                              default:
                                statusColor = Colors.orange.shade800;
                                statusBg = Colors.orange.shade100;
                                statusIcon = Icons.hourglass_top_rounded;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isLab
                                          ? Colors.purple.shade50
                                          : const Color(0xFF13246E).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isLab ? Icons.biotech_rounded : Icons.menu_book_rounded,
                                      color: isLab ? Colors.purple.shade700 : const Color(0xFF13246E),
                                      size: 22,
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
                                              "${ec['subject_code'] ?? ''} - ${ec['subject_name'] ?? 'Subject'}",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isLab
                                                    ? Colors.purple.shade100
                                                    : Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isLab
                                                    ? "LAB (${ec['batch_name'] ?? 'Batch'})"
                                                    : "THEORY",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isLab
                                                      ? Colors.purple.shade900
                                                      : Colors.blue.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded,
                                                size: 13, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${ec['date']} • ${ec['start_time']} - ${ec['end_time']} (${ec['duration_minutes']} min)",
                                              style: TextStyle(
                                                  fontSize: 12, color: Colors.grey.shade700),
                                            ),
                                            if (ec['room'] != null &&
                                                ec['room'].toString().isNotEmpty) ...[
                                              const SizedBox(width: 10),
                                              Icon(Icons.meeting_room_rounded,
                                                  size: 13, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text("${ec['room']}",
                                                  style: TextStyle(
                                                      fontSize: 12, color: Colors.grey.shade700)),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Reason: ${ec['reason'] ?? 'Not specified'}",
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey.shade800),
                                        ),
                                        if (ec['remarks'] != null &&
                                            ec['remarks'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            "HOD Remarks: ${ec['remarks']}",
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Color(0xFF13246E)),
                                          ),
                                        ],
                                        if (isApproved) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.green.shade300),
                                            ),
                                            child: Text(
                                              "Approved for attendance marking on ${ec['date']}",
                                              style: TextStyle(
                                                  color: Colors.green.shade900,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(statusIcon, color: statusColor, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              status,
                                              style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isPending) ...[
                                        const SizedBox(height: 8),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red.shade700,
                                            side: BorderSide(color: Colors.red.shade300),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: () => _cancelExtraClass(ec['id']),
                                          child: const Text("Cancel Request",
                                              style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  //  2. SHORTAGE REPORT
  // ==========================================
  Future<void> _loadShortageReport() async {
    setState(() => _isLoadingShortage = true);
    try {
      final dio = ApiClient().dio;
      final query = <String, dynamic>{
        'threshold': _shortageThreshold,
      };
      if (_shortageSubjectFilter != null) {
        query['subject_id'] = _shortageSubjectFilter;
      }

      final res = await dio.get('/attendance/shortage_report/', queryParameters: query);
      final data = Map<String, dynamic>.from(res.data as Map);
      final rawList = data['shortage_list'] is List ? (data['shortage_list'] as List) : [];
      final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      list.sort((a, b) => (a['usn']?.toString() ?? '').compareTo(b['usn']?.toString() ?? ''));

      if (mounted) {
        setState(() {
          _shortageList = list;
          _shortageCurrentPage = 1;
          _isLoadingShortage = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading shortage report: $e");
      if (mounted) setState(() => _isLoadingShortage = false);
    }
  }

  // ==========================================
  //  3. TIMETABLE SCHEDULE (Existing)
  // ==========================================
  Future<void> _loadSchedule() async {
    setState(() => _isLoadingSchedule = true);
    try {
      var details =
          await ref.read(timetableProvider.notifier).fetchScheduleDetails(personal: true);
      var slots = (details['slots'] as List<Map<String, dynamic>>?) ?? [];
      var assigned =
          (details['assigned_subjects'] as List<Map<String, dynamic>>?) ?? [];

      if (slots.isEmpty && assigned.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          details = await ref
              .read(timetableProvider.notifier)
              .fetchScheduleDetails(personal: true);
          slots = (details['slots'] as List<Map<String, dynamic>>?) ?? [];
          assigned =
              (details['assigned_subjects'] as List<Map<String, dynamic>>?) ?? [];
        }
      }

      if (mounted) {
        setState(() {
          _allSlots = slots;
          if (_professorSubjects.isEmpty && assigned.isNotEmpty) {
            _professorSubjects = assigned;
            if (_selectedSubjectId == null) {
              _selectedSubjectId = (assigned.first['id'] ?? assigned.first['subject_id']) as int?;
            }
          }

          final todayDay = _todayDay;
          final todaySlots =
              slots.where((s) => s['day'] == todayDay).toList();

          if (_selectedFilter == 'ALL' || _selectedFilter == 'TODAY') {
            if (todaySlots.isNotEmpty) {
              _selectedFilter = 'TODAY';
            } else {
              _selectedFilter = 'ALL';
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading faculty schedule: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingSchedule = false);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredSlots() {
    List<Map<String, dynamic>> filtered;

    if (_selectedFilter == 'TODAY') {
      final today = _todayDay;
      filtered = _allSlots.where((s) => s['day'] == today).toList();
    } else if (_selectedFilter == 'ALL') {
      filtered = List.from(_allSlots);
    } else {
      filtered = _allSlots.where((s) => s['day'] == _selectedFilter).toList();
    }

    if (_selectedFaculty != null && _selectedFaculty!.isNotEmpty) {
      filtered = filtered
          .where((s) => (s['faculty_name'] ?? '').toString() == _selectedFaculty)
          .toList();
    }

    if (_scheduleSearchQuery.trim().isNotEmpty) {
      final query = _scheduleSearchQuery.trim().toLowerCase();
      filtered = filtered.where((slot) {
        final name = (slot['subject_name'] ?? '').toString().toLowerCase();
        final code = (slot['subject_code'] ?? '').toString().toLowerCase();
        final branch = (slot['branch_name'] ?? '').toString().toLowerCase();
        final day = (slot['day'] ?? '').toString().toLowerCase();
        final fac = (slot['faculty_name'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            code.contains(query) ||
            branch.contains(query) ||
            day.contains(query) ||
            fac.contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      final dayA = _weekDays.indexOf((a['day'] ?? '').toString().toUpperCase());
      final dayB = _weekDays.indexOf((b['day'] ?? '').toString().toUpperCase());
      if (dayA != dayB) {
        return (dayA == -1 ? 99 : dayA).compareTo(dayB == -1 ? 99 : dayB);
      }
      final timeA = (a['start_time'] ?? '').toString();
      final timeB = (b['start_time'] ?? '').toString();
      return timeA.compareTo(timeB);
    });

    return filtered;
  }

  int _countForDay(String day) {
    return _allSlots
        .where((s) => (s['day'] ?? '').toString().toUpperCase() == day)
        .length;
  }

  String _formatTime(dynamic timeStr) {
    if (timeStr == null || timeStr.toString().isEmpty) return '';
    try {
      final parsed = DateFormat("HH:mm:ss").parse(timeStr.toString());
      return DateFormat("hh:mm a").format(parsed);
    } catch (_) {
      try {
        final parsed2 = DateFormat("HH:mm").parse(timeStr.toString());
        return DateFormat("hh:mm a").format(parsed2);
      } catch (_) {
        return timeStr.toString();
      }
    }
  }

  // ==========================================
  //  BUILD SCREEN
  // ==========================================
  Widget _buildTabPills() {
    final tabs = const [
      _AttendanceTabItem("Theory Attendance", Icons.person_rounded),
      _AttendanceTabItem("Lab Attendance", Icons.science_outlined),
      _AttendanceTabItem("Extra Classes", Icons.more_time_rounded),
      _AttendanceTabItem("Attendance Shortage (<75%)", Icons.warning_amber_rounded),
    ];

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final currentIdx = _tabController.index;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final isSelected = currentIdx == i;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(i);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF13246E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF13246E) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF13246E).withValues(alpha: 0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tabs[i].icon,
                          size: 16,
                          color: isSelected ? Colors.white : const Color(0xFF13246E),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Top Header & Stadium Tab Pills Bar (Image 2)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        children: const [
                          Text(
                            "Attendance",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF13246E),
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Faculty Attendance Management",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF13246E)),
                        tooltip: "Refresh Data",
                        onPressed: () {
                          if (_tabController.index == 0) {
                            if (_selectedSubjectId != null) {
                              _loadSubjectStudents(_selectedSubjectId!, _selectedDate);
                            } else {
                              _loadProfessorSubjects();
                            }
                          } else if (_tabController.index == 1) {
                            if (_selectedLabBatchId != null) {
                              _loadLabBatchStudents(_selectedLabBatchId!, _selectedLabDate);
                            } else {
                              _loadLabBatches();
                            }
                          } else if (_tabController.index == 2) {
                            _loadExtraClasses();
                          } else {
                            _loadShortageReport();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildTabPills(),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubjectAttendanceTab(),
                _buildLabAttendanceTab(),
                _buildExtraClassesTab(),
                _buildAttendanceShortageTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  TAB 1: SUBJECT ATTENDANCE (With Date Picker, Eligible Students, atomic save)
  // =========================================================================
  Widget _buildSubjectAttendanceTab() {
    if (_professorSubjects.isEmpty && !_isLoadingSubjectStudents) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                "No subjects assigned to your faculty profile.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Fetching Subjects"),
                onPressed: _loadProfessorSubjects,
              ),
            ],
          ),
        ),
      );
    }

    final filteredStudents = _eligibleStudents.where((s) {
      if (_studentSearchQuery.trim().isEmpty) return true;
      final q = _studentSearchQuery.trim().toLowerCase();
      final usn = (s['usn'] ?? '').toString().toLowerCase();
      final name = (s['name'] ?? '').toString().toLowerCase();
      return usn.contains(q) || name.contains(q);
    }).toList();

    final presentCount = _eligibleStudents.where((s) => s['status'] == 'Present').length;
    final absentCount = _eligibleStudents.length - presentCount;
    final percentage = _eligibleStudents.isNotEmpty
        ? (presentCount / _eligibleStudents.length * 100.0).toStringAsFixed(1)
        : "0.0";

    final formattedDateDisplay = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);

    final filteredTheorySubjects = _professorSubjects.where((sub) {
      if (_selectedTheorySemester != null) {
        final sem = (sub['semester_no'] ?? sub['semester'] ?? '').toString();
        if (sem != _selectedTheorySemester) return false;
      }
      if (_selectedTheoryAcademicYear != null) {
        final ay = (sub['academic_year'] ?? '').toString();
        if (ay != _selectedTheoryAcademicYear) return false;
      }
      if (_theorySubjectSearch.trim().isNotEmpty) {
        final q = _theorySubjectSearch.trim().toLowerCase();
        final name = (sub['subject_name'] ?? sub['name'] ?? '').toString().toLowerCase();
        final code = (sub['subject_code'] ?? sub['code'] ?? '').toString().toLowerCase();
        final dept = (sub['department_name'] ?? sub['department'] ?? '').toString().toLowerCase();
        return name.contains(q) || code.contains(q) || dept.contains(q);
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SELECT A SUBJECT CARD (Image 2)
              _buildTheorySubjectSelectionCard(filteredTheorySubjects),
              const SizedBox(height: 18),

              // 2. Attendance Session Controls Card (For Selected Subject)
              if (_selectedSubject != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected Subject Header & Status Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF13246E), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Selected: ${_selectedSubject!['subject_code']} - ${_selectedSubject!['subject_name']}",
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "Sem ${_selectedSubject!['semester'] ?? ''}${_selectedSubject!['department_name'] != null ? ' · ${_selectedSubject!['department_name']}' : ''}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isPastDate)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isAlreadyRecorded ? const Color(0xFFEFF6FF) : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _isAlreadyRecorded ? const Color(0xFF93C5FD) : Colors.amber.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_isAlreadyRecorded ? Icons.lock_clock_rounded : Icons.history_toggle_off_rounded,
                                        color: _isAlreadyRecorded ? const Color(0xFF1D4ED8) : Colors.amber.shade900, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isAlreadyRecorded ? "Past Date: Read-Only View" : "Past Date: Records Closed",
                                      style: TextStyle(
                                          color: _isAlreadyRecorded ? const Color(0xFF1E40AF) : Colors.amber.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            else if (_isAlreadyRecorded)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.shade400),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Recorded for Today (Editing Allowed)",
                                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fiber_new_rounded, color: Colors.blue, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      "New Attendance Session",
                                      style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                      // Attendance Date Selection Bar
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_month_rounded, color: Colors.orange, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Attendance Date (Required)",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                              Text(
                                formattedDateDisplay,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                            label: const Text("Select Date"),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2022, 1, 1),
                                lastDate: DateTime.now(), // Rule 3: Enforce no future dates
                                helpText: "SELECT ATTENDANCE DATE",
                              );
                              if (picked != null && picked != _selectedDate) {
                                setState(() => _selectedDate = picked);
                                if (_selectedSubjectId != null) {
                                  _loadSubjectStudents(_selectedSubjectId!, picked);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Warning Banner if not scheduled today
              if (!_isPastDate && !_isSubjectScheduledToday) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_busy_rounded, color: Colors.red.shade900, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "No class or lab session is scheduled for today.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subjectNotScheduledReason ??
                                  "According to the official active timetable, you do not have an approved slot or approved extra class for this subject today. Attendance entry is disabled.",
                              style: TextStyle(fontSize: 13, color: Colors.red.shade800, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_isPastDate && _hasSubjectApprovedExtra) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.purple.shade800, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Approved Extra Class Scheduled for Today: Attendance will be linked to this session.",
                          style: TextStyle(
                            color: Colors.purple.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Summary & Quick Action Bar
              Row(
                children: [
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Eligible Students",
                      value: "${_eligibleStudents.length}",
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF13246E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Present",
                      value: "$presentCount",
                      icon: Icons.check_circle_rounded,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Absent",
                      value: "$absentCount",
                      icon: Icons.cancel_rounded,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Attendance Rate",
                      value: "$percentage%",
                      icon: Icons.pie_chart_rounded,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Eligible Students Attendance Marking List
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Quick Action Buttons
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Eligible Students for this Subject & Semester",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Department & semester matched enrolled students",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green.shade700,
                                  side: BorderSide(color: Colors.green.shade600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.done_all_rounded, size: 16),
                                label: const Text("All Present"),
                                onPressed: (_eligibleStudents.isEmpty || (!_isPastDate && !_isSubjectScheduledToday))
                                    ? null
                                    : () => _markAllStudents('Present'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.remove_done_rounded, size: 16),
                                label: const Text("All Absent"),
                                onPressed: (_eligibleStudents.isEmpty || (!_isPastDate && !_isSubjectScheduledToday))
                                    ? null
                                    : () => _markAllStudents('Absent'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search Bar
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _studentSearchCtrl,
                          decoration: InputDecoration(
                            hintText: "Search student by USN or Name...",
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _studentSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _studentSearchCtrl.clear();
                                      setState(() => _studentSearchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onChanged: (val) => setState(() => _studentSearchQuery = val),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_isLoadingSubjectStudents)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF13246E))),
                        )
                      else if (_subjectAttendanceError != null)
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                                const SizedBox(height: 8),
                                Text(_subjectAttendanceError!, style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        )
                      else if (_eligibleStudents.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: const Text("No eligible active students found for this subject and semester.",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredStudents.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final st = filteredStudents[index];
                            final usn = st['usn']?.toString() ?? 'N/A';
                            final name = st['name']?.toString() ?? 'Student';
                            final sem = st['semester']?.toString() ?? '';
                            final dept = st['department_name']?.toString() ?? '';
                            final status = st['status']?.toString() ?? 'Present';
                            final isPresent = status == 'Present';

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isPresent
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    child: Icon(
                                      isPresent ? Icons.check : Icons.close,
                                      size: 18,
                                      color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
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
                                              usn,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF13246E),
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (dept.isNotEmpty || sem.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                child: Text(
                                                  "$sem${dept.isNotEmpty ? ' · $dept' : ''}",
                                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(name, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                                      ],
                                    ),
                                  ),
                                  // Status Badge or Toggle Buttons
                                  if (_isPastDate)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isPresent ? Colors.green.shade300 : Colors.red.shade300),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                size: 16,
                                                color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isPresent ? "Present (Recorded)" : "Absent (Recorded)",
                                                style: TextStyle(
                                                  color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF13246E),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                                          label: const Text("Request Correction", style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showCorrectionRequestDialog(st, _subjectSessionId, false),
                                        ),
                                      ],
                                    )
                                  else if (!_isSubjectScheduledToday)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        "No Session",
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() => st['status'] = 'Present');
                                            },
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isPresent ? Colors.green.shade600 : Colors.transparent,
                                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.check, size: 14, color: isPresent ? Colors.white : Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Present",
                                                    style: TextStyle(
                                                      color: isPresent ? Colors.white : Colors.grey.shade700,
                                                      fontWeight: isPresent ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              setState(() => st['status'] = 'Absent');
                                            },
                                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: !isPresent ? Colors.red.shade600 : Colors.transparent,
                                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.close, size: 14, color: !isPresent ? Colors.white : Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Absent",
                                                    style: TextStyle(
                                                      color: !isPresent ? Colors.white : Colors.grey.shade700,
                                                      fontWeight: !isPresent ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: 12,
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
                          },
                        ),
                      const SizedBox(height: 20),

                      // Save Attendance Button or Past Date Read-Only Indicator
                      if (_isPastDate)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isAlreadyRecorded ? const Color(0xFFF1F5F9) : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isAlreadyRecorded ? const Color(0xFFCBD5E1) : Colors.amber.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isAlreadyRecorded ? Icons.lock_clock_rounded : Icons.history_toggle_off_rounded,
                                color: _isAlreadyRecorded ? const Color(0xFF475569) : Colors.amber.shade900,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _isAlreadyRecorded
                                      ? "VIEWING PAST ATTENDANCE FOR ${DateFormat('dd MMM yyyy').format(_selectedDate).toUpperCase()} (READ-ONLY)"
                                      : "NO ATTENDANCE WAS RECORDED ON ${DateFormat('dd MMM yyyy').format(_selectedDate).toUpperCase()} (PAST DATES CLOSED)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _isAlreadyRecorded ? const Color(0xFF1E293B) : Colors.amber.shade900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!_isSubjectScheduledToday)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block_rounded, color: Colors.red.shade800, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  "NO SESSION SCHEDULED TODAY — ATTENDANCE ENTRY DISABLED",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.red.shade900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: (_isSavingAttendance || _eligibleStudents.isEmpty)
                                ? null
                                : _saveSubjectAttendance,
                            icon: _isSavingAttendance
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_rounded),
                            label: Text(
                              _isAlreadyRecorded
                                  ? "UPDATE ATTENDANCE FOR ${DateFormat('dd MMM yyyy').format(_selectedDate).toUpperCase()}"
                                  : "SAVE ATTENDANCE RECORDS",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTheorySubjectSelectionCard(List<Map<String, dynamic>> subjects) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Image 2)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              final headerLeft = Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13246E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Select a Subject",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF13246E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Choose a subject to view timetable slots and mark attendance",
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              );

              final headerControls = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth : 190,
                    height: 38,
                    child: TextField(
                      controller: _theorySubjectSearchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search subject...",
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _theorySubjectSearch = val),
                    ),
                  ),
                  _buildTheoryAYDropdown(),
                  _buildTheorySemDropdown(),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerLeft,
                    const SizedBox(height: 12),
                    headerControls,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  headerLeft,
                  headerControls,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // 2-Column Pastel Subjects Grid (Image 2)
          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                "No subjects match your search/filter.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isSingle = constraints.maxWidth < 650;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isSingle ? 1 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 92,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final sub = subjects[index];
                    final theme = _attendancePastelThemes[index % _attendancePastelThemes.length];
                    final subId = (sub['id'] ?? sub['subject_id']) as int;
                    final isSelected = _selectedSubjectId == subId;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSubjectId = subId;
                            _selectedSubject = sub;
                          });
                          _loadSubjectStudents(subId, _selectedDate);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF13246E) : theme.border,
                              width: isSelected ? 2.0 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? const Color(0xFF13246E).withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.02),
                                blurRadius: isSelected ? 6 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.iconBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(theme.icon, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      sub['subject_name'] ?? sub['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "${sub['subject_code'] ?? sub['code']} • Sem ${sub['semester_no'] ?? sub['semester']}${sub['department_name'] != null ? ' • ${sub['department_name']}' : ''}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blueGrey.shade200),
                                          ),
                                          child: Text(
                                            "Theory",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey.shade800,
                                            ),
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF13246E),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "Selected",
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? const Color(0xFF13246E) : Colors.white,
                                  border: Border.all(color: isSelected ? const Color(0xFF13246E) : const Color(0xFFE2E8F0)),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                                  size: isSelected ? 16 : 12,
                                  color: isSelected ? Colors.white : const Color(0xFF13246E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTheoryAYDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedTheoryAcademicYear,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          hint: const Text("All Academic Years", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
          onChanged: (val) => setState(() => _selectedTheoryAcademicYear = val),
        ),
      ),
    );
  }

  Widget _buildTheorySemDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedTheorySemester,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          hint: const Text("All Semesters", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text("All Semesters"),
            ),
            ...['1', '2', '3', '4', '5', '6', '7', '8'].map((sem) {
              return DropdownMenuItem<String?>(
                value: sem,
                child: Text("Sem $sem"),
              );
            }),
          ],
          onChanged: (val) => setState(() => _selectedTheorySemester = val),
        ),
      ),
    );
  }

  // =========================================================================
  //  TAB 2: LAB ATTENDANCE (Batch-Wise, Date Selection, Independent Roster)
  // =========================================================================
  Widget _buildLabAttendanceTab() {
    if (_labBatches.isEmpty && !_isLoadingLabStudents) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.biotech_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                "No laboratory batches assigned to your faculty profile.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                "Batches can be configured and assigned by the HOD from the Lab Batches page.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh Batches"),
                    onPressed: _loadLabBatches,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF13246E)),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text("Manage Lab Batches"),
                    onPressed: () => context.push('/faculty/lab-batches'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final filteredStudents = _labStudents.where((s) {
      if (_labStudentSearchQuery.trim().isEmpty) return true;
      final q = _labStudentSearchQuery.trim().toLowerCase();
      final usn = (s['usn'] ?? '').toString().toLowerCase();
      final name = (s['name'] ?? '').toString().toLowerCase();
      return usn.contains(q) || name.contains(q);
    }).toList();

    final presentCount = _labStudents.where((s) => s['status'] == 'Present').length;
    final absentCount = _labStudents.length - presentCount;
    final percentage = _labStudents.isNotEmpty
        ? (presentCount / _labStudents.length * 100.0).toStringAsFixed(1)
        : "0.0";

    final formattedDateDisplay = DateFormat('EEEE, dd MMMM yyyy').format(_selectedLabDate);

    final filteredLabBatches = _labBatches.where((b) {
      if (_selectedLabSemester != null) {
        final sem = (b['semester_name'] ?? b['semester_no'] ?? (b['semester'] is Map ? b['semester']['sem_number'] : b['semester']) ?? '').toString();
        if (sem != _selectedLabSemester) return false;
      }
      if (_selectedLabAcademicYear != null) {
        final ay = (b['academic_year_name'] ?? b['academic_year'] ?? '').toString();
        if (ay != _selectedLabAcademicYear) return false;
      }
      if (_labBatchSearch.trim().isNotEmpty) {
        final q = _labBatchSearch.trim().toLowerCase();
        final name = (b['name'] ?? '').toString().toLowerCase();
        final subName = (b['subject_name'] ?? '').toString().toLowerCase();
        final subCode = (b['subject_code'] ?? '').toString().toLowerCase();
        return name.contains(q) || subName.contains(q) || subCode.contains(q);
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SELECT A LAB BATCH CARD (Image 2 style)
              _buildLabBatchSelectionCard(filteredLabBatches),
              const SizedBox(height: 18),

              // 2. Controls Card: Selected Batch & Date Selection
              if (_selectedLabBatch != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.biotech_rounded, color: Color(0xFF13246E), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final selName = (_selectedLabBatch!['name'] ?? 'Batch').toString();
                                      final selSubName = (_selectedLabSubject?['subject_name'] ?? _selectedLabBatch!['subject_name'] ?? '').toString().trim();
                                      final selSubCode = (_selectedLabSubject?['subject_code'] ?? _selectedLabBatch!['subject_code'] ?? '').toString().trim();
                                      final selSem = _selectedLabSubject?['semester_name'] ?? _selectedLabSubject?['semester'] ?? _selectedLabBatch!['semester_name'] ?? _selectedLabBatch!['semester'];
                                      final selFaculty = (_selectedLabSubject?['faculty_name'] ?? _selectedLabBatch!['faculty_name'] ?? '').toString().trim();

                                      final selTitle = selSubName.isNotEmpty
                                          ? "Selected Batch: $selName - $selSubName"
                                          : "Selected Batch: $selName";

                                      final detailParts = <String>[];
                                      if (selSubCode.isNotEmpty) detailParts.add(selSubCode);
                                      if (selSem != null && selSem.toString().isNotEmpty) detailParts.add("Sem $selSem");
                                      if (selFaculty.isNotEmpty && selFaculty != "Unassigned") detailParts.add("Faculty: $selFaculty");

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selTitle,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (detailParts.isNotEmpty)
                                            Text(
                                              "Subject: ${detailParts.join(' • ')}",
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isLabPastDate)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isLabAlreadyRecorded ? const Color(0xFFEFF6FF) : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _isLabAlreadyRecorded ? const Color(0xFF93C5FD) : Colors.amber.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_isLabAlreadyRecorded ? Icons.lock_clock_rounded : Icons.history_toggle_off_rounded,
                                        color: _isLabAlreadyRecorded ? const Color(0xFF1D4ED8) : Colors.amber.shade900, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isLabAlreadyRecorded ? "Past Date: Read-Only View" : "Past Date: Records Closed",
                                      style: TextStyle(
                                          color: _isLabAlreadyRecorded ? const Color(0xFF1E40AF) : Colors.amber.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            else if (_isLabAlreadyRecorded)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                    SizedBox(width: 4),
                                    Text("Lab Attendance Marked Today",
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fiber_new_rounded, color: Colors.blue, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      "New Lab Session",
                                      style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Date Pickers Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: Colors.orange, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Attendance Date (Required)",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                ),
                                Text(
                                  formattedDateDisplay,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF13246E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                              label: const Text("Select Date", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedLabDate,
                                  firstDate: DateTime(now.year - 1),
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  setState(() => _selectedLabDate = picked);
                                  if (_selectedLabBatchId != null) {
                                    _loadLabBatchStudents(_selectedLabBatchId!, picked);
                                  }
                                }
                              },
                            ),
                          ],
                        ),

                      if (_isLabPastDate) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF1E40AF), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Viewing recorded lab attendance for a past date. Past attendance is strictly read-only to prevent backdated modifications.",
                                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_labAttendanceError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_labAttendanceError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Warning Banner if not scheduled today
              if (!_isLabPastDate && !_isLabScheduledToday) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_busy_rounded, color: Colors.red.shade900, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "No class or lab session is scheduled for today.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _labNotScheduledReason ??
                                  "According to the official active timetable, you do not have an approved slot or approved extra class for this laboratory batch today. Attendance entry is disabled.",
                              style: TextStyle(fontSize: 13, color: Colors.red.shade800, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_isLabPastDate && _hasLabApprovedExtra) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.purple.shade800, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Approved Extra Lab Batch Session Scheduled for Today: Attendance will be linked to this session.",
                          style: TextStyle(
                            color: Colors.purple.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Metrics Strip: Lab Batch Overview
              Row(
                children: [
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Batch Students",
                      value: "${_labStudents.length}",
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF13246E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Present",
                      value: "$presentCount",
                      icon: Icons.check_circle_rounded,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Absent",
                      value: "$absentCount",
                      icon: Icons.cancel_rounded,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attendanceMetricCard(
                      label: "Attendance %",
                      value: "$percentage%",
                      icon: Icons.pie_chart_rounded,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Batch Student Roster Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Controls
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${_selectedLabBatch?['name'] ?? 'Batch'} Student Roster",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Mark attendance for each assigned student in this lab batch for $formattedDateDisplay",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (!_isLabPastDate) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade800,
                                side: BorderSide(color: Colors.green.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.done_all_rounded, size: 16),
                              label: const Text("All Present"),
                              onPressed: (!_isLabScheduledToday) ? null : () => _markAllLabStudents('Present'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade800,
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.remove_done_rounded, size: 16),
                              label: const Text("All Absent"),
                              onPressed: (!_isLabScheduledToday) ? null : () => _markAllLabStudents('Absent'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search Box
                      TextField(
                        controller: _labStudentSearchCtrl,
                        decoration: InputDecoration(
                          hintText: "Search batch students by USN or Name...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onChanged: (val) {
                          setState(() => _labStudentSearchQuery = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Student List
                      if (_isLoadingLabStudents)
                        const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                      else if (_labStudents.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.people_alt_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text("No students currently assigned to this batch.", style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.group_add_rounded, size: 16),
                                  label: const Text("Assign Students on Lab Batches Page"),
                                  onPressed: () => context.push('/faculty/lab-batches'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredStudents.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final st = filteredStudents[idx];
                            final isPresent = st['status'] == 'Present';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.1),
                                    child: Text(
                                      "${idx + 1}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF13246E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          st['name'] ?? 'Student',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          "${st['usn'] ?? ''} • ${st['department_name'] ?? ''}",
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status Toggle Button / Badge
                                  if (_isLabPastDate)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: isPresent ? Colors.green.shade300 : Colors.red.shade300),
                                          ),
                                          child: Text(
                                            isPresent ? "PRESENT" : "ABSENT",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF13246E),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                                          label: const Text("Request Correction", style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showCorrectionRequestDialog(st, _labSessionId, true),
                                        ),
                                      ],
                                    )
                                  else if (!_isLabScheduledToday)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        "No Session",
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() => st['status'] = 'Present');
                                          },
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isPresent ? Colors.green : Colors.transparent,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isPresent ? Colors.green : Colors.grey.shade400),
                                            ),
                                            child: Text(
                                              "Present",
                                              style: TextStyle(
                                                color: isPresent ? Colors.white : Colors.black87,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            setState(() => st['status'] = 'Absent');
                                          },
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: !isPresent ? Colors.red : Colors.transparent,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: !isPresent ? Colors.red : Colors.grey.shade400),
                                            ),
                                            child: Text(
                                              "Absent",
                                              style: TextStyle(
                                                color: !isPresent ? Colors.white : Colors.black87,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 20),

                      // Submit Lab Attendance Button
                      if (!_isLabPastDate && !_isLabScheduledToday)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block_rounded, color: Colors.red.shade800, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  "NO LAB SESSION SCHEDULED TODAY — ATTENDANCE ENTRY DISABLED",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.red.shade900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!_isLabPastDate && _labStudents.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            onPressed: _isSavingLabAttendance ? null : _saveLabAttendance,
                            child: _isSavingLabAttendance
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _isLabAlreadyRecorded
                                        ? "UPDATE LAB ATTENDANCE FOR ${DateFormat('dd MMM yyyy').format(_selectedLabDate).toUpperCase()}"
                                        : "SAVE LAB ATTENDANCE FOR ${DateFormat('dd MMM yyyy').format(_selectedLabDate).toUpperCase()}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabBatchSelectionCard(List<Map<String, dynamic>> batches) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 1180;
              final headerLeft = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.biotech_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Select a Lab Batch",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF13246E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Choose a lab batch to view timetable slots and mark attendance",
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              );

              final headerControls = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildLabSubjectDropdown(),
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth : 190,
                    height: 38,
                    child: TextField(
                      controller: _labBatchSearchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search lab batch...",
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _labBatchSearch = val),
                    ),
                  ),
                  _buildLabAYDropdown(),
                  _buildLabSemDropdown(),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerLeft,
                    const SizedBox(height: 14),
                    headerControls,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  headerLeft,
                  Flexible(child: headerControls),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // 2-Column Pastel Lab Batches Grid
          if (batches.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                "No lab batches match your search/filter.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isSingle = constraints.maxWidth < 650;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isSingle ? 1 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 92,
                  ),
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final b = batches[index];
                    final theme = _attendancePastelThemes[(index + 1) % _attendancePastelThemes.length];
                    final bId = b['id'] as int;
                    final isSelected = _selectedLabBatchId == bId;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedLabBatchId = bId;
                            _selectedLabBatch = b;
                          });
                          _loadLabBatchStudents(bId, _selectedLabDate);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF13246E) : theme.border,
                              width: isSelected ? 2.0 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? const Color(0xFF13246E).withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.02),
                                blurRadius: isSelected ? 6 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.iconBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.biotech_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final bName = (b['name'] ?? 'Batch').toString();
                                        final curSubName = (_selectedLabSubject?['subject_name'] ?? b['subject_name'] ?? '').toString().trim();
                                        final curSubCode = (_selectedLabSubject?['subject_code'] ?? b['subject_code'] ?? '').toString().trim();
                                        final bSem = _selectedLabSubject?['semester_name'] ?? _selectedLabSubject?['semester'] ?? b['semester_name'] ?? b['semester'];
                                        final cardTitle = curSubName.isNotEmpty ? "$bName - $curSubName" : bName;
                                        final detailParts = <String>[];
                                        if (curSubCode.isNotEmpty) detailParts.add(curSubCode);
                                        if (bSem != null && bSem.toString().isNotEmpty) detailParts.add("Sem $bSem");

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              cardTitle,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              detailParts.isNotEmpty ? detailParts.join(' • ') : "Lab Batch",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.teal.shade200),
                                          ),
                                          child: Text(
                                            "Lab Batch",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal.shade800,
                                            ),
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF13246E),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "Selected",
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? const Color(0xFF13246E) : Colors.white,
                                  border: Border.all(color: isSelected ? const Color(0xFF13246E) : const Color(0xFFE2E8F0)),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                                  size: isSelected ? 16 : 12,
                                  color: isSelected ? Colors.white : const Color(0xFF13246E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLabSubjectDropdown() {
    var labSubs = _assignedLabSubjects;
    if (_selectedLabSemester != null) {
      final semFiltered = labSubs.where((s) {
        final sem = (s['semester_name'] ?? s['semester'] ?? '').toString();
        return sem == _selectedLabSemester;
      }).toList();
      if (semFiltered.isNotEmpty) {
        labSubs = semFiltered;
      }
    }
    if (labSubs.isEmpty) return const SizedBox.shrink();

    final effectiveValue = labSubs.any((s) => (s['id'] ?? s['subject_id']) == _selectedLabSubjectId)
        ? _selectedLabSubjectId
        : (labSubs.first['id'] ?? labSubs.first['subject_id']) as int;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF13246E), width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: effectiveValue,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
          style: const TextStyle(fontSize: 12, color: Color(0xFF13246E), fontWeight: FontWeight.bold),
          items: labSubs.map((s) {
            final sId = (s['id'] ?? s['subject_id']) as int;
            final code = (s['subject_code'] ?? '').toString();
            final name = (s['subject_name'] ?? '').toString();
            final sem = s['semester_name'] ?? s['semester'];
            final semText = sem != null && sem.toString().isNotEmpty ? " (Sem $sem)" : "";
            return DropdownMenuItem<int>(
              value: sId,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.science_rounded, size: 16, color: Color(0xFF13246E)),
                  const SizedBox(width: 6),
                  Text(
                    code.isNotEmpty ? "$code - $name$semText" : "$name$semText",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              _onLabSubjectChanged(val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLabAYDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedLabAcademicYear,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          hint: const Text("All Academic Years", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
          onChanged: (val) => setState(() => _selectedLabAcademicYear = val),
        ),
      ),
    );
  }

  Widget _buildLabSemDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedLabSemester,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          hint: const Text("All Semesters", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text("All Semesters"),
            ),
            ...['1', '2', '3', '4', '5', '6', '7', '8'].map((sem) {
              return DropdownMenuItem<String?>(
                value: sem,
                child: Text("Sem $sem"),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedLabSemester = val;
              if (val != null) {
                // If current subject is not in this semester, auto-switch to a subject in this semester
                final curSem = (_selectedLabSubject?['semester_name'] ?? _selectedLabSubject?['semester'] ?? '').toString();
                if (curSem != val) {
                  final matchingSub = _assignedLabSubjects.firstWhere(
                    (s) {
                      final sSem = (s['semester_name'] ?? s['semester'] ?? '').toString();
                      return sSem == val;
                    },
                    orElse: () => {},
                  );
                  if (matchingSub.isNotEmpty) {
                    final sId = (matchingSub['id'] ?? matchingSub['subject_id']) as int;
                    _onLabSubjectChanged(sId);
                  }
                }
              }
            });
          },
        ),
      ),
    );
  }

  // =========================================================================
  //  TAB 3: TIMETABLE SCHEDULE (Preserves 100% existing functionality)
  // =========================================================================
  // ignore: unused_element
  Widget _buildTimetableScheduleTab() {
    final todayDay = _todayDay;
    final todayCount = _countForDay(todayDay);
    final filteredSlots = _getFilteredSlots();

    if (_isLoadingSchedule) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF13246E)),
            SizedBox(height: 16),
            Text(
              "Loading your scheduled classes...",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (_allSlots.isEmpty) {
      return _buildZeroSlotsAssignedView();
    }

    return RefreshIndicator(
      onRefresh: _loadSchedule,
      color: const Color(0xFF13246E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Section
          _buildFilterSection(todayDay, todayCount),

          if (_selectedFilter == 'ALL' && todayCount == 0 && _scheduleSearchQuery.isEmpty)
            _buildNoClassTodayNotice(todayDay),

          Expanded(
            child: filteredSlots.isEmpty
                ? _buildEmptyFilteredState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredSlots.length,
                    itemBuilder: (context, index) {
                      return _buildClassCard(filteredSlots[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String todayDay, int todayCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              controller: _scheduleSearchCtrl,
              decoration: InputDecoration(
                hintText: "Search class, code, branch...",
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _scheduleSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _scheduleSearchCtrl.clear();
                          setState(() => _scheduleSearchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => setState(() => _scheduleSearchQuery = val),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDayPill(
                  label: "Today ($todayDay)",
                  filterKey: 'TODAY',
                  count: todayCount,
                  highlight: true,
                ),
                const SizedBox(width: 8),
                _buildDayPill(
                  label: "All Days",
                  filterKey: 'ALL',
                  count: _allSlots.length,
                ),
                const SizedBox(width: 8),
                for (final day in _weekDays) ...[
                  _buildDayPill(
                    label: day,
                    filterKey: day,
                    count: _countForDay(day),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPill({
    required String label,
    required String filterKey,
    required int count,
    bool highlight = false,
  }) {
    final isSelected = _selectedFilter == filterKey;
    final bg = isSelected
        ? const Color(0xFF13246E)
        : (highlight ? Colors.amber.shade100 : Colors.grey.shade100);
    final textColor = isSelected
        ? Colors.white
        : (highlight ? const Color(0xFF13246E) : Colors.grey[800]!);
    final borderColor = isSelected
        ? const Color(0xFF13246E)
        : (highlight ? Colors.amber.shade400 : Colors.grey.shade300);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : (highlight ? Colors.amber.shade200 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoClassTodayNotice(String todayDay) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF13246E), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "No scheduled classes for today ($todayDay). Showing your full timetable schedule.",
              style: const TextStyle(fontSize: 12, color: Color(0xFF13246E), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> slot) {
    final slotId = slot['id'];
    final subjectName = (slot['subject_name'] ?? 'Class Session').toString();
    final day = (slot['day'] ?? '').toString();
    final isToday = day.toUpperCase() == _todayDay;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isToday ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday ? const Color(0xFF13246E) : Colors.grey.shade200,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF13246E) : const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: isToday ? Colors.white : const Color(0xFF13246E)),
                      const SizedBox(width: 6),
                      Text(
                        "$day • ${_formatTime(slot['start_time'])} - ${_formatTime(slot['end_time'])}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isToday ? Colors.white : const Color(0xFF13246E),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      "Today",
                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subjectName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (slot['subject_code'] != null && slot['subject_code'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      slot['subject_code'].toString(),
                      style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                if (slot['semester'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      "Sem ${slot['semester']}",
                      style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                if (slot['branch_name'] != null && slot['branch_name'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      slot['branch_name'].toString(),
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text("View Subject"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF13246E),
                    side: const BorderSide(color: Color(0xFF13246E)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.push('/subjects'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                  label: const Text("Mark Attendance"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    context.push('/attendance/mark/$slotId', extra: subjectName);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _scheduleSearchQuery.isNotEmpty
                  ? "No classes found matching '$_scheduleSearchQuery'"
                  : "No classes scheduled for $_selectedFilter",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.view_week_rounded, size: 16),
              label: const Text("View All Classes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _scheduleSearchCtrl.clear();
                  _scheduleSearchQuery = '';
                  _selectedFilter = 'ALL';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZeroSlotsAssignedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "No timetable slots scheduled yet.",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 6),
            const Text(
              "You can still mark attendance by subject directly in the 'Subject Attendance' tab.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
              icon: const Icon(Icons.how_to_reg_rounded),
              label: const Text("Go to Subject Attendance"),
              onPressed: () => _tabController.animateTo(0),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  //  TAB 3: CUSTOM ATTENDANCE SHORTAGE COMPONENT (<75% Threshold)
  // =========================================================================
  Widget _buildAttendanceShortageTab() {
    final filteredShortage = _shortageList.where((st) {
      if (_shortageSearchQuery.trim().isNotEmpty) {
        final q = _shortageSearchQuery.trim().toLowerCase();
        final usn = (st['usn'] ?? '').toString().toLowerCase();
        final name = (st['name'] ?? '').toString().toLowerCase();
        final sub = "${st['subject_code'] ?? ''} ${st['subject_name'] ?? ''}".toLowerCase();
        if (!usn.contains(q) && !name.contains(q) && !sub.contains(q)) return false;
      }
      if (_shortageSemester != null) {
        final sem = (st['semester'] ?? st['semester_no'] ?? '').toString();
        if (sem != _shortageSemester) return false;
      }
      if (_shortageAcademicYear != null) {
        final ay = (st['academic_year'] ?? st['year_name'] ?? '').toString();
        if (ay != _shortageAcademicYear) return false;
      }
      if (_shortageSubjectFilter != null) {
        final sId = st['subject_id'] ?? st['subject'] ?? st['id'];
        if (sId != _shortageSubjectFilter) return false;
      }
      return true;
    }).toList();

    final criticalCount = filteredShortage.where((s) {
      final p = ((s['attendance_percentage'] ?? 0.0) as num).toDouble();
      return p < 50.0;
    }).length;

    final moderateCount = filteredShortage.where((s) {
      final p = ((s['attendance_percentage'] ?? 0.0) as num).toDouble();
      return p >= 50.0 && p < 65.0;
    }).length;

    final mildCount = filteredShortage.where((s) {
      final p = ((s['attendance_percentage'] ?? 0.0) as num).toDouble();
      return p >= 65.0 && p < 75.0;
    }).length;

    final goodCount = filteredShortage.where((s) {
      final p = ((s['attendance_percentage'] ?? 0.0) as num).toDouble();
      return p >= 75.0;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Card: Shortage Range Slider & KPI Metrics (Image 3)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 850;

                    final sliderColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFFEF4444), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Attendance Shortage",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Find students whose attendance is below the selected range",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Select Shortage Range (%)",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Badges above slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "0%",
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${_shortageThreshold.toInt()}%",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFEF4444),
                            inactiveTrackColor: const Color(0xFFE2E8F0),
                            thumbColor: const Color(0xFFEF4444),
                            overlayColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _shortageThreshold.clamp(0.0, 100.0),
                            min: 0.0,
                            max: 100.0,
                            onChanged: (val) {
                              setState(() {
                                _shortageThreshold = val;
                                _shortageCurrentPage = 1;
                              });
                            },
                            onChangeEnd: (_) => _loadShortageReport(),
                          ),
                        ),
                        // Number ticks row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              '0%', '10%', '20%', '30%', '40%', '50%', '60%', '70%', '75%', '80%', '100%'
                            ].map((tick) {
                              final isCurrent = tick == "${_shortageThreshold.toInt()}%";
                              return Text(
                                tick,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isCurrent ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );

                    final metricsColumn = Column(
                      children: [
                        // Total Students Mini Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF3B82F6), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Students",
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    "${filteredShortage.length}",
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    "Below ${_shortageThreshold.toInt()}%",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 4 Severity KPI boxes
                        Row(
                          children: [
                            Expanded(
                              child: _buildSeverityBox(
                                icon: Icons.error_rounded,
                                count: criticalCount,
                                label: "Critical",
                                sublabel: "(< 50%)",
                                bg: const Color(0xFFFFF1F2),
                                border: const Color(0xFFFFE4E6),
                                textColor: const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSeverityBox(
                                icon: Icons.warning_rounded,
                                count: moderateCount,
                                label: "Moderate",
                                sublabel: "(50% - 65%)",
                                bg: const Color(0xFFFFF7ED),
                                border: const Color(0xFFFFEDD5),
                                textColor: const Color(0xFFF97316),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSeverityBox(
                                icon: Icons.warning_amber_rounded,
                                count: mildCount,
                                label: "Mild",
                                sublabel: "(65% - 75%)",
                                bg: const Color(0xFFFEFCE8),
                                border: const Color(0xFFFEF08A),
                                textColor: const Color(0xFFEAB308),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSeverityBox(
                                icon: Icons.check_circle_rounded,
                                count: goodCount,
                                label: "Good",
                                sublabel: "(> 75%)",
                                bg: const Color(0xFFF0FDF4),
                                border: const Color(0xFFDCFCE7),
                                textColor: const Color(0xFF22C55E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          sliderColumn,
                          const SizedBox(height: 20),
                          metricsColumn,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: sliderColumn),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: metricsColumn),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 2. Filter Bar (Search, AY, Sem, Subject, Export CSV)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 950;
                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildShortageSearchField(),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildShortageAYDropdown(),
                            _buildShortageSemDropdown(),
                            _buildShortageSubjectDropdown(),
                            _buildShortageExportButton(),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: _buildShortageSearchField()),
                      const SizedBox(width: 12),
                      _buildShortageAYDropdown(),
                      const SizedBox(width: 12),
                      _buildShortageSemDropdown(),
                      const SizedBox(width: 12),
                      _buildShortageSubjectDropdown(),
                      const SizedBox(width: 12),
                      _buildShortageExportButton(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // 3. Students Table Card (Image 3)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.groups_rounded, color: Color(0xFF3B82F6), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Students with Attendance Shortage",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF13246E),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "List of students whose attendance falls within the selected range",
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                      if (_isLoadingShortage)
                      const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF13246E))),
                      )
                    else if (_shortageList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.verified_user_rounded, size: 54, color: Colors.green.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "No students below ${_shortageThreshold.toInt()}% attendance in your assigned subjects!",
                              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    else if (filteredShortage.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(30),
                        alignment: Alignment.center,
                        child: const Text("No students match the selected filters", style: TextStyle(color: Colors.grey)),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final int totalShortageCount = filteredShortage.length;
                          final int totalShortagePages = (totalShortageCount / _shortagePageSize).ceil();
                          final int safePage = _shortageCurrentPage.clamp(1, math.max(1, totalShortagePages));
                          final int startIndex = (safePage - 1) * _shortagePageSize;
                          final paginatedShortage = filteredShortage.skip(startIndex).take(_shortagePageSize).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(minWidth: math.max(constraints.maxWidth, 850)),
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                            dataRowMinHeight: 52,
                                            dataRowMaxHeight: 58,
                                            horizontalMargin: 16,
                                            columnSpacing: 20,
                                            columns: const [
                                              DataColumn(label: Text("#", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)))),
                                              DataColumn(label: Text("USN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)))),
                                              DataColumn(label: Text("STUDENT NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)))),
                                              DataColumn(label: Text("SUBJECT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)))),
                                              DataColumn(label: Text("ATTENDED / TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)))),
                                              DataColumn(label: Text("PERCENTAGE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)))),
                                              DataColumn(label: Text("STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)))),
                                            ],
                                            rows: List.generate(paginatedShortage.length, (index) {
                                              final st = paginatedShortage[index];
                                              final usn = st['usn']?.toString() ?? 'N/A';
                                              final name = st['name']?.toString() ?? 'Student';
                                              final subName = st['subject_name']?.toString() ?? st['subject_code']?.toString() ?? '';
                                              final attended = st['attended_classes'] ?? 0;
                                              final conducted = st['conducted_classes'] ?? 0;
                                              final pct = ((st['attendance_percentage'] ?? 0.0) as num).toDouble();

                                              final String statusText;
                                              final Color statusTextColor;
                                              final Color statusBgColor;
                                              final Color barColor;

                                              if (pct < 50.0) {
                                                statusText = "Critical";
                                                statusTextColor = const Color(0xFFEF4444);
                                                statusBgColor = const Color(0xFFFFF1F2);
                                                barColor = const Color(0xFFEF4444);
                                              } else if (pct < 65.0) {
                                                statusText = "Moderate";
                                                statusTextColor = const Color(0xFFF97316);
                                                statusBgColor = const Color(0xFFFFF7ED);
                                                barColor = const Color(0xFFF97316);
                                              } else if (pct < 75.0) {
                                                statusText = "Mild";
                                                statusTextColor = const Color(0xFFEAB308);
                                                statusBgColor = const Color(0xFFFEFCE8);
                                                barColor = const Color(0xFFEAB308);
                                              } else {
                                                statusText = "Good";
                                                statusTextColor = const Color(0xFF22C55E);
                                                statusBgColor = const Color(0xFFF0FDF4);
                                                barColor = const Color(0xFF22C55E);
                                              }

                                              return DataRow(
                                                cells: [
                                                  DataCell(Text("${startIndex + index + 1}", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 12))),
                                                  DataCell(Text(usn, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13))),
                                                  DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 13))),
                                                  DataCell(Text(subName, style: const TextStyle(color: Color(0xFF334155), fontSize: 13))),
                                                  DataCell(Text("$attended / $conducted", style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w500))),
                                                  DataCell(
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          width: 42,
                                                          child: Text(
                                                            "${pct.toInt()}%",
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 13,
                                                              color: barColor,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          width: 72,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: FractionallySizedBox(
                                                            alignment: Alignment.centerLeft,
                                                            widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: barColor,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusBgColor,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        statusText,
                                                        style: TextStyle(
                                                          color: statusTextColor,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AppPaginationBar(
                                currentPage: safePage,
                                totalPages: totalShortagePages,
                                totalItems: totalShortageCount,
                                pageSize: _shortagePageSize,
                                onPageChanged: (newPage) => setState(() => _shortageCurrentPage = newPage),
                              ),
                            ],
                          );
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

  Widget _buildSeverityBox({
    required IconData icon,
    required int count,
    required String label,
    required String sublabel,
    required Color bg,
    required Color border,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(height: 4),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _shortageSearchCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: "Search by USN or name...",
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
          suffixIcon: _shortageSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _shortageSearchCtrl.clear();
                    setState(() {
                      _shortageSearchQuery = '';
                      _shortageCurrentPage = 1;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (val) => setState(() {
          _shortageSearchQuery = val;
          _shortageCurrentPage = 1;
        }),
      ),
    );
  }

  Widget _buildShortageAYDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF13246E)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _shortageAcademicYear,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
              hint: const Text("All Academic Years", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              onChanged: (val) => setState(() => _shortageAcademicYear = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageSemDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_rounded, size: 16, color: Color(0xFF13246E)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _shortageSemester,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
              hint: const Text("All Semesters", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("All Semesters"),
                ),
                ...['1', '2', '3', '4', '5', '6', '7', '8'].map((sem) {
                  return DropdownMenuItem<String?>(
                    value: sem,
                    child: Text("Sem $sem"),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _shortageSemester = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageSubjectDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF13246E)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _shortageSubjectFilter,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF13246E), size: 18),
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
              hint: const Text("All Subjects", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("All Subjects"),
                ),
                ..._professorSubjects.map((sub) {
                  final id = (sub['id'] ?? sub['subject_id']) as int;
                  final name = sub['subject_name'] ?? sub['name'] ?? '';
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text(name),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _shortageSubjectFilter = val);
                _loadShortageReport();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageExportButton() {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF13246E),
          side: const BorderSide(color: Color(0xFF13246E)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: const Icon(Icons.download_rounded, size: 16),
        label: const Text("Export CSV", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        onPressed: _shortageList.isEmpty ? null : _exportShortageReportToCSV,
      ),
    );
  }

  void _exportShortageReportToCSV() {
    final buffer = StringBuffer();
    buffer.writeln("USN,Student Name,Department,Semester,Subject Code,Subject Name,Conducted,Attended,Percentage,Status,Classes Needed for ${_shortageThreshold.toInt()}%");

    for (final s in _shortageList) {
      final usn = s['usn'] ?? '';
      final name = '"${(s['name'] ?? '').toString().replaceAll('"', '""')}"';
      final dept = '"${(s['department_name'] ?? '').toString().replaceAll('"', '""')}"';
      final sem = s['semester'] ?? '';
      final subCode = s['subject_code'] ?? '';
      final subName = '"${(s['subject_name'] ?? '').toString().replaceAll('"', '""')}"';
      final conducted = s['conducted_classes'] ?? 0;
      final attended = s['attended_classes'] ?? 0;
      final pct = "${s['attendance_percentage']}%";
      final status = s['shortage_status'] ?? '';
      final needed = s['classes_needed_for_threshold'] ?? 0;

      buffer.writeln("$usn,$name,$dept,$sem,$subCode,$subName,$conducted,$attended,$pct,$status,$needed");
    }

    final csvContent = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.file_download_outlined, color: Color(0xFF13246E)),
            const SizedBox(width: 8),
            const Text("Attendance Shortage Report (CSV)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Generated ${DateTime.now().toString().split('.')[0]} for ${_shortageList.length} students below ${_shortageThreshold.toInt()}%.",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvContent,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text("Copy CSV"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("CSV copied to clipboard!"), backgroundColor: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _attendanceMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}