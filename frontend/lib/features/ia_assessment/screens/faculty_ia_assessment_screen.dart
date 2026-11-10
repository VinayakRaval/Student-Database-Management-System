import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';
import 'ia_marks_screen.dart';

class _PastelSubjectTheme {
  final Color background;
  final Color border;
  final Color iconBg;
  final Color iconColor;
  final Color chevronBg;
  final Color chevronColor;
  final IconData icon;

  const _PastelSubjectTheme({
    this.background = Colors.white,
    this.border = const Color(0xFFE2E8F0),
    this.iconBg = const Color(0xFFEBF5FE),
    this.iconColor = const Color(0xFF0F2577),
    this.chevronBg = const Color(0xFFF8FAFC),
    this.chevronColor = const Color(0xFF0F2577),
    required this.icon,
  });
}

class FacultyIAAssessmentScreen extends ConsumerStatefulWidget {
  const FacultyIAAssessmentScreen({super.key});

  @override
  ConsumerState<FacultyIAAssessmentScreen> createState() =>
      _FacultyIAAssessmentScreenState();
}

class _FacultyIAAssessmentScreenState
    extends ConsumerState<FacultyIAAssessmentScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _assignedSubjects = [];
  List<String> _academicYears = [];
  List<int> _semesters = [];

  // Filter selections
  String? _selectedAcademicYear; // null means 'All Academic Years'
  int? _selectedSemester; // null means 'All Semesters'
  int? _selectedSubjectFilter; // null means 'All Subjects'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Metrics
  int _totalStudents = 7;
  String _configuredAssessmentsText = "Default 2";
  String _classAverageIAText = "N/A";
  int _evaluatedStudentsCount = 0;

  // Lock status
  String? _semesterLockReason;
  Map<int, Map<String, dynamic>> _finalizedSemesters = {};
  Map<int, Map<String, dynamic>> _subjectMetrics = {};

  bool get _isCurrentViewLocked {
    if (_selectedSemester != null) {
      return _finalizedSemesters.containsKey(_selectedSemester);
    }
    if (_assignedSubjects.isNotEmpty) {
      return _assignedSubjects.every((sub) {
        final semNum = int.tryParse(sub['semester']?.toString() ?? '');
        return semNum != null && _finalizedSemesters.containsKey(semNum);
      });
    }
    return false;
  }

  String? get _currentLockReason {
    if (_selectedSemester != null && _finalizedSemesters.containsKey(_selectedSemester)) {
      return _finalizedSemesters[_selectedSemester]!['remarks']?.toString() ??
          "Internal Assessment evaluations are locked as the semester has concluded.";
    }
    return _semesterLockReason;
  }

  @override
  void initState() {
    super.initState();
    _loadAssignedSubjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;

      // 1. Fetch assigned subjects for the logged-in professor
      final res = await dio.get('/subjects/professor/subjects/');
      final List raw = res.data is List ? res.data : [];
      final subjects =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // 2. Fetch lock & finalization status per semester
      final Map<int, Map<String, dynamic>> finalizedSemesters = {};
      try {
        final finRes =
            await dio.get('/academics/semesters/finalization-status/');
        final List rawFin = finRes.data is List ? finRes.data : [];
        for (var item in rawFin) {
          if (item is Map && item['is_finalized'] == true) {
            final semNo = int.tryParse(item['semester_no']?.toString() ?? item['semester_id']?.toString() ?? '');
            if (semNo != null) {
              finalizedSemesters[semNo] = Map<String, dynamic>.from(item);
            }
          }
        }
      } catch (_) {}

      // 3. Fetch academic years list
      final List<String> ayList = [];
      try {
        final ayRes = await dio.get('/academics/academic-years/');
        final List rawAy = ayRes.data is List ? ayRes.data : [];
        for (var item in rawAy) {
          if (item is Map && item['year'] != null) {
            final y = item['year'].toString();
            if (!ayList.contains(y)) ayList.add(y);
          }
        }
      } catch (_) {}

      // Populate semesters and academic years from assigned subjects
      final Set<int> semSet = {};
      for (var s in subjects) {
        if (s['semester'] != null) {
          final semNum = int.tryParse(s['semester'].toString());
          if (semNum != null) semSet.add(semNum);
        }
        if (s['academic_year'] != null) {
          final y = s['academic_year'].toString();
          if (!ayList.contains(y)) ayList.add(y);
        }
      }

      // 4. Fetch real students count, tests count, and evaluations per subject from database
      final Map<int, Map<String, dynamic>> subjectMetrics = {};
      final Set<int> allDistinctStudentIds = {};
      int totalTestsAcrossSubjects = 0;
      int totalEvaluatedAcrossSubjects = 0;
      double totalMarksSum = 0;
      int totalMarksCount = 0;

      await Future.wait(subjects.map((sub) async {
        final sId = (sub['id'] ?? sub['subject_id']) as int;
        int subStudentCount = 0;
        int subTestCount = 0;
        int subEvaluatedCount = 0;

        try {
          final stuRes = await dio.get('/ia/faculty/active-students/',
              queryParameters: {'subject_id': sId});
          if (stuRes.data is List) {
            final list = stuRes.data as List;
            subStudentCount = list.length;
            for (var st in list) {
              if (st is Map && st['id'] != null) {
                allDistinctStudentIds.add(st['id'] as int);
              }
            }
          }
        } catch (_) {}

        try {
          final testsRes = await dio.get('/ia/ia-tests/',
              queryParameters: {'subject_id': sId});
          if (testsRes.data is List) {
            subTestCount = (testsRes.data as List).length;
          }
        } catch (_) {}

        try {
          final marksRes = await dio.get('/ia/faculty/ia-marks/',
              queryParameters: {'subject_id': sId});
          if (marksRes.data is List) {
            final Set evaluatedStudentIds = {};
            for (var m in marksRes.data) {
              if (m is Map && m['obtained_marks'] != null) {
                evaluatedStudentIds.add(m['student'] ?? m['student_id']);
                final val = double.tryParse(m['obtained_marks'].toString());
                if (val != null) {
                  totalMarksSum += val;
                  totalMarksCount++;
                }
              }
            }
            subEvaluatedCount = evaluatedStudentIds.length;
          }
        } catch (_) {}

        totalTestsAcrossSubjects += subTestCount;
        totalEvaluatedAcrossSubjects += subEvaluatedCount;

        subjectMetrics[sId] = {
          'students': subStudentCount,
          'tests': subTestCount,
          'evaluated': subEvaluatedCount,
        };
      }));

      final calculatedStudents = allDistinctStudentIds.isNotEmpty
          ? allDistinctStudentIds.length
          : subjectMetrics.values.fold<int>(0, (sum, m) => sum + (m['students'] as int? ?? 0));

      final avgText = totalMarksCount > 0
          ? (totalMarksSum / totalMarksCount).toStringAsFixed(1)
          : "N/A";

      if (mounted) {
        setState(() {
          _assignedSubjects = subjects;
          _academicYears = ayList;
          _semesters = semSet.toList()..sort();
          _finalizedSemesters = finalizedSemesters;
          _subjectMetrics = subjectMetrics;
          _semesterLockReason = finalizedSemesters.values.isNotEmpty
              ? (finalizedSemesters.values.first['remarks']?.toString() ?? "Semester marks entry is officially finalized.")
              : null;
          _totalStudents = calculatedStudents;
          _evaluatedStudentsCount = totalEvaluatedAcrossSubjects;
          _configuredAssessmentsText = totalTestsAcrossSubjects.toString();
          _classAverageIAText = avgText;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load assigned subjects: $e";
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    return _assignedSubjects.where((s) {
      if (_selectedAcademicYear != null &&
          _selectedAcademicYear!.isNotEmpty) {
        if (s['academic_year']?.toString() != _selectedAcademicYear) {
          return false;
        }
      }
      if (_selectedSemester != null) {
        final sem = int.tryParse(s['semester']?.toString() ?? '');
        if (sem != _selectedSemester) return false;
      }
      if (_selectedSubjectFilter != null) {
        final sId = s['id'] ?? s['subject_id'];
        if (sId != _selectedSubjectFilter) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (s['subject_name'] ?? '').toString().toLowerCase();
        final code = (s['subject_code'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !code.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  _PastelSubjectTheme _getSubjectTheme(int index, String code) {
    final upper = code.toUpperCase();
    IconData icon = Icons.menu_book_rounded;
    if (upper.contains('LAB') || upper.contains('601L') || upper.contains('L')) {
      icon = Icons.biotech_rounded;
    } else if (upper.contains('301') || upper.contains('701')) {
      icon = Icons.devices_other_rounded;
    } else if (upper.contains('302') || upper.contains('702')) {
      icon = Icons.memory_rounded;
    } else if (upper.contains('303') || upper.contains('603')) {
      icon = Icons.computer_rounded;
    } else if (upper.contains('304')) {
      icon = Icons.dns_rounded;
    } else if (upper.contains('305')) {
      icon = Icons.code_rounded;
    } else {
      final icons = [
        Icons.menu_book_rounded,
        Icons.computer_rounded,
        Icons.storage_rounded,
        Icons.code_rounded,
        Icons.science_rounded,
      ];
      icon = icons[index % icons.length];
    }

    return _PastelSubjectTheme(
      background: Colors.white,
      border: const Color(0xFFE2E8F0),
      iconBg: const Color(0xFFEBF5FE),
      iconColor: const Color(0xFF0F2577),
      chevronBg: const Color(0xFFF8FAFC),
      chevronColor: const Color(0xFF0F2577),
      icon: icon,
    );
  }

  void _openMarksEntryDialog([int? targetSubjectId, String? targetSubjectName]) {
    final sId = targetSubjectId ??
        (_assignedSubjects.isNotEmpty
            ? (_assignedSubjects.first['id'] ??
                _assignedSubjects.first['subject_id'])
            : null);
    if (sId == null) return;

    final name = targetSubjectName ??
        _assignedSubjects.firstWhere(
          (s) => (s['id'] ?? s['subject_id']) == sId,
          orElse: () => {'subject_name': 'Subject'},
        )['subject_name']?.toString() ??
        'Subject';

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (ctx) => IAMarksScreen(
          subjectId: sId,
          subjectName: name,
        ),
      ),
    )
        .then((_) {
      _loadAssignedSubjects();
    });
  }

  void _showCreateTestDialog([int? targetSubjectId]) {
    final sId = targetSubjectId ??
        (_assignedSubjects.isNotEmpty
            ? (_assignedSubjects.first['id'] ??
                _assignedSubjects.first['subject_id'])
            : null);
    if (sId == null) return;

    final subjectData = _assignedSubjects.firstWhere(
      (s) => (s['id'] ?? s['subject_id']) == sId,
      orElse: () => {},
    );
    final subjectName = subjectData['subject_name'] ?? 'Subject';

    final nameCtrl = TextEditingController(text: 'Internal Assessment 1');
    final maxMarksCtrl = TextEditingController(text: '25');
    final instructionsCtrl = TextEditingController();
    DateTime assessmentDate = DateTime.now();
    DateTime submissionDeadline = DateTime.now().add(const Duration(days: 7));
    String iaType = 'Test1';

    final typeOptions = [
      {
        'val': 'Test1',
        'label': 'Test 1 (Theory IA)',
        'icon': Icons.assignment_outlined
      },
      {
        'val': 'Test2',
        'label': 'Test 2 (Theory IA)',
        'icon': Icons.assignment_outlined
      },
      {
        'val': 'LabTest1',
        'label': 'Lab Test 1 (Lab IA)',
        'icon': Icons.science_outlined
      },
      {
        'val': 'LabTest2',
        'label': 'Lab Test 2 (Lab IA)',
        'icon': Icons.science_outlined
      },
      {
        'val': 'Assignment',
        'label': 'Assignment',
        'icon': Icons.menu_book_outlined
      },
      {
        'val': 'Presentation',
        'label': 'Presentation',
        'icon': Icons.co_present_outlined
      },
      {'val': 'Quiz', 'label': 'Quiz', 'icon': Icons.quiz_outlined},
      {
        'val': 'Custom',
        'label': 'Custom Assessment',
        'icon': Icons.tune_rounded
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isLab = iaType == 'LabTest1' || iaType == 'LabTest2';

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isLab ? Icons.biotech_rounded : Icons.post_add_rounded,
                    color: const Color(0xFF13246E),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLab
                            ? "Configure Lab Assessment"
                            : "Configure Assessment",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        subjectName,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Academic Year & Semester Badges (Auto-selected from Subject)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school_outlined, size: 16, color: Color(0xFF0F2577)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Academic Year: ${subjectData['academic_year'] ?? 'Current AY'}   •   Semester: ${subjectData['semester'] ?? 'N/A'}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F2577),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text("Assessment Type",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: iaType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: typeOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['val'] as String,
                          child: Row(
                            children: [
                              Icon(opt['icon'] as IconData,
                                  size: 16, color: const Color(0xFF13246E)),
                              const SizedBox(width: 8),
                              Text(opt['label'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            iaType = val;
                            if (val == 'Test1') {
                              nameCtrl.text = 'Internal Assessment 1';
                            }
                            if (val == 'Test2') {
                              nameCtrl.text = 'Internal Assessment 2';
                            }
                            if (val == 'LabTest1') {
                              nameCtrl.text = 'Lab Internal Assessment 1';
                            }
                            if (val == 'LabTest2') {
                              nameCtrl.text = 'Lab Internal Assessment 2';
                            }
                            if (val == 'Assignment') {
                              nameCtrl.text = 'Assignment 1';
                            }
                            if (val == 'Presentation') {
                              nameCtrl.text = 'Presentation 1';
                            }
                            if (val == 'Quiz') nameCtrl.text = 'Quiz 1';
                            if (val == 'Custom') {
                              nameCtrl.text = 'Custom Assessment';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text("Assessment Title",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: "e.g. Internal Assessment 1 / Unit Test 1",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text("Maximum Marks",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: maxMarksCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "e.g. 25, 30, 50, 100",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Pickers Row (Assessment Date & Submission Deadline)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Assessment Date",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: assessmentDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      assessmentDate = picked;
                                      if (submissionDeadline.isBefore(assessmentDate)) {
                                        submissionDeadline = assessmentDate.add(const Duration(days: 7));
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${assessmentDate.day.toString().padLeft(2, '0')}/${assessmentDate.month.toString().padLeft(2, '0')}/${assessmentDate.year}",
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F2577)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Submission Deadline",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: submissionDeadline,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      submissionDeadline = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${submissionDeadline.day.toString().padLeft(2, '0')}/${submissionDeadline.month.toString().padLeft(2, '0')}/${submissionDeadline.year}",
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF0F2577)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text("Instructions (Optional)",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: instructionsCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "e.g. Conducted during regular lecture hours. Bring calculators.",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  final maxMarks =
                      int.tryParse(maxMarksCtrl.text.trim()) ?? 0;
                  final title = nameCtrl.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Assessment title is required."), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (maxMarks <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Maximum marks must be greater than zero."), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (submissionDeadline.isBefore(assessmentDate)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Submission deadline cannot be earlier than assessment date."), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  Navigator.of(ctx).pop();
                  try {
                    final dio = ApiClient().dio;
                    final payload = <String, dynamic>{
                      'subject': sId,
                      'ia_type': iaType,
                      'ia_name': title,
                      'max_marks': maxMarks,
                      'component_type': isLab ? 'LAB' : 'THEORY',
                      'assessment_date': "${assessmentDate.year}-${assessmentDate.month.toString().padLeft(2, '0')}-${assessmentDate.day.toString().padLeft(2, '0')}",
                      'submission_deadline': "${submissionDeadline.year}-${submissionDeadline.month.toString().padLeft(2, '0')}-${submissionDeadline.day.toString().padLeft(2, '0')}",
                      'instructions': instructionsCtrl.text.trim(),
                      'status': 'CONFIGURED',
                    };

                    await dio.post('/ia/ia-tests/create/', data: payload);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "${isLab ? 'Lab' : 'Theory'} Assessment '$title' configured successfully!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadAssignedSubjects();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Failed to configure test: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text("Save & Configure"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildMainContent(),
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
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white),
              onPressed: _loadAssignedSubjects,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final filtered = _filteredSubjects;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Refresh Icon Row aligned to the right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Color(0xFF1E293B), size: 22),
                tooltip: "Refresh IA Management Data",
                onPressed: _loadAssignedSubjects,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 1. Top Alert Banner: "Semester Completed – Marks Locked"
          if (_isCurrentViewLocked) ...[
            _buildSemesterLockedBanner(),
            const SizedBox(height: 18),
          ],

          // 2. Overview 4 Metric Cards
          _buildMetricCards(filtered),
          const SizedBox(height: 20),

          // 3. Filter Bar (All Academic Years, All Semesters, All Subjects, Search)
          _buildFilterBar(),
          const SizedBox(height: 22),

          // 4. Section Header: "Assigned Subjects" & Subtitle
          const Text(
            "Assigned Subjects",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Manage IA assessments, view marks and evaluations for each subject",
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),

          // 5. Subject Cards Grid (3 Columns on Desktop, 2 on Tablet, 1 on Mobile)
          if (filtered.isEmpty)
            _buildEmptySubjectsView()
          else
            _buildSubjectCardsGrid(filtered),
        ],
      ),
    );
  }

  Widget _buildSemesterLockedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded,
                color: Color(0xFFEF4444), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      "Semester Completed – Marks Locked",
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.shield_rounded,
                        color: Color(0xFFDC2626), size: 16),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _currentLockReason ??
                      "Internal Assessment evaluations are locked as the semester has concluded.",
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards([List<Map<String, dynamic>>? subjectsList]) {
    final list = subjectsList ?? _assignedSubjects;
    int studentsCount = 0;
    int testsCount = 0;
    int evaluatedCount = 0;
    for (var s in list) {
      final sId = (s['id'] ?? s['subject_id']) as int;
      final m = _subjectMetrics[sId] ?? {'students': 0, 'tests': 0, 'evaluated': 0};
      studentsCount += (m['students'] as int? ?? 0);
      testsCount += (m['tests'] as int? ?? 0);
      evaluatedCount += (m['evaluated'] as int? ?? 0);
    }
    final displayStudents = list.isNotEmpty ? studentsCount : _totalStudents;
    final displayTests = list.isNotEmpty ? testsCount.toString() : _configuredAssessmentsText;
    final displayEvaluated = list.isNotEmpty ? "$evaluatedCount / $displayStudents" : "$_evaluatedStudentsCount / $_totalStudents";

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: "Total Students",
                      value: "$displayStudents",
                      icon: Icons.people_alt_rounded,
                      iconBg: const Color(0xFFEBF5FE),
                      iconColor: const Color(0xFF0F2577),
                      valueColor: const Color(0xFF0F2577),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      label: "Configured Assessments",
                      value: displayTests,
                      icon: Icons.assignment_outlined,
                      iconBg: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: "Class Average IA",
                      value: _classAverageIAText,
                      icon: Icons.analytics_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      valueColor: const Color(0xFF0F2577),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      label: "Evaluated Students",
                      value: displayEvaluated,
                      icon: Icons.check_circle_rounded,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      valueColor: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: "Total Students",
                value: "$displayStudents",
                icon: Icons.people_alt_rounded,
                iconBg: const Color(0xFFEBF5FE),
                iconColor: const Color(0xFF0F2577),
                valueColor: const Color(0xFF0F2577),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                label: "Configured Assessments",
                value: displayTests,
                icon: Icons.assignment_outlined,
                iconBg: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF16A34A),
                valueColor: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                label: "Class Average IA",
                value: _classAverageIAText,
                icon: Icons.analytics_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                valueColor: const Color(0xFF0F2577),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                label: "Evaluated Students",
                value: displayEvaluated,
                icon: Icons.check_circle_rounded,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                valueColor: const Color(0xFF059669),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        final ayDropdown = Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedAcademicYear,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded,
                  color: Color(0xFF64748B)),
              hint: const Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text("All Academic Years",
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500)),
                ],
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text("All Academic Years",
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                ..._academicYears.map((ay) => DropdownMenuItem<String?>(
                      value: ay,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined,
                              size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(ay,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedAcademicYear = val),
            ),
          ),
        );

        final semDropdown = Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedSemester,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded,
                  color: Color(0xFF64748B)),
              hint: const Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text("All Semesters",
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500)),
                ],
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text("All Semesters",
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                ..._semesters.map((s) => DropdownMenuItem<int?>(
                      value: s,
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined,
                              size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text("Semester $s",
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedSemester = val),
            ),
          ),
        );

        final subDropdown = Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedSubjectFilter,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded,
                  color: Color(0xFF64748B)),
              hint: const Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "All Subjects",
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "All Subjects",
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._assignedSubjects.map((sub) {
                  final sId = (sub['id'] ?? sub['subject_id']) as int;
                  final code = sub['subject_code'] ?? '';
                  final name = sub['subject_name'] ?? '';
                  return DropdownMenuItem<int?>(
                    value: sId,
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$code - $name",
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedSubjectFilter = val),
            ),
          ),
        );

        final searchInput = Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: "Search subject name...",
              hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.normal),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        );

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: ayDropdown),
                  const SizedBox(width: 10),
                  Expanded(child: semDropdown),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: subDropdown),
                  const SizedBox(width: 10),
                  Expanded(child: searchInput),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: ayDropdown),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: semDropdown),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: subDropdown),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: searchInput),
          ],
        );
      },
    );
  }

  Widget _buildEmptySubjectsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? "No subjects found matching '$_searchQuery'"
                : "No subjects match the selected filters.",
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedAcademicYear = null;
                _selectedSemester = null;
                _selectedSubjectFilter = null;
                _searchQuery = '';
                _searchCtrl.clear();
              });
            },
            child: const Text("Clear All Filters"),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCardsGrid(List<Map<String, dynamic>> subjects) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 750) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1180) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 215,
          ),
          itemCount: subjects.length,
          itemBuilder: (ctx, index) {
            final sub = subjects[index];
            final sId = (sub['id'] ?? sub['subject_id']) as int;
            final code = (sub['subject_code'] ?? '').toString();
            final name = (sub['subject_name'] ?? '').toString();
            final sem = (sub['semester'] ?? '3').toString();
            final semNum = int.tryParse(sem);
            final bool isSubLocked = semNum != null && _finalizedSemesters.containsKey(semNum);
            final theme = _getSubjectTheme(index, code);

            final metrics = _subjectMetrics[sId] ?? {'students': 0, 'tests': 0, 'evaluated': 0};
            final subStudents = metrics['students'] ?? 0;
            final subTests = metrics['tests'] ?? 0;
            final subEvaluated = metrics['evaluated'] ?? 0;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row: Navy Icon Box + Subject Title & Subtitle + Chevron Button
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF5FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(theme.icon,
                              color: const Color(0xFF0F2577), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "$code  •  Semester $sem",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _openMarksEntryDialog(sId, name),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xFF0F2577),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Middle Row: Mini stats badges matching Image 1
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Badge 1: Students
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline_rounded,
                                  size: 13, color: Color(0xFF0F2577)),
                              const SizedBox(width: 4),
                              Text(
                                "$subStudents Students",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge 2: Configured Assessments
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_outlined,
                                  size: 13, color: Color(0xFF0F2577)),
                              const SizedBox(width: 4),
                              Text(
                                "$subTests Assessments",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge 3: Evaluated
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDCFCE7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 13, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              Text(
                                "$subEvaluated / $subStudents Evaluated",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Bottom Row: Action Buttons matching Image 1
                    Row(
                      children: [
                        // Left: Outlined "+ Configure Test"
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Color(0xFF0F2577), width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                              ),
                              onPressed: () => _showCreateTestDialog(sId),
                              child: const Text(
                                "+ Configure Test",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F2577),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right: Filled Navy "View (Locked)" or "Enter Marks"
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F2577),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                              ),
                              onPressed: () =>
                                  _openMarksEntryDialog(sId, name),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSubLocked
                                        ? Icons.lock_outline_rounded
                                        : Icons.edit_note_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isSubLocked
                                          ? "View (Locked)"
                                          : "Enter Marks",
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
