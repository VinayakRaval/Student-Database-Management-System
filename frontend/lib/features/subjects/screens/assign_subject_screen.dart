import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  // List of Rows (Subject Code, Faculty ID)
  // Each item is a map: {'subject': 'CS101', 'faculty': 5}
  List<Map<String, dynamic>> _rows = [];

  // Helper to fetch subjects when Dept/Sem changes
  void _checkAndFetchSubjects() {
    if (_selectedDept != null && _selectedSem != null) {
      // Clear existing rows if context changes to prevent mismatches
      setState(() => _rows = []); 
      ref.read(assignSubjectProvider.notifier).fetchSubjects(_selectedDept!, _selectedSem!);
    }
  }

  void _addRow() {
    setState(() {
      _rows.add({'subject': null, 'faculty': null});
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least one assignment row")));
      return;
    }

    // Check if all rows are filled
    for (var row in _rows) {
      if (row['subject'] == null || row['faculty'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all rows")));
        return;
      }
    }

    final request = SubjectAssignmentRequest(
      departmentId: _selectedDept!,
      assignments: _rows.map((r) => AssignmentItem(
        subjectCode: r['subject'],
        facultyId: r['faculty'],
        semesterId: _selectedSem!,
        academicYearId: _selectedYear!,
      )).toList(),
    );

    ref.read(assignSubjectProvider.notifier).submitAssignment(request);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignSubjectProvider);

    // Listen for success
    ref.listen(assignSubjectProvider, (prev, next) {
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subjects Assigned Successfully!"), backgroundColor: Colors.green));
        context.pop();
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red));
      }
    });

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
              // --- 1. GLOBAL SETTINGS ---
              _buildSectionTitle("Configuration"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildDropdown(
                      label: "Department",
                      value: _selectedDept,
                      items: state.departments,
                      onChanged: (val) {
                        setState(() => _selectedDept = val);
                        _checkAndFetchSubjects();
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildDropdown(
                      label: "Semester",
                      value: _selectedSem,
                      items: state.semesters,
                      onChanged: (val) {
                        setState(() => _selectedSem = val);
                        _checkAndFetchSubjects();
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildDropdown(
                      label: "Academic Year",
                      value: _selectedYear,
                      items: state.academicYears,
                      onChanged: (val) => setState(() => _selectedYear = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- 2. ASSIGNMENT ROWS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Mappings"),
                  TextButton.icon(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF13246E)),
                    label: const Text("Add Row", style: TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold)),
                    onPressed: (state.availableSubjects.isNotEmpty && _selectedYear != null) 
                      ? _addRow 
                      : null, // Disable if config incomplete
                  ),
                ],
              ),
              
              if (state.isLoading && state.availableSubjects.isEmpty && _selectedDept != null)
                const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator())),

              if (state.availableSubjects.isEmpty && _selectedDept != null && !state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0), 
                  child: Center(child: Text("No subjects found for this Department/Semester", style: TextStyle(color: Colors.grey)))
                ),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rows.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        // Subject Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              hint: const Text("Select Subject"),
                              value: _rows[index]['subject'],
                              isExpanded: true,
                              items: state.availableSubjects.map((s) {
                                return DropdownMenuItem(value: s.code, child: Text("${s.code} - ${s.name}"));
                              }).toList(),
                              onChanged: (val) => setState(() => _rows[index]['subject'] = val),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 30),
                        // Faculty Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              hint: const Text("Select Faculty"),
                              value: _rows[index]['faculty'],
                              isExpanded: true,
                              items: state.faculties.map((f) {
                                return DropdownMenuItem(value: f.id, child: Text(f.name));
                              }).toList(),
                              onChanged: (val) => setState(() => _rows[index]['faculty'] = val),
                            ),
                          ),
                        ),
                        // Remove Button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeRow(index),
                        )
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

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
                      : const Text("SUBMIT ASSIGNMENTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    required Function(int?) onChanged,
  }) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? "Required" : null,
    );
  }
}