import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../models/assign_subject_model.dart';
import '../providers/assign_subject_provider.dart';

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
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignSubjectProvider.notifier).loadInitialData();
    });
  }

  // Helper to fetch cohort subjects when Dept/Sem changes
  void _checkAndFetchSubjects() {
    if (_selectedDept != null && _selectedSem != null) {
      setState(() => _rows = []);
      ref.read(assignSubjectProvider.notifier).fetchSubjects(
            _selectedDept!,
            _selectedSem!,
          );
    }
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
      _rows.removeAt(index);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
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

    final request = SubjectAssignmentRequest(
      departmentId: _selectedDept!,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red),
        );
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

    // Auto-add first row if empty and subjects available
    if (subjectList.isNotEmpty && _rows.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _rows.isEmpty && subjectList.isNotEmpty) {
          setState(() {
            _rows.add({
              'subject': subjectList.first.code,
              'faculty': state.faculties.isNotEmpty ? state.faculties.first.id : null,
            });
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
                            onChanged: (val) => setState(() => _selectedYear = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- 2. ASSIGNMENT ROWS & ELECTIVE SELECTION ---
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
                  final currentSubject = row['subject'];
                  final safeSubjectValue = subjectList.any((s) => s.code == currentSubject) ? currentSubject : null;

                  final currentFaculty = row['faculty'];
                  final safeFacultyValue = state.faculties.any((f) => f.id == currentFaculty) ? currentFaculty : null;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
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
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: "Remove Mapping",
                              onPressed: () => _removeRow(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Subject & Faculty Row
                        Row(
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
                                  final label = s.isElective
                                      ? "${s.code} - ${s.name} (${s.departmentName ?? 'Elective'})"
                                      : "${s.code} - ${s.name}";
                                  return DropdownMenuItem<String>(
                                    value: s.code,
                                    child: Text(
                                      label,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _rows[index]['subject'] = val),
                                validator: (val) => val == null ? "Subject is required" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Faculty Dropdown
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                decoration: InputDecoration(
                                  labelText: "Assigned Faculty *",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                value: safeFacultyValue,
                                isExpanded: true,
                                hint: const Text("Select Faculty", style: TextStyle(fontSize: 13)),
                                items: state.faculties.map((f) {
                                  return DropdownMenuItem<int>(
                                    value: f.id,
                                    child: Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _rows[index]['faculty'] = val),
                                validator: (val) => val == null ? "Faculty is required" : null,
                              ),
                            ),
                          ],
                        ),
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
                  onPressed: state.isLoading ? null : _submit,
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
      validator: (val) => val == null ? "Required" : null,
    );
  }
}