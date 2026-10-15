import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/faculty_model.dart';
import '../providers/faculty_provider.dart';

class EditFacultyDialog extends ConsumerStatefulWidget {
  final Faculty faculty;

  const EditFacultyDialog({super.key, required this.faculty});

  static Future<bool?> show(BuildContext context, Faculty faculty) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditFacultyDialog(faculty: faculty),
    );
  }

  @override
  ConsumerState<EditFacultyDialog> createState() => _EditFacultyDialogState();
}

class _EditFacultyDialogState extends ConsumerState<EditFacultyDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _qualCtrl;
  late TextEditingController _addressCtrl;

  String? _selectedRole;
  String? _selectedGender;
  int? _selectedDepartmentId;
  bool _isSaving = false;

  final List<String> _genderOptions = ['male', 'female', 'other'];
  final List<Map<String, String>> _roleOptions = [
    {'label': 'Principal', 'value': 'PRINCIPAL'},
    {'label': 'HOD', 'value': 'HOD'},
    {'label': 'Professor', 'value': 'PROFESSOR'},
    {'label': 'Admission', 'value': 'ADMISSION'},
    {'label': 'Accounts', 'value': 'ACCOUNTS'},
    {'label': 'Library', 'value': 'LIBRARY'},
    {'label': 'Exam', 'value': 'EXAM'},
  ];

  @override
  void initState() {
    super.initState();
    final f = widget.faculty;
    _nameCtrl = TextEditingController(text: f.name);
    _phoneCtrl = TextEditingController(text: f.phone);
    _emailCtrl = TextEditingController(text: f.email);
    _qualCtrl = TextEditingController(text: f.qualification ?? '');
    _addressCtrl = TextEditingController(text: f.address ?? '');

    _selectedRole = f.role.toUpperCase();
    if (!_roleOptions.any((r) => r['value'] == _selectedRole)) {
      _selectedRole = 'PROFESSOR';
    }

    _selectedGender = f.gender?.toLowerCase();
    if (_selectedGender != null && !_genderOptions.contains(_selectedGender)) {
      _selectedGender = 'male';
    }

    _selectedDepartmentId = f.departmentId;

    // Ensure departments are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(facultyProvider.notifier).fetchDepartments();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _qualCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final Map<String, dynamic> updateData = {
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'role': _selectedRole,
      if (_selectedGender != null) 'gender': _selectedGender,
      if (_selectedDepartmentId != null) 'department': _selectedDepartmentId,
      'qualification': _qualCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
    };

    final success = await ref
        .read(facultyActionProvider.notifier)
        .updateFaculty(widget.faculty.id, updateData);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ref.invalidate(facultyDetailProvider(widget.faculty.id));
      ref.invalidate(facultyListProvider('all'));
      ref.invalidate(facultyListProvider('pending'));

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Faculty updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update faculty details. Please check values."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final facultyState = ref.watch(facultyProvider);
    final departments = facultyState.departments;

    // Fallback if department not matched by id
    if (_selectedDepartmentId == null && departments.isNotEmpty) {
      final match = departments.where((d) => d.name.toLowerCase() == widget.faculty.department.toLowerCase()).firstOrNull;
      if (match != null) {
        _selectedDepartmentId = match.id;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13246E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFF13246E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Edit Faculty Details",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            "ID: ${widget.faculty.facultyId}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF13246E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Form Fields (Scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Name
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: "Full Name *",
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
                        ),
                        const SizedBox(height: 14),

                        // Email & Phone
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtrl,
                                decoration: InputDecoration(
                                  labelText: "Email *",
                                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? "Email is required" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                decoration: InputDecoration(
                                  labelText: "Phone *",
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? "Phone is required" : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Role & Gender
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: "Role",
                                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: _roleOptions.map((r) {
                                  return DropdownMenuItem<String>(
                                    value: r['value'],
                                    child: Text(r['label']!),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedRole = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedGender,
                                decoration: InputDecoration(
                                  labelText: "Gender",
                                  prefixIcon: const Icon(Icons.transgender_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: _genderOptions.map((g) {
                                  return DropdownMenuItem<String>(
                                    value: g,
                                    child: Text(g[0].toUpperCase() + g.substring(1)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedGender = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Department Dropdown
                        DropdownButtonFormField<int>(
                          initialValue: _selectedDepartmentId,
                          decoration: InputDecoration(
                            labelText: "Department",
                            prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          hint: const Text("Select Department"),
                          items: departments.map((d) {
                            return DropdownMenuItem<int>(
                              value: d.id,
                              child: Text(d.name),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDepartmentId = val),
                        ),
                        const SizedBox(height: 14),

                        // Qualification
                        TextFormField(
                          controller: _qualCtrl,
                          decoration: InputDecoration(
                            labelText: "Qualification",
                            prefixIcon: const Icon(Icons.school_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Address
                        TextFormField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: "Address",
                            prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSaving ? "Saving..." : "Save Changes"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
