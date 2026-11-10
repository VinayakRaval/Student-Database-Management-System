import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../models/assign_subject_model.dart';
import '../providers/assign_subject_provider.dart';
import 'package:frontend/core/utils/validation_utils.dart';

const String kSubjectAssignmentConflictMessage =
    "This subject is already assigned to another faculty member for the selected department, "
    "semester, and academic year. Each subject can be assigned to only one faculty member per "
    "academic offering. Please select a different subject or update the existing assignment.";

class AssignSubjectScreen extends ConsumerStatefulWidget {
  const AssignSubjectScreen({super.key});

  @override
  ConsumerState<AssignSubjectScreen> createState() => _AssignSubjectScreenState();
}

class _AssignSubjectScreenState extends ConsumerState<AssignSubjectScreen> {
  final _formKey = GlobalKey<FormState>();

  // Global Selections
  int? _selectedDept;
  int? _selectedSem;
  int? _selectedYear;

  // List of Rows: {'subject': String?, 'faculty': int?}
  List<Map<String, dynamic>> _rows = [{'subject': null, 'faculty': null}];

  // Dynamic Offering Department faculty cache for elective subjects: {departmentId: List<AssignOption>}
  final Map<int, List<AssignOption>> _offeringFacultiesCache = {};
  final Set<int> _loadingOfferingDeptIds = {};

  Future<void> _fetchOfferingDepartmentFaculty(int deptId) async {
    if (_offeringFacultiesCache.containsKey(deptId) || _loadingOfferingDeptIds.contains(deptId)) {
      return;
    }
    setState(() {
      _loadingOfferingDeptIds.add(deptId);
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/faculty/faculties/', queryParameters: {
        'department_id': deptId,
        'for_assignment': 'true',
        'page_size': 'all',
      });
      List<dynamic> rawList = [];
      if (res.data is List) {
        rawList = res.data as List;
      } else if (res.data is Map && res.data.containsKey('results') && res.data['results'] is List) {
        rawList = res.data['results'] as List;
      }
      final facs = rawList.map((e) => AssignOption.fromMap(e)).toList();
      if (mounted) {
        setState(() {
          _offeringFacultiesCache[deptId] = facs;
          // Restore existing assignment faculty for elective rows if not yet selected
          final currentSubjects = ref.read(assignSubjectProvider).availableSubjects;
          for (final row in _rows) {
            final subCode = row['subject'] as String?;
            if (subCode != null && row['faculty'] == null) {
              final sub = currentSubjects.firstWhere((s) => s.code == subCode, orElse: () => AssignOption(id: 0, name: ''));
              if (sub.isElective && sub.departmentId == deptId) {
                final existing = _findExistingAssignment(subCode);
                if (existing != null && facs.any((f) => f.id == existing.facultyId)) {
                  row['faculty'] = existing.facultyId;
                }
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading offering department faculties: $e");
      if (mounted) {
        setState(() {
          _offeringFacultiesCache[deptId] = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingOfferingDeptIds.remove(deptId);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignSubjectProvider.notifier).loadInitialData();
    });
  }

  // Helper to fetch cohort subjects and existing assignments when Dept/Sem/Year changes
  void _checkAndFetchSubjects() {
    if (_selectedDept != null && _selectedSem != null) {
      setState(() => _rows = [{'subject': null, 'faculty': null}]);
      ref.read(assignSubjectProvider.notifier).fetchSubjects(
            _selectedDept!,
            _selectedSem!,
            academicYearId: _selectedYear,
          );
    }
  }

  void _onYearChanged(int? val) {
    setState(() => _selectedYear = val);
    if (_selectedDept != null && _selectedSem != null && val != null) {
      ref.read(assignSubjectProvider.notifier).fetchExistingAssignments(
            _selectedDept!,
            _selectedSem!,
            val,
          );
    }
  }

  ExistingAssignment? _findExistingAssignment(String? code) {
    if (code == null || code.isEmpty) return null;
    final list = ref.read(assignSubjectProvider).existingAssignments;
    for (final e in list) {
      if (e.subjectCode.toUpperCase() == code.toUpperCase()) {
        if (_selectedYear == null || e.academicYearId == null || e.academicYearId == _selectedYear) {
          return e;
        }
      }
    }
    return null;
  }

  bool _isDuplicateInOtherRow(int currentIndex, String? code) {
    if (code == null || code.isEmpty) return false;
    for (int i = 0; i < _rows.length; i++) {
      if (i != currentIndex && _rows[i]['subject'] == code) {
        return true;
      }
    }
    return false;
  }

  void _addRow() {
    setState(() {
      _rows.add({
        'subject': null,
        'faculty': null,
      });
    });
  }

  void _removeRow(int index) {
    setState(() {
      if (_rows.length > 1) {
        _rows.removeAt(index);
      } else {
        _rows[0] = {'subject': null, 'faculty': null};
      }
    });
  }

  void _showConflictDialog({
    required String title,
    required String message,
    List<Map<String, dynamic>> conflicts = const [],
    bool allowUpdate = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                message,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              if (conflicts.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 6),
                const Text(
                  "Conflicting Subjects:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                ...conflicts.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${c['code']} - ${c['subjectName']}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Current Faculty: ${c['currentFaculty']}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                          ),
                          Text(
                            "New Proposed Faculty: ${c['newFaculty']}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF13246E), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Select Different Subject", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (allowUpdate)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _submit(updateExisting: true);
              },
              child: const Text("Update Existing Assignment"),
            ),
        ],
      ),
    );
  }

  void _submit({bool updateExisting = false}) {
    if (!_formKey.currentState!.validate()) {
      ValidationUtils.showValidationErrorSnackBar(context);
      return;
    }
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one assignment row")),
      );
      return;
    }

    // Check if all rows are filled
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row['subject'] == null || row['faculty'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select subject and faculty for row #${i + 1}")),
        );
        return;
      }
    }

    // Check intra-form duplicates
    final seen = <String>{};
    for (int i = 0; i < _rows.length; i++) {
      final code = _rows[i]['subject'] as String;
      if (seen.contains(code)) {
        _showConflictDialog(
          title: "Duplicate Subject Selected",
          message: kSubjectAssignmentConflictMessage,
          allowUpdate: false,
        );
        return;
      }
      seen.add(code);
    }

    // Validate faculty department match on frontend for elective & core subjects
    final state = ref.read(assignSubjectProvider);
    final subjectList = state.availableSubjects;
    for (int i = 0; i < _rows.length; i++) {
      final code = _rows[i]['subject'] as String;
      final facId = _rows[i]['faculty'] as int;
      final sub = subjectList.firstWhere(
        (s) => s.code == code,
        orElse: () => AssignOption(id: 0, name: ''),
      );
      if (sub.isElective && sub.departmentId != null) {
        final offeringFacs = _offeringFacultiesCache[sub.departmentId!] ?? [];
        if (offeringFacs.isNotEmpty && !offeringFacs.any((f) => f.id == facId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("For elective subject '${sub.code} - ${sub.name}', please select a faculty member from ${sub.departmentName ?? 'the offering department'}."),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else if (!sub.isElective) {
        if (state.faculties.isNotEmpty && !state.faculties.any((f) => f.id == facId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("For core subject '${sub.code} - ${sub.name}', please select a faculty member from the home department."),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    // Check conflicts with existing DB assignments
    if (!updateExisting) {
      final conflicts = <Map<String, dynamic>>[];
      for (final row in _rows) {
        final code = row['subject'] as String;
        final facId = row['faculty'] as int;
        final existing = _findExistingAssignment(code);
        if (existing != null && existing.facultyId != facId) {
          String newFacName = "Selected Faculty";
          for (final f in state.faculties) {
            if (f.id == facId) {
              newFacName = f.name;
              break;
            }
          }
          if (newFacName == "Selected Faculty") {
            for (final list in _offeringFacultiesCache.values) {
              for (final f in list) {
                if (f.id == facId) {
                  newFacName = f.name;
                  break;
                }
              }
            }
          }
          conflicts.add({
            'code': code,
            'subjectName': existing.subjectName,
            'currentFaculty': existing.professorName,
            'newFaculty': newFacName,
          });
        }
      }

      if (conflicts.isNotEmpty) {
        _showConflictDialog(
          title: "Subject Already Assigned",
          message: kSubjectAssignmentConflictMessage,
          conflicts: conflicts,
          allowUpdate: true,
        );
        return;
      }
    }

    final request = SubjectAssignmentRequest(
      departmentId: _selectedDept!,
      updateExisting: updateExisting,
      assignments: _rows.map((r) {
        return AssignmentItem(
          subjectCode: r['subject'],
          facultyId: r['faculty'],
          semesterId: _selectedSem!,
          academicYearId: _selectedYear!,
        );
      }).toList(),
    );

    ref.read(assignSubjectProvider.notifier).submitAssignment(request);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignSubjectProvider);

    final auth = p.Provider.of<AuthProvider>(context);
    final role = (auth.role ?? '').toUpperCase();
    final isHod = role == AppRoles.hod;
    final int? userDeptId = auth.userData?['department'] is int
        ? auth.userData!['department'] as int
        : int.tryParse(auth.userData?['department']?.toString() ?? '');
    final String? userDeptName = auth.userData?['department_name']?.toString();

    // For HOD: Filter departments to ONLY show their assigned department for cohort
    List<AssignOption> availableDepts = state.departments;
    if (isHod && userDeptId != null) {
      final filtered = state.departments.where((d) => d.id == userDeptId).toList();
      if (filtered.isNotEmpty) {
        availableDepts = filtered;
      } else {
        availableDepts = [AssignOption(id: userDeptId, name: userDeptName ?? "My Department")];
      }
    }

    // Listen for success or error
    ref.listen(assignSubjectProvider, (prev, next) {
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subjects Assigned Successfully!"), backgroundColor: Colors.green),
        );
        context.pop();
      }
      if (next.errorMessage != null) {
        final err = next.errorMessage!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
        if (err.contains("already assigned to another faculty member")) {
          _showConflictDialog(
            title: "Assignment Conflict",
            message: err,
            allowUpdate: true,
          );
        }
      }
    });

    // Auto-select Department
    if (isHod && userDeptId != null && _selectedDept != userDeptId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedDept = userDeptId;
          });
          _checkAndFetchSubjects();
        }
      });
    } else if (_selectedDept == null && availableDepts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedDept = availableDepts.first.id;
          });
          _checkAndFetchSubjects();
        }
      });
    }

    // Auto-select Semester
    if (_selectedSem == null && state.semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedSem = state.semesters.first.id;
          });
          _checkAndFetchSubjects();
        }
      });
    }

    // Auto-select Academic Year
    if (_selectedYear == null && state.academicYears.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedYear = state.academicYears.first.id;
          });
        }
      });
    }

    // Deduplicate available subjects by subject code
    final uniqueSubjectMap = <String, AssignOption>{};
    for (final s in state.availableSubjects) {
      if (s.code != null && s.code!.isNotEmpty && !uniqueSubjectMap.containsKey(s.code)) {
        uniqueSubjectMap[s.code!] = s;
      }
    }
    final subjectList = uniqueSubjectMap.values.toList();

    // Ensure at least one default row is always present
    if (_rows.isEmpty) {
      _rows.add({'subject': null, 'faculty': null});
    }

    // Auto-populate first row if subject not yet chosen and subjects available
    if (subjectList.isNotEmpty && (_rows.isEmpty || (_rows.length == 1 && _rows[0]['subject'] == null))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_rows.isEmpty || (_rows.length == 1 && _rows[0]['subject'] == null)) && subjectList.isNotEmpty) {
          final firstSub = subjectList.first;
          final firstCode = firstSub.code;
          final existing = _findExistingAssignment(firstCode);
          int? initialFacultyId;
          if (firstSub.isElective) {
            if (firstSub.departmentId != null) {
              _fetchOfferingDepartmentFaculty(firstSub.departmentId!);
              final cached = _offeringFacultiesCache[firstSub.departmentId!];
              if (existing != null && cached != null && cached.any((f) => f.id == existing.facultyId)) {
                initialFacultyId = existing.facultyId;
              }
            }
          } else {
            initialFacultyId = existing?.facultyId ?? (state.faculties.isNotEmpty ? state.faculties.first.id : null);
          }
          setState(() {
            if (_rows.isEmpty) {
              _rows.add({
                'subject': firstCode,
                'faculty': initialFacultyId,
              });
            } else {
              _rows[0] = {
                'subject': firstCode,
                'faculty': initialFacultyId,
              };
            }
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Assign Subjects"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. GLOBAL CONFIGURATION CARD ---
              _buildSectionTitle("Configuration"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDropdown(
                      label: isHod ? "Student Cohort Department" : "Department",
                      value: _selectedDept,
                      items: availableDepts,
                      onChanged: isHod
                          ? null
                          : (val) {
                              setState(() => _selectedDept = val);
                              _checkAndFetchSubjects();
                            },
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: "Semester",
                            value: _selectedSem,
                            items: state.semesters,
                            onChanged: (val) {
                              setState(() => _selectedSem = val);
                              _checkAndFetchSubjects();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            label: "Academic Year",
                            value: _selectedYear,
                            items: state.academicYears,
                            onChanged: _onYearChanged,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- 1b. EXISTING COHORT ASSIGNMENTS OVERVIEW ---
              if (state.existingAssignments.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD0DDFC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: Color(0xFF13246E)),
                          const SizedBox(width: 8),
                          Text(
                            "Current Cohort Assignments (${state.existingAssignments.length})",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E), fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Each subject can only be assigned to one faculty member for this offering.",
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: state.existingAssignments.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13246E),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    e.subjectCode,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  e.professorName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // --- 2. ASSIGNMENT ROWS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Subject Mappings"),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Add Row"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (_selectedDept != null && _selectedSem != null)
                        ? _addRow
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (state.isLoading && subjectList.isEmpty && _selectedDept != null)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                ),

              if (_rows.isEmpty && !state.isLoading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        "No subjects mapped yet",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Click 'Add Row' above to map subjects to faculty.",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rows.length,
                separatorBuilder: (c, i) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  final currentSubject = row['subject'] as String?;
                  final safeSubjectValue = subjectList.any((s) => s.code == currentSubject) ? currentSubject : null;

                  final currentFaculty = row['faculty'] as int?;
                  final chosenSub = subjectList.firstWhere(
                    (s) => s.code == currentSubject,
                    orElse: () => AssignOption(id: 0, name: ''),
                  );
                  final bool isElectiveSub = chosenSub.id != 0 && chosenSub.isElective && chosenSub.departmentId != null;
                  if (isElectiveSub && !_offeringFacultiesCache.containsKey(chosenSub.departmentId!) && !_loadingOfferingDeptIds.contains(chosenSub.departmentId!)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _fetchOfferingDepartmentFaculty(chosenSub.departmentId!);
                      }
                    });
                  }
                  final List<AssignOption> rowFaculties = isElectiveSub
                      ? (_offeringFacultiesCache[chosenSub.departmentId!] ?? [])
                      : state.faculties;
                  final safeFacultyValue = rowFaculties.any((f) => f.id == currentFaculty) ? currentFaculty : null;

                  final isDuplicate = _isDuplicateInOtherRow(index, currentSubject);
                  final existingAssignment = _findExistingAssignment(currentSubject);
                  final bool isConflictWithExisting = existingAssignment != null &&
                      currentFaculty != null &&
                      existingAssignment.facultyId != currentFaculty;
                  final bool isSameAsExisting = existingAssignment != null &&
                      currentFaculty != null &&
                      existingAssignment.facultyId == currentFaculty;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDuplicate
                            ? Colors.red.shade400
                            : (isConflictWithExisting ? Colors.orange.shade400 : Colors.grey.shade200),
                        width: (isDuplicate || isConflictWithExisting) ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Subject Mapping #${index + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF13246E),
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(_rows.length > 1 ? Icons.delete_outline : Icons.clear_rounded, color: _rows.length > 1 ? Colors.red : Colors.grey.shade600, size: 20),
                              tooltip: _rows.length > 1 ? "Remove Mapping" : "Clear Selection",
                              onPressed: () => _removeRow(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Subject & Faculty Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subject Dropdown
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: "Select Subject *",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                value: safeSubjectValue,
                                isExpanded: true,
                                hint: Text(
                                  subjectList.isEmpty ? "No subjects available" : "Select Subject",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                items: subjectList.map((s) {
                                  final existing = _findExistingAssignment(s.code);
                                  String label = s.isElective
                                      ? "${s.code} - ${s.name} (Offered by ${s.departmentName ?? 'Elective'})"
                                      : "${s.code} - ${s.name}";
                                  if (existing != null) {
                                    label += " [Assigned: ${existing.professorName}]";
                                  }
                                  return DropdownMenuItem<String>(
                                    value: s.code,
                                    child: Text(
                                      label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: existing != null ? const Color(0xFF13246E) : Colors.black87,
                                        fontWeight: existing != null ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _rows[index]['subject'] = val;
                                    // Clear faculty immediately to prevent invalid or stale state
                                    _rows[index]['faculty'] = null;

                                    final chosen = subjectList.firstWhere(
                                      (s) => s.code == val,
                                      orElse: () => AssignOption(id: 0, name: ''),
                                    );
                                    if (chosen.id != 0 && chosen.isElective && chosen.departmentId != null) {
                                      _fetchOfferingDepartmentFaculty(chosen.departmentId!);
                                      final cached = _offeringFacultiesCache[chosen.departmentId!];
                                      final existing = _findExistingAssignment(val);
                                      if (existing != null && cached != null && cached.any((f) => f.id == existing.facultyId)) {
                                        _rows[index]['faculty'] = existing.facultyId;
                                      }
                                    } else {
                                      // Auto-set faculty to current professor if already assigned
                                      final existing = _findExistingAssignment(val);
                                      if (existing != null && existing.facultyId > 0 && state.faculties.any((f) => f.id == existing.facultyId)) {
                                        _rows[index]['faculty'] = existing.facultyId;
                                      }
                                    }
                                  });
                                },
                                validator: (val) {
                                  if (val == null || val.isEmpty) return "This field is mandatory.";
                                  if (_isDuplicateInOtherRow(index, val)) {
                                    return "Duplicate subject in form";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Faculty Dropdown
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                decoration: InputDecoration(
                                  labelText: isElectiveSub
                                      ? "Assigned Faculty (${chosenSub.departmentName ?? 'Offering Dept'}) *"
                                      : "Assigned Faculty *",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                value: safeFacultyValue,
                                isExpanded: true,
                                hint: (isElectiveSub && _loadingOfferingDeptIds.contains(chosenSub.departmentId))
                                    ? const Text("Loading offering faculty...", style: TextStyle(fontSize: 13, color: Colors.blueGrey))
                                    : const Text("Select Faculty", style: TextStyle(fontSize: 13)),
                                items: rowFaculties.map((f) {
                                  return DropdownMenuItem<int>(
                                    value: f.id,
                                    child: Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _rows[index]['faculty'] = val),
                                validator: (val) => val == null ? "This field is mandatory." : null,
                              ),
                            ),
                          ],
                        ),

                        // Inline validation feedback
                        if (isDuplicate) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    kSubjectAssignmentConflictMessage,
                                    style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isConflictWithExisting) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 16),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        kSubjectAssignmentConflictMessage,
                                        style: TextStyle(color: Color(0xFF7A4A00), fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Currently assigned to: ${existingAssignment.professorName}. Submitting will prompt to update the assignment.",
                                  style: TextStyle(color: Colors.brown.shade700, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isSameAsExisting) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "Currently assigned to ${existingAssignment.professorName}",
                                style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // --- 3. SUBMIT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : () => _submit(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SUBMIT ASSIGNMENTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey));
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<AssignOption> items,
    required Function(int?)? onChanged,
  }) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? "This field is mandatory." : null,
    );
  }
}