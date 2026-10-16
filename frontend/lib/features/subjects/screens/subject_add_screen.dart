import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../models/subject_model.dart';
import '../providers/subject_provider.dart';

class SubjectAddScreen extends ConsumerStatefulWidget {
  const SubjectAddScreen({super.key});

  @override
  ConsumerState<SubjectAddScreen> createState() => _SubjectAddScreenState();
}

class _SubjectAddScreenState extends ConsumerState<SubjectAddScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  int? _selectedDepartment;
  int? _selectedSemester;
  int? _selectedSchema;
  bool _isElective = false;

  // Elective Cross-Department Selection
  int? _selectedOfferingDepartment;
  int? _selectedOfferingSubjectId;
  List<Map<String, dynamic>> _offeringSubjects = [];
  bool _isLoadingOfferingSubjects = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subjectProvider.notifier).loadDropdowns();
    });
  }

  Future<void> _loadOfferingSubjects() async {
    if (_selectedOfferingDepartment == null) return;
    setState(() {
      _isLoadingOfferingSubjects = true;
      _offeringSubjects = [];
      _selectedOfferingSubjectId = null;
    });

    try {
      final subjects = await ref
          .read(subjectProvider.notifier)
          .fetchOfferingSubjects(
            _selectedOfferingDepartment!,
            semester: _selectedSemester,
          );
      if (mounted) {
        setState(() {
          _offeringSubjects = subjects;
          _isLoadingOfferingSubjects = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOfferingSubjects = false);
      }
    }
  }

  void _onOfferingSubjectSelected(int? subjectId) {
    setState(() {
      _selectedOfferingSubjectId = subjectId;
      if (subjectId != null) {
        final sub = _offeringSubjects.firstWhere(
          (s) => s['id'] == subjectId,
          orElse: () => <String, dynamic>{},
        );
        if (sub.isNotEmpty) {
          _nameController.text =
              (sub['name'] ?? sub['subject_name'] ?? '').toString();
          _codeController.text =
              (sub['code'] ?? sub['subject_code'] ?? '').toString();
        }
      }
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDepartment == null || _selectedSemester == null || _selectedSchema == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select all dropdown fields')),
        );
        return;
      }

      final subjectData = SubjectAddModel(
        subjectName: _nameController.text,
        subjectCode: _codeController.text,
        departmentId: _selectedDepartment!,
        semesterId: _selectedSemester!,
        schemaId: _selectedSchema!,
        isElective: _isElective,
      );

      ref.read(subjectProvider.notifier).addSubject(subjectData);
    }
  }

  // --- NEW: Add Schema Dialog ---
  void _showAddSchemaDialog() {
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Department first.')),
      );
      return;
    }

    final schemaNameCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Schema"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the name for the new syllabus pattern (e.g. '2025 Scheme')."),
            const SizedBox(height: 16),
            TextField(
              controller: schemaNameCtrl,
              decoration: const InputDecoration(
                labelText: "Schema Name",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E)),
            onPressed: () async {
              if (schemaNameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              
              final success = await ref.read(subjectProvider.notifier)
                  .addSchema(schemaNameCtrl.text, _selectedDepartment!);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Schema Added Successfully!"), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subjectProvider);

    final auth = p.Provider.of<AuthProvider>(context);
    final role = (auth.role ?? '').toUpperCase();
    final isHod = role == AppRoles.hod;
    final int? userDeptId = auth.userData?['department'] is int
        ? auth.userData!['department'] as int
        : int.tryParse(auth.userData?['department']?.toString() ?? '');
    final String? userDeptName = auth.userData?['department_name']?.toString();

    List<SubjectOption> availableDepts = state.departments;
    if (isHod && userDeptId != null) {
      final filtered = state.departments.where((d) => d.id == userDeptId).toList();
      if (filtered.isNotEmpty) {
        availableDepts = filtered;
      } else {
        availableDepts = [SubjectOption(id: userDeptId, name: userDeptName ?? "My Department")];
      }
    }

    ref.listen(subjectProvider, (previous, next) {
      if (next.errorMessage != null) {
        final err = next.errorMessage!;
        if (err.toLowerCase().contains("already exists")) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text("Subject Already Exists", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Text(
                err,
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject Added Successfully!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    });

    // Auto-select department for HOD or first available
    if (isHod && userDeptId != null && _selectedDepartment != userDeptId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedDepartment = userDeptId;
          });
        }
      });
    } else if (_selectedDepartment == null && availableDepts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDepartment == null) {
          setState(() {
            _selectedDepartment = availableDepts.first.id;
          });
        }
      });
    }

    // Auto-select semester if available and not selected
    if (_selectedSemester == null && state.semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSemester == null) {
          setState(() {
            _selectedSemester = state.semesters.first.id;
          });
        }
      });
    }

    // Auto-select schema if available and not selected
    if (_selectedSchema == null && state.schemas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSchema == null) {
          setState(() {
            _selectedSchema = state.schemas.first.id;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Add New Subject", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0), 
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Subject Details",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 30),

                    _buildDropdown(
                      label: "Department",
                      value: _selectedDepartment,
                      items: availableDepts,
                      onChanged: isHod ? null : (val) => setState(() => _selectedDepartment = val),
                      isLoading: state.isLoading,
                    ),

                    _buildDropdown(
                      label: "Semester",
                      value: _selectedSemester,
                      items: state.semesters,
                      onChanged: (val) {
                        setState(() => _selectedSemester = val);
                        if (_isElective && _selectedOfferingDepartment != null) {
                          _loadOfferingSubjects();
                        }
                      },
                      isLoading: state.isLoading,
                    ),

                    // Modified Schema Dropdown with Add Button
                    _buildSchemaDropdownWithAdd(state),

                    _buildElectiveCheckbox(),

                    if (_isElective) ...[
                      _buildOfferingDepartmentDropdown(state.departments),
                      if (_selectedOfferingDepartment != null)
                        _buildOfferingSubjectDropdown(),
                    ],

                    _buildField(label: "Subject Name", controller: _nameController, hint: "e.g. Data Structures"),
                    _buildField(label: "Subject Code", controller: _codeController, hint: "e.g. CS101"),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 150,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: state.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: state.isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Add Subject", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildElectiveCheckbox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: const Text(
            "Elective Subject (Optional)",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
          ),
          subtitle: const Text(
            "Check if this subject is an elective or open-elective offering",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          value: _isElective,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) {
            setState(() {
              _isElective = val ?? false;
              if (!_isElective) {
                _selectedOfferingDepartment = null;
                _selectedOfferingSubjectId = null;
                _offeringSubjects = [];
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildOfferingDepartmentDropdown(List<SubjectOption> departments) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Offering Department",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int>(
                value: _selectedOfferingDepartment,
                isExpanded: true,
                hint: const Text("Select Offering Department"),
                items: departments
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedOfferingDepartment = val);
                  _loadOfferingSubjects();
                },
                decoration: const InputDecoration(border: InputBorder.none),
                validator: (val) => _isElective && val == null ? "Required for elective" : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingSubjectDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Department Subject",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int>(
                value: _selectedOfferingSubjectId,
                isExpanded: true,
                hint: Text(_isLoadingOfferingSubjects
                    ? "Loading subjects..."
                    : (_offeringSubjects.isEmpty
                        ? "No subjects found for this department & semester"
                        : "Select Subject")),
                items: _offeringSubjects.map((sub) {
                  final id = sub['id'] as int;
                  final name = (sub['name'] ?? sub['subject_name'] ?? '').toString();
                  final code = (sub['code'] ?? sub['subject_code'] ?? '').toString();
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text("$code - $name", overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _onOfferingSubjectSelected,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required TextEditingController controller, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: controller,
              validator: (val) => val == null || val.isEmpty ? "Required" : null,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<SubjectOption> items,
    required Function(int?)? onChanged,
    required bool isLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int>(
                value: value,
                isExpanded: true,
                hint: Text(isLoading ? "Loading..." : "Select"),
                items: items.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                onChanged: onChanged,
                decoration: const InputDecoration(border: InputBorder.none),
                validator: (val) => val == null ? "Required" : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Special Widget for Schema to include the Add Button
  Widget _buildSchemaDropdownWithAdd(SubjectState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Schema", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<int>(
                      value: _selectedSchema,
                      isExpanded: true,
                      hint: Text(state.isLoading ? "Loading..." : "Select"),
                      items: state.schemas.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                      onChanged: (val) => setState(() => _selectedSchema = val),
                      decoration: const InputDecoration(border: InputBorder.none),
                      validator: (val) => val == null ? "Required" : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Add Button
              InkWell(
                onTap: _showAddSchemaDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}