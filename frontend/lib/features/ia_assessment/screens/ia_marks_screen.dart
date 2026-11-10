import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class IAMarksScreen extends ConsumerStatefulWidget {
  final int subjectId;
  final String? subjectName;
  final int? initialTestId;

  const IAMarksScreen({
    super.key,
    required this.subjectId,
    this.subjectName,
    this.initialTestId,
  });

  @override
  ConsumerState<IAMarksScreen> createState() => _IAMarksScreenState();
}

class _IAMarksScreenState extends ConsumerState<IAMarksScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool _isLocked = false;
  String? _lockReason;
  int? _currentTestId;
  String _testStatus = 'DRAFT';
  String? _hodRemarks;
  String? _instructions;
  DateTime? _assessmentDate = DateTime.now();
  DateTime? _submissionDeadline = DateTime.now().add(const Duration(days: 7));

  List<Map<String, dynamic>> _availableTests = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _labBatches = [];
  List<Map<String, dynamic>> _existingMarks = [];
  int? _selectedBatchId;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, bool> _isAbsentMap = {};
  final Map<int, bool> _isExemptedMap = {};
  final Map<int, TextEditingController> _remarksControllers = {};
  bool _hasUnsavedChanges = false;

  bool get _isReadOnly =>
      _isLocked ||
      _testStatus == 'SUBMITTED' ||
      _testStatus == 'APPROVED' ||
      _testStatus == 'VERIFIED' ||
      _testStatus == 'PUBLISHED';

  String _iaType = 'Test1';
  final TextEditingController _iaNameController =
      TextEditingController(text: 'Internal Assessment 1');
  final TextEditingController _maxMarksController =
      TextEditingController(text: '25');

  final List<String> _iaTypes = [
    'Test1',
    'Test2',
    'LabTest1',
    'LabTest2',
    'Assignment',
    'Presentation',
    'Quiz',
    'Custom'
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _iaNameController.dispose();
    _maxMarksController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    for (var c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    await _fetchBatches();
    await _fetchExistingMarksAndLockStatus();
    await _fetchStudents();
  }

  Future<void> _fetchBatches() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/attendance/batches/',
          queryParameters: {'subject_id': widget.subjectId});
      final List raw = res.data is List ? res.data : [];
      if (mounted) {
        setState(() {
          _labBatches =
              raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchExistingMarksAndLockStatus() async {
    try {
      final dio = ApiClient().dio;

      // 1. Fetch available tests for this subject
      List<Map<String, dynamic>> tests = [];
      try {
        final tRes = await dio.get('/ia/ia-tests/',
            queryParameters: {'subject_id': widget.subjectId});
        final List rawT = tRes.data is List ? tRes.data : [];
        tests = rawT.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}

      // 2. Fetch marks for this subject
      final res = await dio.get('/ia/faculty/ia-marks/',
          queryParameters: {'subject_id': widget.subjectId});
      final List raw = res.data is List ? res.data : [];
      final marks =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // 3. Fetch semester finalization status
      bool finalized = false;
      String? finReason;
      try {
        final finRes = await dio.get('/academics/semesters/finalization-status/');
        final List rawFin = finRes.data is List ? finRes.data : [];
        for (var item in rawFin) {
          if (item is Map && item['is_finalized'] == true) {
            finalized = true;
            finReason = item['remarks']?.toString() ??
                "Semester Officially Completed & Finalized";
            break;
          }
        }
      } catch (_) {}

      // Pick selected test: widget.initialTestId or first available
      Map<String, dynamic>? chosenTest;
      if (widget.initialTestId != null) {
        chosenTest = tests.firstWhere(
          (t) => t['id'] == widget.initialTestId,
          orElse: () => tests.isNotEmpty ? tests.first : {},
        );
      } else if (_currentTestId != null) {
        chosenTest = tests.firstWhere(
          (t) => t['id'] == _currentTestId,
          orElse: () => tests.isNotEmpty ? tests.first : {},
        );
      } else if (tests.isNotEmpty) {
        chosenTest = tests.first;
      }

      int? foundTestId;
      String currentStatus = 'DRAFT';
      String? remarks;
      String? instructions;
      DateTime? aDate;
      DateTime? dLine;
      bool testLocked = false;
      String? testLockReason;

      if (chosenTest != null && chosenTest.isNotEmpty) {
        foundTestId = chosenTest['id'] as int?;
        _iaType = chosenTest['ia_type']?.toString() ?? _iaType;
        _iaNameController.text = chosenTest['ia_name']?.toString() ?? _iaNameController.text;
        _maxMarksController.text = (chosenTest['max_marks'] ?? '25').toString();
        currentStatus = chosenTest['status']?.toString() ?? 'DRAFT';
        testLocked = chosenTest['is_locked'] == true;
        testLockReason = chosenTest['lock_reason']?.toString();
        remarks = chosenTest['hod_remarks']?.toString();
        instructions = chosenTest['instructions']?.toString();
        if (chosenTest['assessment_date'] != null) {
          aDate = DateTime.tryParse(chosenTest['assessment_date'].toString());
        }
        if (chosenTest['submission_deadline'] != null) {
          dLine = DateTime.tryParse(chosenTest['submission_deadline'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _availableTests = tests;
          _existingMarks = marks;
          _currentTestId = foundTestId;
          _isLocked = testLocked || finalized;
          _lockReason = testLockReason ?? finReason ?? "Semester Completed – Marks Locked";
          _testStatus = currentStatus;
          _hodRemarks = remarks;
          _instructions = instructions;
          if (aDate != null) _assessmentDate = aDate;
          if (dLine != null) _submissionDeadline = dLine;
        });
      }
    } catch (_) {}
  }

  void _onTestSelected(Map<String, dynamic> test) {
    setState(() {
      _currentTestId = test['id'] as int?;
      _iaType = test['ia_type']?.toString() ?? 'Test1';
      _iaNameController.text = test['ia_name']?.toString() ?? 'Internal Assessment';
      _maxMarksController.text = (test['max_marks'] ?? '25').toString();
      _testStatus = test['status']?.toString() ?? 'DRAFT';
      _isLocked = test['is_locked'] == true;
      _lockReason = test['lock_reason']?.toString() ?? "Semester Completed – Marks Locked";
      _hodRemarks = test['hod_remarks']?.toString();
      _instructions = test['instructions']?.toString();
      if (test['assessment_date'] != null) {
        _assessmentDate = DateTime.tryParse(test['assessment_date'].toString());
      }
      if (test['submission_deadline'] != null) {
        _submissionDeadline = DateTime.tryParse(test['submission_deadline'].toString());
      }
      _hasUnsavedChanges = false;
    });
    _repopulateStudentMarksForCurrentTest();
  }

  void _repopulateStudentMarksForCurrentTest() {
    for (var s in _students) {
      final id = s['id'] as int;
      String initialMark = '0';
      bool isAbsent = false;
      bool isExempted = false;
      String remark = '';

      for (var m in _existingMarks) {
        final mTestId = m['ia_test'] is int
            ? m['ia_test']
            : (m['ia_test'] is Map ? m['ia_test']['id'] : null);
        final mStudentId = m['student'] is int
            ? m['student']
            : (m['student'] is Map ? m['student']['id'] : null);

        if (mStudentId == id && mTestId == _currentTestId) {
          initialMark = m['obtained_marks']?.toString() ?? '0';
          isAbsent = m['is_absent'] == true;
          isExempted = m['is_exempted'] == true;
          remark = m['remarks']?.toString() ?? '';
          break;
        }
      }

      _isAbsentMap[id] = isAbsent;
      _isExemptedMap[id] = isExempted;
      if (_controllers.containsKey(id)) {
        _controllers[id]!.text = initialMark;
      }
      if (_remarksControllers.containsKey(id)) {
        _remarksControllers[id]!.text = remark;
      }
    }
    setState(() {});
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final params = <String, dynamic>{'subject_id': widget.subjectId};
      if (_selectedBatchId != null) {
        params['batch_id'] = _selectedBatchId;
      }

      final response = await dio.get(
        '/ia/faculty/active-students/',
        queryParameters: params,
      );

      final List data = response.data is List ? response.data : [];
      final List<Map<String, dynamic>> students =
          data.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Sort by USN in ascending order (lowest to highest)
      students.sort((a, b) {
        final usnA = (a['usn'] ?? a['student__usn'] ?? '').toString().trim();
        final usnB = (b['usn'] ?? b['student__usn'] ?? '').toString().trim();
        return usnA.compareTo(usnB);
      });

      for (var s in students) {
        final id = s['id'] as int;
        String initialMark = '0';
        bool isAbsent = false;
        bool isExempted = false;
        String remark = '';

        for (var m in _existingMarks) {
          final mTestId = m['ia_test'] is int
              ? m['ia_test']
              : (m['ia_test'] is Map ? m['ia_test']['id'] : null);
          final mStudentId = m['student'] is int
              ? m['student']
              : (m['student'] is Map ? m['student']['id'] : null);

          bool match = false;
          if (_currentTestId != null) {
            match = (mTestId == _currentTestId && mStudentId == id);
          } else {
            match = (mStudentId == id && (m['ia_type'] == _iaType || m['ia_name'] == _iaNameController.text.trim()));
          }

          if (match) {
            initialMark = m['obtained_marks']?.toString() ?? '0';
            isAbsent = m['is_absent'] == true;
            isExempted = m['is_exempted'] == true;
            remark = m['remarks']?.toString() ?? '';
            break;
          }
        }

        _isAbsentMap[id] = isAbsent;
        _isExemptedMap[id] = isExempted;
        if (_controllers.containsKey(id)) {
          _controllers[id]!.text = initialMark;
        } else {
          _controllers[id] = TextEditingController(text: initialMark);
        }
        if (_remarksControllers.containsKey(id)) {
          _remarksControllers[id]!.text = remark;
        } else {
          _remarksControllers[id] = TextEditingController(text: remark);
        }
      }

      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = "Could not load students for this subject.";
        if (e is DioException) {
          final data = e.response?.data;
          if (e.response?.statusCode == 403) {
            msg = data is Map && data['error'] != null
                ? data['error'].toString()
                : "Permission Denied: Only the faculty member assigned to teach this subject can enter or update IA marks.";
          } else if (data is Map && data['error'] != null) {
            msg = data['error'].toString();
          } else if (e.response?.statusCode == 404) {
            msg = "No enrolled students found for this subject.";
          }
        }
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    }
  }

  void _onTypeOrBatchChanged() {
    // Re-check existing marks for the chosen type
    bool testLocked = false;
    String? testLockReason;
    int? foundTestId;
    String currentStatus = 'DRAFT';
    String? remarks;
    DateTime? aDate;
    DateTime? dLine;

    for (var m in _existingMarks) {
      if (m['ia_type'] == _iaType ||
          m['ia_name'] == _iaNameController.text.trim()) {
        foundTestId = m['ia_test'] is int
            ? m['ia_test']
            : (m['ia_test'] is Map ? m['ia_test']['id'] : null);
        if (m['is_locked'] == true) {
          testLocked = true;
          testLockReason = m['lock_reason']?.toString() ??
              "Semester Completed – Marks Locked";
        }
        currentStatus = m['test_status'] ?? m['status'] ?? 'DRAFT';
        remarks = m['hod_remarks'];
        if (m['assessment_date'] != null) {
          aDate = DateTime.tryParse(m['assessment_date'].toString());
        }
        if (m['submission_deadline'] != null) {
          dLine = DateTime.tryParse(m['submission_deadline'].toString());
        }
      }
    }

    setState(() {
      _currentTestId = foundTestId;
      _isLocked = testLocked;
      _lockReason = testLockReason ?? "Semester Completed – Marks Locked";
      _testStatus = currentStatus;
      _hodRemarks = remarks;
      if (aDate != null) _assessmentDate = aDate;
      if (dLine != null) _submissionDeadline = dLine;
    });

    // Update marks controllers with existing data
    for (var s in _students) {
      final id = s['id'] as int;
      String currentVal = '0';
      bool isAbsent = false;
      for (var m in _existingMarks) {
        final mStudentId = m['student'] is int
            ? m['student']
            : (m['student'] is Map ? m['student']['id'] : null);
        if (mStudentId == id &&
            (m['ia_type'] == _iaType ||
                m['ia_name'] == _iaNameController.text.trim())) {
          currentVal = m['obtained_marks']?.toString() ?? '0';
          isAbsent = m['is_absent'] == true;
          break;
        }
      }
      _isAbsentMap[id] = isAbsent;
      if (_controllers.containsKey(id)) {
        _controllers[id]!.text = currentVal;
      }
    }
  }

  Future<void> _submitMarks([String action = 'SUBMIT']) async {
    if (_isLocked) {
      _showLockedDialog();
      return;
    }
    if (_isReadOnly && action != 'DRAFT') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Assessment is in '$_testStatus' status and read-only."),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final maxMarks = int.tryParse(_maxMarksController.text.trim()) ?? 0;
    if (maxMarks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Max marks must be greater than 0."),
            backgroundColor: Colors.red),
      );
      return;
    }

    final iaName = _iaNameController.text.trim();
    if (iaName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Assessment Name is required."),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Validate marks values before proceeding
    for (var s in _students) {
      final id = s['id'] as int;
      final isAbsent = _isAbsentMap[id] == true;
      final isExempted = _isExemptedMap[id] == true;
      final text = _controllers[id]?.text.trim() ?? '0';
      final val = double.tryParse(text);
      if (!isAbsent && !isExempted && (val == null || val < 0 || val > maxMarks)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Invalid mark '$text' for student ${s['usn'] ?? s['name']}. Must be between 0 and $maxMarks."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (action == 'SUBMIT') {
      _showPreSubmissionSummaryDialog();
    } else {
      await _executeSubmission('DRAFT');
    }
  }

  void _showPreSubmissionSummaryDialog() {
    final maxMarks = int.tryParse(_maxMarksController.text.trim()) ?? 25;
    int evaluatedCount = 0;
    int missingCount = 0;
    int absentCount = 0;
    int exemptedCount = 0;

    for (var s in _students) {
      final id = s['id'] as int;
      final isAb = _isAbsentMap[id] == true;
      final isEx = _isExemptedMap[id] == true;
      final text = _controllers[id]?.text.trim() ?? '';
      final val = double.tryParse(text);

      if (isAb) {
        absentCount++;
        evaluatedCount++;
      } else if (isEx) {
        exemptedCount++;
        evaluatedCount++;
      } else if (val != null && val >= 0) {
        evaluatedCount++;
      } else {
        missingCount++;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fact_check_rounded, color: Color(0xFF0F2577), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Pre-Submission Review Summary",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2577)),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Assessment: ${_iaNameController.text.trim()}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _dialogSummaryRow("Total Enrolled Students", "${_students.length}"),
                    const Divider(height: 12),
                    _dialogSummaryRow("Evaluated Students", "$evaluatedCount / ${_students.length}"),
                    const Divider(height: 12),
                    _dialogSummaryRow("Missing Marks", "$missingCount", isAlert: missingCount > 0),
                    const Divider(height: 12),
                    _dialogSummaryRow("Absent Students (AB)", "$absentCount"),
                    const Divider(height: 12),
                    _dialogSummaryRow("Exempted Students (EX)", "$exemptedCount"),
                    const Divider(height: 12),
                    _dialogSummaryRow("Maximum Marks", "$maxMarks"),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Once submitted, marks will be locked for faculty editing while awaiting HOD review and approval.",
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2577),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSubmission("SUBMIT");
            },
            child: const Text("CONFIRM & SUBMIT TO HOD"),
          ),
        ],
      ),
    );
  }

  Widget _dialogSummaryRow(String label, String value, {bool isAlert = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Future<void> _executeSubmission(String action) async {
    final maxMarks = int.tryParse(_maxMarksController.text.trim()) ?? 25;
    final iaName = _iaNameController.text.trim();

    final List<Map<String, dynamic>> marksPayload = [];
    for (var s in _students) {
      final id = s['id'] as int;
      final isAbsent = _isAbsentMap[id] == true;
      final isExempted = _isExemptedMap[id] == true;
      final text = _controllers[id]?.text.trim() ?? '0';
      final val = double.tryParse(text);

      marksPayload.add({
        "student_id": id,
        "obtained_marks": (isAbsent || isExempted) ? 0.0 : (val ?? 0.0),
        "is_absent": isAbsent,
        "is_exempted": isExempted,
        "remarks": _remarksControllers[id]?.text.trim() ?? '',
      });
    }

    setState(() => _isSubmitting = true);

    try {
      final dio = ApiClient().dio;

      final postData = <String, dynamic>{
        'subject': widget.subjectId,
        'ia_type': _iaType,
        'ia_name': iaName,
        'max_marks': maxMarks,
        'component_type': _iaType.startsWith('Lab') ? 'LAB' : 'THEORY',
        'status': action == 'SUBMIT' ? 'SUBMITTED' : (_testStatus == 'RETURNED' ? 'RETURNED' : 'IN_PROGRESS'),
      };
      if (_selectedBatchId != null) {
        postData['batch_id'] = _selectedBatchId;
      }
      if (_assessmentDate != null) {
        postData['assessment_date'] =
            "${_assessmentDate!.year}-${_assessmentDate!.month.toString().padLeft(2, '0')}-${_assessmentDate!.day.toString().padLeft(2, '0')}";
      }
      if (_submissionDeadline != null) {
        postData['submission_deadline'] =
            "${_submissionDeadline!.year}-${_submissionDeadline!.month.toString().padLeft(2, '0')}-${_submissionDeadline!.day.toString().padLeft(2, '0')}";
      }
      if (_instructions != null && _instructions!.isNotEmpty) {
        postData['instructions'] = _instructions;
      }

      // 1. Create or get IA Test Setup
      final testRes = await dio.post('/ia/ia-tests/create/', data: postData);
      final testId = testRes.data['id'];
      _currentTestId = testId;

      // 2. Submit Bulk Marks
      await dio.put('/ia/ia-tests/$testId/update-marks/', data: {
        'marks': marksPayload,
        'status': action == 'SUBMIT' ? 'SUBMITTED' : 'DRAFT',
        'submit': action == 'SUBMIT',
      });

      _hasUnsavedChanges = false;

      if (mounted) {
        final successMsg = action == 'SUBMIT'
            ? "IA Marks submitted to HOD successfully!"
            : "IA Marks draft saved successfully.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(successMsg),
              backgroundColor: Colors.green),
        );
        await _fetchInitialData();
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String msg = "Submission failed. Please check inputs and try again.";
        bool isLockError = false;

        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            if (data['is_locked'] == true) {
              isLockError = true;
            }
            if (data['error'] != null) {
              msg = data['error'].toString();
              if (msg.contains("Locked") || msg.contains("finalized")) {
                isLockError = true;
              }
            } else if (data['detail'] != null) {
              msg = data['detail'].toString();
            } else if (data['non_field_errors'] != null) {
              msg = (data['non_field_errors'] is List)
                  ? (data['non_field_errors'] as List).join(", ")
                  : data['non_field_errors'].toString();
            }
          } else if (data is String && data.isNotEmpty) {
            msg = data;
          }
        }

        if (isLockError) {
          setState(() {
            _isLocked = true;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Semester Completed – Marks Locked",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lockReason ??
                  "This semester has been officially finalized. Normal editing, overwriting, and deletions are permanently disabled for all roles.",
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFB91C1C), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "To request an exceptional correction, submit an authorized correction request with a documented justification.",
                      style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2577),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text("Request Correction"),
            onPressed: () {
              Navigator.pop(ctx);
              _showCorrectionRequestDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showCorrectionRequestDialog([Map<String, dynamic>? preselectedStudent]) {
    if (_students.isEmpty) return;

    Map<String, dynamic> selectedStudent = preselectedStudent ?? _students.first;
    int studentId = selectedStudent['id'] as int;
    final currentMark = _controllers[studentId]?.text.trim() ?? '0';

    final requestedMarksCtrl = TextEditingController(text: currentMark);
    final reasonCtrl = TextEditingController();
    bool isSubmittingReq = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final maxMarks = int.tryParse(_maxMarksController.text.trim()) ?? 25;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.security_update_warning_rounded,
                    color: Color(0xFF0F2577), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Academic Mark Correction Request",
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
                  const Text(
                    "This assessment is permanently locked. Submitting this request creates an immutable audit trail and requires formal approval by the Principal or Academic Administrator.",
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Student Selector
                  DropdownButtonFormField<int>(
                    value: studentId,
                    decoration: const InputDecoration(
                      labelText: "Select Student",
                      border: OutlineInputBorder(),
                    ),
                    items: _students.map((s) {
                      return DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text("${s['usn'] ?? ''} - ${s['name'] ?? ''}",
                            style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          studentId = val;
                          selectedStudent = _students.firstWhere(
                              (s) => (s['id'] as int) == val,
                              orElse: () => _students.first);
                          final cur =
                              _controllers[val]?.text.trim() ?? '0';
                          requestedMarksCtrl.text = cur;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: currentMark,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: "Current Mark",
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: requestedMarksCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: "Corrected Mark (Max: $maxMarks)",
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Documented Reason / Justification *",
                      hintText:
                          "Enter detailed academic justification (e.g., Evaluation recheck, paper retotaling error)...",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogError!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmittingReq ? null : () => Navigator.pop(ctx),
                child: const Text("CANCEL"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2577),
                  foregroundColor: Colors.white,
                ),
                icon: isSubmittingReq
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text("Submit for Review"),
                onPressed: isSubmittingReq
                    ? null
                    : () async {
                        final reqText = requestedMarksCtrl.text.trim();
                        final reqVal = double.tryParse(reqText);
                        final reason = reasonCtrl.text.trim();

                        if (reqVal == null || reqVal < 0 || reqVal > maxMarks) {
                          setDialogState(() {
                            dialogError =
                                "Requested mark must be a valid number between 0 and $maxMarks.";
                          });
                          return;
                        }

                        if (reason.length < 5) {
                          setDialogState(() {
                            dialogError =
                                "Please provide a detailed justification (minimum 5 characters).";
                          });
                          return;
                        }

                        setDialogState(() {
                          isSubmittingReq = true;
                          dialogError = null;
                        });

                        try {
                          final dio = ApiClient().dio;

                          // If we don't have test id, ensure test is created/fetched
                          int? testId = _currentTestId;
                          if (testId == null) {
                            final testRes = await dio.post(
                              '/ia/ia-tests/create/',
                              data: {
                                'subject': widget.subjectId,
                                'ia_type': _iaType,
                                'ia_name': _iaNameController.text.trim(),
                                'max_marks': maxMarks,
                                'component_type':
                                    _iaType.startsWith('Lab') ? 'LAB' : 'THEORY',
                              },
                            );
                            testId = testRes.data['id'];
                            _currentTestId = testId;
                          }

                          await dio.post('/ia/corrections/request/', data: {
                            'ia_test_id': testId,
                            'student_id': studentId,
                            'requested_marks': reqVal,
                            'reason': reason,
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Correction request submitted successfully! Awaiting Principal / Administrator approval."),
                                backgroundColor: Color(0xFF0F2577),
                              ),
                            );
                          }
                        } catch (err) {
                          setDialogState(() {
                            isSubmittingReq = false;
                            if (err is DioException &&
                                err.response?.data != null) {
                              final d = err.response!.data;
                              dialogError = d is Map && d['error'] != null
                                  ? d['error'].toString()
                                  : err.toString();
                            } else {
                              dialogError = err.toString();
                            }
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 10),
            Text("Unsaved Changes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "You have unsaved changes in student marks. Are you sure you want to discard them and leave?",
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("STAY & EDIT"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DISCARD & LEAVE"),
          ),
        ],
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'PUBLISHED':
        return const Color(0xFFEFF6FF);
      case 'APPROVED':
      case 'VERIFIED':
        return const Color(0xFFECFDF5);
      case 'SUBMITTED':
        return const Color(0xFFFFFBEB);
      case 'RETURNED':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'PUBLISHED':
        return const Color(0xFF1D4ED8);
      case 'APPROVED':
      case 'VERIFIED':
        return const Color(0xFF047857);
      case 'SUBMITTED':
        return const Color(0xFFB45309);
      case 'RETURNED':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF475569);
    }
  }

  Widget _attendancePill({
    required String label,
    required bool isSelected,
    required Color activeColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSegment(int id, TextEditingController controller) {
    final isAb = _isAbsentMap[id] == true;
    final isEx = _isExemptedMap[id] == true;
    final isP = !isAb && !isEx;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _attendancePill(
            label: "P",
            isSelected: isP,
            activeColor: const Color(0xFF16A34A),
            onTap: _isReadOnly
                ? null
                : () {
                    setState(() {
                      _isAbsentMap[id] = false;
                      _isExemptedMap[id] = false;
                      _hasUnsavedChanges = true;
                    });
                  },
          ),
          _attendancePill(
            label: "AB",
            isSelected: isAb,
            activeColor: const Color(0xFFDC2626),
            onTap: _isReadOnly
                ? null
                : () {
                    setState(() {
                      _isAbsentMap[id] = true;
                      _isExemptedMap[id] = false;
                      controller.text = '0';
                      _hasUnsavedChanges = true;
                    });
                  },
          ),
          _attendancePill(
            label: "EX",
            isSelected: isEx,
            activeColor: const Color(0xFF7C3AED),
            onTap: _isReadOnly
                ? null
                : () {
                    setState(() {
                      _isAbsentMap[id] = false;
                      _isExemptedMap[id] = true;
                      controller.text = '0';
                      _hasUnsavedChanges = true;
                    });
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("IA Marks Entry",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
              Text(widget.subjectName ?? "Subject Assessment",
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF13246E),
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFE2E8F0), height: 1),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text("Error: $_errorMessage", textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _fetchStudents,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SEMESTER COMPLETED - MARKS LOCKED BANNER ---
                        if (_isLocked) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
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
                                  child: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 24),
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
                                              fontSize: 15,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 16),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _lockReason ??
                                            "Student marks for this semester are officially completed and finalized. Modifications, overwrites, and deletions are permanently restricted across all roles.",
                                        style: const TextStyle(
                                          color: Color(0xFF7F1D1D),
                                          fontSize: 12.5,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF991B1B),
                                          side: const BorderSide(color: Color(0xFFDC2626)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                                        label: const Text(
                                          "Request Academic Mark Correction",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        onPressed: () => _showCorrectionRequestDialog(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // --- SUBMITTED PENDING VERIFICATION BANNER ---
                        if (_testStatus == 'SUBMITTED' && !_isLocked) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Submitted to HOD – Pending Verification",
                                        style: TextStyle(
                                            color: Color(0xFF92400E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "These marks have been submitted for HOD review. Editing is temporarily locked awaiting verification or return.",
                                        style: TextStyle(color: Color(0xFF78350F), fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // --- APPROVED BANNER ---
                        if ((_testStatus == 'APPROVED' || _testStatus == 'VERIFIED') && !_isLocked) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 24),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Marks Approved by HOD",
                                        style: TextStyle(
                                            color: Color(0xFF065F46),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Assessment has been formally verified and approved by the Head of Department. Awaiting final publication to students.",
                                        style: TextStyle(color: Color(0xFF047857), fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // --- PUBLISHED BANNER ---
                        if (_testStatus == 'PUBLISHED' && !_isLocked) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.visibility_rounded, color: Color(0xFF2563EB), size: 24),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Marks Published to Students",
                                        style: TextStyle(
                                            color: Color(0xFF1E40AF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "This assessment is published and accessible on student portals. Official calculations are active.",
                                        style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // --- RETURNED FOR CORRECTION BANNER ---
                        if (_testStatus == 'RETURNED') ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.assignment_return_rounded,
                                      color: Color(0xFFD97706), size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Text(
                                            "Returned by HOD for Correction",
                                            style: TextStyle(
                                              color: Color(0xFF92400E),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.warning_amber_rounded,
                                              color: Color(0xFFD97706), size: 16),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _hodRemarks != null && _hodRemarks!.isNotEmpty
                                            ? "HOD Remarks: $_hodRemarks"
                                            : "The Head of Department has returned this assessment for correction. Please review marks and resubmit.",
                                        style: const TextStyle(
                                          color: Color(0xFF78350F),
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // --- Test Configuration Card ---
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Assessment Details",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (_isReadOnly)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusBgColor(_testStatus),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _getStatusTextColor(_testStatus).withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isLocked ? Icons.lock : Icons.shield_outlined,
                                              size: 13,
                                              color: _getStatusTextColor(_testStatus),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _isLocked ? "Locked" : _testStatus,
                                              style: TextStyle(
                                                color: _getStatusTextColor(_testStatus),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Assessment switcher dropdown if tests exist
                                if (_availableTests.isNotEmpty) ...[
                                  DropdownButtonFormField<int>(
                                    value: _currentTestId,
                                    decoration: const InputDecoration(
                                      labelText: "Select Configured Assessment",
                                      prefixIcon: Icon(Icons.assignment_outlined, color: Color(0xFF0F2577)),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _availableTests.map((t) {
                                      final tId = t['id'] as int;
                                      final tName = t['ia_name'] ?? t['ia_type'] ?? 'Test';
                                      final tMax = t['max_marks'] ?? 25;
                                      final tStatus = t['status'] ?? 'DRAFT';
                                      return DropdownMenuItem<int>(
                                        value: tId,
                                        child: Row(
                                          children: [
                                            Text("$tName (Max: $tMax)",
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusBgColor(tStatus),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                tStatus,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getStatusTextColor(tStatus)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newTestId) {
                                      if (newTestId != null) {
                                        final t = _availableTests.firstWhere((x) => x['id'] == newTestId);
                                        _onTestSelected(t);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _iaType,
                                        decoration: const InputDecoration(
                                            labelText: "Assessment Type", border: OutlineInputBorder()),
                                        items: _iaTypes.map((t) {
                                          String label = t;
                                          if (t == 'Test1') label = 'Test 1 (Theory IA)';
                                          if (t == 'Test2') label = 'Test 2 (Theory IA)';
                                          if (t == 'LabTest1') label = 'Test 1 (Lab IA)';
                                          if (t == 'LabTest2') label = 'Test 2 (Lab IA)';
                                          return DropdownMenuItem(value: t, child: Text(label));
                                        }).toList(),
                                        onChanged: _isReadOnly
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _iaType = val;
                                                    if (val == 'Test1') _iaNameController.text = 'Internal Assessment 1';
                                                    if (val == 'Test2') _iaNameController.text = 'Internal Assessment 2';
                                                    if (val == 'LabTest1') _iaNameController.text = 'Lab Internal Assessment 1';
                                                    if (val == 'LabTest2') _iaNameController.text = 'Lab Internal Assessment 2';
                                                    if (val == 'Presentation') _iaNameController.text = 'Presentation 1';
                                                    if (val == 'Assignment') _iaNameController.text = 'Assignment 1';
                                                    if (val == 'Quiz') _iaNameController.text = 'Quiz 1';
                                                    if (val == 'Custom') _iaNameController.text = 'Custom Assessment';
                                                  });
                                                  _onTypeOrBatchChanged();
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _maxMarksController,
                                        enabled: !_isReadOnly,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: "Max Marks", border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _iaNameController,
                                  enabled: !_isReadOnly,
                                  decoration: const InputDecoration(
                                      labelText: "Assessment Name", border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: _isReadOnly
                                            ? null
                                            : () async {
                                                final picked = await showDatePicker(
                                                  context: context,
                                                  initialDate: _assessmentDate ?? DateTime.now(),
                                                  firstDate: DateTime(2020),
                                                  lastDate: DateTime(2035),
                                                );
                                                if (picked != null) {
                                                  setState(() => _assessmentDate = picked);
                                                }
                                              },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: "Assessment Date",
                                            prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                            border: OutlineInputBorder(),
                                          ),
                                          child: Text(
                                            _assessmentDate != null
                                                ? "${_assessmentDate!.year}-${_assessmentDate!.month.toString().padLeft(2, '0')}-${_assessmentDate!.day.toString().padLeft(2, '0')}"
                                                : "Select Date",
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: _isReadOnly
                                            ? null
                                            : () async {
                                                final picked = await showDatePicker(
                                                  context: context,
                                                  initialDate: _submissionDeadline ??
                                                      DateTime.now().add(const Duration(days: 7)),
                                                  firstDate: DateTime(2020),
                                                  lastDate: DateTime(2035),
                                                );
                                                if (picked != null) {
                                                  setState(() => _submissionDeadline = picked);
                                                }
                                              },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: "Submission Deadline",
                                            prefixIcon: Icon(Icons.event_available_rounded, size: 18),
                                            border: OutlineInputBorder(),
                                          ),
                                          child: Text(
                                            _submissionDeadline != null
                                                ? "${_submissionDeadline!.year}-${_submissionDeadline!.month.toString().padLeft(2, '0')}-${_submissionDeadline!.day.toString().padLeft(2, '0')}"
                                                : "Select Deadline",
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_instructions != null && _instructions!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Instructions / Remarks:",
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF64748B))),
                                        const SizedBox(height: 2),
                                        Text(_instructions!,
                                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                                      ],
                                    ),
                                  ),
                                ],
                                if (_labBatches.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<int?>(
                                    value: _selectedBatchId,
                                    decoration: const InputDecoration(
                                      labelText: "Target Lab Batch",
                                      prefixIcon: Icon(Icons.group_work_rounded, color: Color(0xFF0F2577)),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text("All Enrolled Students (Full Class)"),
                                      ),
                                      ..._labBatches.map((b) => DropdownMenuItem<int?>(
                                            value: b['id'] as int,
                                            child: Text("${b['name']} (${b['student_count'] ?? 0} students)"),
                                          )),
                                    ],
                                    onChanged: _isReadOnly
                                        ? null
                                        : (val) {
                                            setState(() => _selectedBatchId = val);
                                            _fetchStudents();
                                          },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Student Roster ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Student Marks Roster",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Chip(
                              label: Text("${_students.length} Students",
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              backgroundColor: const Color(0xFFEFF6FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_students.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text("No enrolled students found for this subject.")),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _students.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final id = student['id'] as int;
                              final controller = _controllers[id]!;
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                elevation: 0.5,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: const Color(0xFF0F2577).withValues(alpha: 0.08),
                                            foregroundColor: const Color(0xFF0F2577),
                                            child: Text("${index + 1}",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(student['name'] ?? 'Unknown',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.w600, fontSize: 13.5)),
                                                Text("USN: ${student['usn'] ?? 'N/A'}",
                                                    style: TextStyle(
                                                        color: Colors.grey[600], fontSize: 11.5)),
                                              ],
                                            ),
                                          ),
                                          // Attendance segmented toggle
                                          _buildAttendanceSegment(id, controller),
                                          const SizedBox(width: 10),
                                          // Marks input field
                                          SizedBox(
                                            width: 65,
                                            height: 38,
                                            child: TextFormField(
                                              controller: controller,
                                              readOnly: _isReadOnly ||
                                                  (_isAbsentMap[id] == true) ||
                                                  (_isExemptedMap[id] == true),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(decimal: true),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 13.5, fontWeight: FontWeight.bold),
                                              onChanged: (_) {
                                                if (!_hasUnsavedChanges) {
                                                  setState(() => _hasUnsavedChanges = true);
                                                }
                                              },
                                              decoration: InputDecoration(
                                                contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 8),
                                                border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(6)),
                                                hintText: "0",
                                                filled: _isReadOnly ||
                                                    (_isAbsentMap[id] == true) ||
                                                    (_isExemptedMap[id] == true),
                                                fillColor: (_isAbsentMap[id] == true)
                                                    ? Colors.red.shade50
                                                    : (_isExemptedMap[id] == true)
                                                        ? Colors.purple.shade50
                                                        : (_isReadOnly
                                                            ? const Color(0xFFF1F5F9)
                                                            : Colors.white),
                                              ),
                                            ),
                                          ),
                                          if (_isLocked) ...[
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: const Icon(Icons.edit_note_rounded,
                                                  color: Color(0xFF0F2577), size: 22),
                                              tooltip: "Request mark correction",
                                              onPressed: () => _showCorrectionRequestDialog(student),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.comment_outlined,
                                              size: 13, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _remarksControllers[id],
                                              readOnly: _isReadOnly,
                                              style: const TextStyle(fontSize: 11.5),
                                              onChanged: (_) {
                                                if (!_hasUnsavedChanges) {
                                                  setState(() => _hasUnsavedChanges = true);
                                                }
                                              },
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                hintText:
                                                    "Remarks (optional, e.g., Medical leave, re-test)",
                                                hintStyle:
                                                    TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
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
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
        bottomNavigationBar: _students.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLocked
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF991B1B),
                          side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626)),
                        label: const Text(
                          "SEMESTER COMPLETED – MARKS LOCKED",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        onPressed: _showLockedDialog,
                      )
                    : _testStatus == 'SUBMITTED'
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFD97706), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "MARKS SUBMITTED – UNDER HOD REVIEW",
                                  style: TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : (_testStatus == 'APPROVED' || _testStatus == 'VERIFIED')
                            ? Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "MARKS APPROVED BY HOD (READ-ONLY)",
                                      style: TextStyle(
                                          color: Color(0xFF065F46),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : _testStatus == 'PUBLISHED'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.public_rounded, color: Color(0xFF2563EB), size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          "MARKS PUBLISHED TO STUDENTS (READ-ONLY)",
                                          style: TextStyle(
                                              color: Color(0xFF1E40AF),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF0F2577),
                                            side: const BorderSide(color: Color(0xFF0F2577), width: 1.5),
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.save_rounded, size: 18),
                                          label: const Text(
                                            "SAVE DRAFT",
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: _isSubmitting ? null : () => _submitMarks("DRAFT"),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F2577),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: _isSubmitting
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child: CircularProgressIndicator(
                                                      color: Colors.white, strokeWidth: 2))
                                              : const Icon(Icons.send_rounded, size: 18),
                                          label: Text(
                                            _testStatus == 'RETURNED' ? "RESUBMIT TO HOD" : "SUBMIT TO HOD",
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: _isSubmitting ? null : () => _submitMarks("SUBMIT"),
                                        ),
                                      ),
                                    ],
                                  ),
              ),
      ),
    );
  }
}

