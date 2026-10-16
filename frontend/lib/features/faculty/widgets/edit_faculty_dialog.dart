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

    if (_selectedDepartmentId == null && departments.isNotEmpty) {
      final match = departments
          .where((d) => d.name.toLowerCase() == widget.faculty.department.toLowerCase())
          .firstOrNull;
      if (match != null) {
        _selectedDepartmentId = match.id;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Image 4 style: Clean text and subtitle)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Edit Faculty Details",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Registration ID: ${widget.faculty.facultyId}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Form Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField(
                            label: "Full Name *",
                            controller: _nameCtrl,
                            hint: "Faculty Name",
                            validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField<String>(
                                  label: "Gender",
                                  value: _selectedGender,
                                  items: _genderOptions
                                      .map((g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(g[0].toUpperCase() + g.substring(1)),
                                          ))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedGender = val),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildField(
                                  label: "Qualification",
                                  controller: _qualCtrl,
                                  hint: "e.g. M.Tech, Ph.D",
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  label: "Email-ID *",
                                  controller: _emailCtrl,
                                  hint: "email@example.com",
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (val) => val == null || val.trim().isEmpty ? "Email is required" : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildField(
                                  label: "Phone *",
                                  controller: _phoneCtrl,
                                  hint: "Phone Number",
                                  keyboardType: TextInputType.phone,
                                  validator: (val) => val == null || val.trim().isEmpty ? "Phone is required" : null,
                                ),
                              ),
                            ],
                          ),

                          _buildField(
                            label: "Address",
                            controller: _addressCtrl,
                            hint: "Residential Address",
                            maxLines: 2,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField<int>(
                                  label: "Department *",
                                  value: _selectedDepartmentId,
                                  hint: "Select Department",
                                  items: departments
                                      .map((d) => DropdownMenuItem(
                                            value: d.id,
                                            child: Text(d.name, overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedDepartmentId = val),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDropdownField<String>(
                                  label: "Role / Designation *",
                                  value: _selectedRole,
                                  items: _roleOptions
                                      .map((r) => DropdownMenuItem(
                                            value: r['value'],
                                            child: Text(r['label']!),
                                          ))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedRole = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons (Image 4 pill style)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        side: BorderSide(color: Colors.grey.shade500),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 2,
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Update Faculty Details",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              validator: validator,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    String? hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                isExpanded: true,
                hint: hint != null ? Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey.shade400)) : null,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
