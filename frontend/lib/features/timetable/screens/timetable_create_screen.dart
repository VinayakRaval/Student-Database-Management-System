import 'package:frontend/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../providers/timetable_provider.dart';
import 'package:frontend/core/utils/validation_utils.dart';
import '../models/timetable_model.dart';
import '../widgets/add_slot_dialog.dart';
import '../widgets/official_timetable_header.dart';
import '../../subjects/models/assign_subject_model.dart';
import '../../subjects/providers/assign_subject_provider.dart'; 

class TimetableCreateScreen extends ConsumerStatefulWidget {
  const TimetableCreateScreen({super.key});

  @override
  ConsumerState<TimetableCreateScreen> createState() => _TimetableCreateScreenState();
}

class _TimetableCreateScreenState extends ConsumerState<TimetableCreateScreen> {
  int? _selectedDept;
  int? _selectedSem;
  int? _selectedAy;
  DateTime? _effectiveDate;
  int? _selectedClassTeacher;
  List<AssignOption> _departmentFaculties = [];
  bool _isLoadingFaculties = false;
  
  final List<Map<String, dynamic>> _slots = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignSubjectProvider.notifier).loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(assignSubjectProvider);
    final timetableState = ref.watch(timetableProvider);

    final auth = p.Provider.of<AuthProvider>(context);
    final role = (auth.role ?? '').toUpperCase();
    final isHod = role == AppRoles.hod;
    final int? userDeptId = auth.userData?['department'] is int
        ? auth.userData!['department'] as int
        : int.tryParse(auth.userData?['department']?.toString() ?? '');
    final String? userDeptName = auth.userData?['department_name']?.toString();
    final bool hodHasNoDept = isHod && userDeptId == null;

    // For HOD: Filter departments to ONLY show their assigned department!
    List<AssignOption> availableDepts = configState.departments;
    if (isHod && userDeptId != null) {
      final filtered = configState.departments.where((d) => d.id == userDeptId).toList();
      if (filtered.isNotEmpty) {
        availableDepts = filtered;
      } else {
        availableDepts = [AssignOption(id: userDeptId, name: userDeptName ?? "My Department")];
      }
    }

    String selectedDeptName = '';
    if (isHod) {
      selectedDeptName = userDeptName ?? 'My Department';
    } else if (_selectedDept != null) {
      final d = availableDepts.firstWhere((e) => e.id == _selectedDept, orElse: () => AssignOption(id: 0, name: ''));
      selectedDeptName = d.name;
    }

    String selectedAyName = '';
    if (_selectedAy != null) {
      final ay = configState.academicYears.firstWhere((e) => e.id == _selectedAy, orElse: () => AssignOption(id: 0, name: ''));
      selectedAyName = ay.name;
    }

    String selectedClassTeacherName = '';
    if (_selectedClassTeacher != null && _departmentFaculties.isNotEmpty) {
      final match = _departmentFaculties.firstWhere((f) => f.id == _selectedClassTeacher, orElse: () => AssignOption(id: 0, name: ''));
      if (match.id != 0) {
        selectedClassTeacherName = match.name;
      }
    }

    ref.listen(timetableProvider, (prev, next) {
      if (next.isSuccess) {
        ref.invalidate(timetableListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Timetable Created Successfully!"), backgroundColor: Colors.green),
        );
        context.pop();
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red),
        );
      }
    });

    // Auto-select department: For HOD, force userDeptId
    if (isHod && userDeptId != null) {
      if (_selectedDept != userDeptId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedDept != userDeptId) {
            setState(() {
              _selectedDept = userDeptId;
            });
            _fetchAssignments();
          }
        });
      }
    } else if (_selectedDept == null && availableDepts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDept == null) {
          setState(() {
            _selectedDept = availableDepts.first.id;
          });
          _fetchAssignments();
        }
      });
    }

    // Auto-select semester if available and not selected
    if (_selectedSem == null && configState.semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSem == null) {
          final sem3 = configState.semesters.firstWhere((s) => s.id == 3, orElse: () => configState.semesters.first);
          setState(() {
            _selectedSem = sem3.id;
          });
          _fetchAssignments();
        }
      });
    }

    // Auto-select academic year if available and not selected (prefer 2026-2027)
    if (_selectedAy == null && configState.academicYears.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedAy == null) {
          final preferred = configState.academicYears.firstWhere(
            (ay) => ay.name.contains('2026-2027') || ay.name.contains('2026-27'),
            orElse: () => configState.academicYears.first,
          );
          setState(() {
            _selectedAy = preferred.id;
          });
          _fetchAssignments();
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Create Timetable"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: (_slots.isEmpty || hodHasNoDept) ? null : _submitTimetable,
            child: const Text("Save Draft", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (configState.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: LinearProgressIndicator(),
              ),

            // Error banner if HOD has no department assigned
            if (hodHasNoDept) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "No department is assigned to your HOD profile. Timetable creation is disabled until an administrator assigns your department.",
                        style: TextStyle(color: Color(0xFF7F1D1D), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // --- OFFICIAL TIMETABLE HEADER ---
            OfficialTimetableHeader(
              departmentName: selectedDeptName.isNotEmpty ? selectedDeptName : 'Select Department',
              semesterNo: _selectedSem,
              academicYear: selectedAyName,
              classTeacherName: selectedClassTeacherName,
              effectiveDate: _effectiveDate,
              onEffectiveDateChanged: (newDate) {
                setState(() {
                  _effectiveDate = newDate;
                });
              },
            ),
            const SizedBox(height: 16),

            // --- CONFIGURATION ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: isHod ? "Department (Your Assigned Department) *" : "Department *",
                      errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5)),
                      focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5)),
                      border: const OutlineInputBorder(),
                      prefixIcon: isHod ? const Icon(Icons.lock_outline, size: 20) : null,
                    ),
                    value: (availableDepts.any((e) => e.id == _selectedDept))
                        ? _selectedDept
                        : (availableDepts.isNotEmpty ? availableDepts.first.id : null),
                    hint: const Text("Select Department"),
                    items: availableDepts.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    onChanged: isHod
                        ? null
                        : (val) {
                            setState(() => _selectedDept = val);
                            _fetchAssignments();
                          },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: "Semester *", border: OutlineInputBorder(), errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5)), focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5))),
                          value: (configState.semesters.any((e) => e.id == _selectedSem)) ? _selectedSem : null,
                          hint: const Text("Select Semester"),
                          items: configState.semesters.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                          onChanged: (val) { setState(() => _selectedSem = val); _fetchAssignments(); },
                          validator: (val) => ValidationUtils.mandatorySelect(val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: "Academic Year *",
                                  errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5)),
                                  focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5)),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                value: (configState.academicYears.any((e) => e.id == _selectedAy)) ? _selectedAy : null,
                                hint: const Text("Select Academic Year"),
                                items: configState.academicYears.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                                onChanged: (val) { setState(() => _selectedAy = val); _fetchAssignments(); },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: "Add Custom Academic Year",
                              child: InkWell(
                                onTap: _showAddAcademicYearDialog,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFC7D2FE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, size: 18, color: Color(0xFF13246E)),
                                      SizedBox(width: 4),
                                      Text(
                                        "Custom",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF13246E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Class Teacher selection from department faculties
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: "Class Teacher (Department Faculty) *",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_pin_rounded, color: Color(0xFF13246E)),
                      helperText: "Assign this faculty member as Class Teacher for Semester ${_selectedSem ?? ''} students",
                      helperStyle: const TextStyle(color: Color(0xFF13246E), fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                    value: (_departmentFaculties.any((f) => f.id == _selectedClassTeacher))
                        ? _selectedClassTeacher
                        : null,
                    hint: Text(_isLoadingFaculties
                        ? "Loading department faculties..."
                        : (_departmentFaculties.isEmpty ? "Select Department to load faculty list" : "Select Class Teacher")),
                    items: _departmentFaculties.map((f) {
                      return DropdownMenuItem<int>(
                        value: f.id,
                        child: Text(
                          f.name + (f.code != null && f.code!.isNotEmpty ? ' (${f.code})' : ''),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedClassTeacher = val;
                      });
                    },
                    validator: (val) => val == null ? "Please select a Class Teacher for this semester" : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- SLOTS HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Weekly Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add Slot"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                  onPressed: (!hodHasNoDept && _selectedDept != null && _selectedSem != null && _selectedAy != null)
                      ? () => _showAddSlotDialog(timetableState.availableAssignments)
                      : null,
                ),
              ],
            ),
            
            const SizedBox(height: 10),

            if (_slots.isEmpty)
              const Padding(padding: EdgeInsets.all(40.0), child: Center(child: Text("No slots added. Click 'Add Slot' to begin.", style: TextStyle(color: Colors.grey)))),

            // --- DAY LIST ---
            ...["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((day) => _buildDaySection(day, timetableState.availableAssignments)),
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(String day, List<AssignmentOption> assignments) {
    final daySlots = _slots.where((s) => s['day'] == day).toList();
    daySlots.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time']));

    if (daySlots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Chip(
            backgroundColor: const Color(0xFF13246E),
            label: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        ...daySlots.map((slot) {
          final isBatchWise = slot['is_batch_wise'] == true || (slot['batches'] is List && (slot['batches'] as List).isNotEmpty);
          final batches = isBatchWise ? (slot['batches'] as List? ?? []) : [];

          // Visual break indicators
          final start = slot['start_time'] as String;
          Widget? breakWidget;
          if (start.startsWith("11:30")) breakWidget = _buildBreakDivider("BREAK (11:20 - 11:30)");
          if (start.startsWith("14:00") || start.startsWith("13:20")) breakWidget = _buildBreakDivider("LUNCH BREAK (01:20 - 02:00)");

          if (isBatchWise) {
            return Column(
              children: [
                ?breakWidget,
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.science_outlined, color: Color(0xFF13246E), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              TimeTable.formatTimeRange12(slot['start_time'], slot['end_time']),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${batches.length} BATCHES",
                                style: const TextStyle(color: Color(0xFF3730A3), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (slot['allow_co_teaching'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "CO-TEACHING",
                                  style: TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _slots.remove(slot)),
                            ),
                          ],
                        ),
                        const Divider(height: 12, color: Color(0xFFF1F5F9)),
                        // Display Batch rows (Req 9)
                        ...batches.map((b) {
                          final bMap = Map<String, dynamic>.from(b as Map);
                          final bAssign = assignments.firstWhere(
                            (a) => a.id == bMap['assignment'],
                            orElse: () => AssignmentOption(id: 0, subjectName: 'Unknown', facultyName: ''),
                          );
                          final bName = bMap['batch_name'] ?? 'Batch';
                          final room = (bMap['lab_room'] != null && bMap['lab_room'].toString().isNotEmpty)
                              ? " • Room: ${bMap['lab_room']}"
                              : "";
                          final timeStr = (bMap['start_time'] != null && bMap['start_time'] != slot['start_time'])
                              ? " (${TimeTable.formatTimeRange12(bMap['start_time'], bMap['end_time'])})"
                              : "";

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13246E),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${bAssign.subjectName}$room$timeStr • Prof: ${bAssign.facultyName}",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Single regular class slot
          final assignment = assignments.firstWhere(
            (a) => a.id == slot['assignment'],
            orElse: () => AssignmentOption(id: 0, subjectName: 'Unknown', facultyName: ''),
          );

          final hasDept = assignment.subjectDepartment != null && assignment.subjectDepartment!.trim().isNotEmpty;
          final deptTag = hasDept ? " [${assignment.subjectDepartment}]" : "";
          final codeTag = (assignment.subjectCode != null && assignment.subjectCode!.trim().isNotEmpty) ? " (${assignment.subjectCode})" : "";

          return Column(
            children: [
              ?breakWidget,
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFF13246E)),
                  title: Text(TimeTable.formatTimeRange12(slot['start_time'], slot['end_time']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text("${assignment.subjectName}$codeTag$deptTag (${assignment.facultyName})", style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _slots.remove(slot)),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildBreakDivider(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      color: Colors.amber[100],
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
    );
  }

  Future<void> _fetchDepartmentFaculties(int deptId) async {
    setState(() {
      _isLoadingFaculties = true;
    });
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/faculty/faculties/', queryParameters: {
        'department_id': deptId,
        'for_assignment': 'true',
        'page_size': 'all',
      });
      List<dynamic> raw = [];
      if (res.data is List) {
        raw = res.data;
      } else if (res.data is Map && res.data['results'] is List) {
        raw = res.data['results'];
      }
      final list = raw.map((e) => AssignOption.fromMap(e)).toList();
      if (mounted) {
        setState(() {
          _departmentFaculties = list;
          _isLoadingFaculties = false;
          if (_selectedClassTeacher != null && !list.any((f) => f.id == _selectedClassTeacher)) {
            _selectedClassTeacher = list.isNotEmpty ? list.first.id : null;
          } else if (_selectedClassTeacher == null && list.isNotEmpty) {
            _selectedClassTeacher = list.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _departmentFaculties = [];
          _isLoadingFaculties = false;
        });
      }
    }
  }

  void _fetchAssignments() {
    if (_selectedDept != null) {
      _fetchDepartmentFaculties(_selectedDept!);
    }
    if (_selectedDept != null && _selectedSem != null && _selectedAy != null) {
      setState(() => _slots.clear());
      ref.read(timetableProvider.notifier).fetchAssignments(_selectedDept!, _selectedSem!, _selectedAy!);
    }
  }

  void _submitTimetable() {
    if (_selectedDept == null || _selectedSem == null || _selectedAy == null) {
      ValidationUtils.showValidationErrorSnackBar(context);
      return;
    }
    if (_selectedClassTeacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Class Teacher from the department faculties."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_slots.isEmpty) {
      ValidationUtils.showValidationErrorSnackBar(context, "Please add at least one schedule slot before submitting.");
      return;
    }
    final payload = {
      "department": _selectedDept,
      "semester": _selectedSem,
      "academic_year": _selectedAy,
      "class_teacher": _selectedClassTeacher,
      "effective_date": _effectiveDate != null ? DateFormat('yyyy-MM-dd').format(_effectiveDate!) : null,
      "remarks": "Created via App",
      "slots": _slots 
    };
    ref.read(timetableProvider.notifier).createTimetable(payload);
  }

  // --- SHOW ADD SLOT DIALOG (Matching Image 1) ---

  Future<void> _showAddAcademicYearDialog() async {
    final yearController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: Color(0xFF13246E)),
                SizedBox(width: 10),
                Text("Add Academic Year", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Enter academic year in standard format (e.g., 2026-2027 or 2027-2028).",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: yearController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Academic Year *",
                      hintText: "e.g. 2026-2027",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.date_range_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return "Please enter an academic year";
                      }
                      if (!RegExp(r'^\d{4}-\d{2,4}$').hasMatch(val.trim())) {
                        return "Format should be YYYY-YYYY (e.g. 2026-2027)";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
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
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        final val = yearController.text.trim();
                        final newAy = await ref.read(assignSubjectProvider.notifier).addAcademicYear(val);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (!mounted) return;
                        if (newAy != null) {
                          setState(() {
                            _selectedAy = newAy.id;
                          });
                          _fetchAssignments();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Academic Year '$val' added and selected!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Failed to create academic year. Please check format or retry."),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("ADD YEAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSlotDialog(List<AssignmentOption> assignments) {
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No subjects available for the selected department/semester.")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AddClassSlotDialog(
        availableAssignments: assignments,
        onSave: (newSlot) {
          setState(() {
            _slots.add(newSlot);
          });
        },
      ),
    );
  }
}
