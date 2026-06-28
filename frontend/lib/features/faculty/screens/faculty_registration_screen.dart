import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/faculty_model.dart';
import '../providers/faculty_provider.dart';

class FacultyRegistrationScreen extends ConsumerStatefulWidget {
  const FacultyRegistrationScreen({super.key});

  @override
  ConsumerState<FacultyRegistrationScreen> createState() =>
      _FacultyRegistrationScreenState();
}

class _FacultyRegistrationScreenState
    extends ConsumerState<FacultyRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _regIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _dobController = TextEditingController();

  String? _selectedGender;
  String? _selectedRole;
  int? _selectedDepartmentId;
  XFile? _selectedPhoto;

  final List<String> _genderOptions = ['male', 'female', 'other'];
  final List<Map<String, String>> _roleOptions = [
    {'label': 'Principal', 'value': 'PRINCIPAL'},
    {'label': 'HOD', 'value': 'HOD'},
    {'label': 'Professor', 'value': 'PROFESSOR'},
    {'label': 'Admission', 'value': 'ADMISSION'},
    {'label': 'Accounts', 'value': 'ACCOUNTS'},
  ];

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF13246E)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedPhoto = image;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDepartmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a department')),
        );
        return;
      }

      final facultyData = FacultyRegistrationModel(
        facultyId: _regIdController.text,
        name: _nameController.text,
        gender: _selectedGender ?? 'male',
        dob: _dobController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        departmentId: _selectedDepartmentId!,
        qualification: _qualificationController.text,
        role: _selectedRole ?? 'PROFESSOR',
        photoFile: _selectedPhoto, // Pass XFile here
      );

      ref.read(facultyProvider.notifier).registerFaculty(facultyData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facultyState = ref.watch(facultyProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    ref.listen(facultyProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Faculty Registered Successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/faculty/list');
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Register New Faculty'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Container(
              width: isDesktop ? 1100 : double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    "Personal Details",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),

                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildLeftColumn(facultyState),
                            ),
                            const SizedBox(width: 50),
                            Expanded(
                              flex: 1,
                              child: _buildRightColumn(facultyState),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildRightColumn(facultyState),
                            const SizedBox(height: 30),
                            _buildLeftColumn(facultyState),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn(FacultyState facultyState) {
    return Column(
      children: [
        _buildSnippedField(label: "Name", controller: _nameController),
        _buildSnippedField(
          label: "Registration ID",
          controller: _regIdController,
        ),

        _buildDropdownRow(
          label: "Gender",
          value: _selectedGender,
          items: _genderOptions,
          onChanged: (val) => setState(() => _selectedGender = val),
        ),

        _buildSnippedField(
          label: "Date of Birth",
          controller: _dobController,
          isReadOnly: true,
          onTap: _pickDate,
        ),

        _buildSnippedField(label: "Address", controller: _addressController),
        _buildSnippedField(
          label: "Phone",
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        _buildSnippedField(
          label: "Email-ID",
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),

        _buildDepartmentDropdown(facultyState),

        _buildSnippedField(
          label: "Qualification",
          controller: _qualificationController,
        ),

        _buildDesignationDropdown(),
      ],
    );
  }

  Widget _buildRightColumn(FacultyState facultyState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 180,
          width: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _selectedPhoto == null
              ? const Icon(Icons.person, size: 80, color: Colors.grey)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(_selectedPhoto!.path, fit: BoxFit.cover)
                      : Image.file(
                          io.File(_selectedPhoto!.path),
                          fit: BoxFit.cover,
                        ),
                ),
        ),
        const SizedBox(height: 15),

        SizedBox(
          width: 140,
          child: ElevatedButton(
            onPressed: _pickImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Upload Image",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),

        const SizedBox(height: 200),

        Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: facultyState.isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: facultyState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Submit",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnippedField({
    required String label,
    required TextEditingController controller,
    bool isReadOnly = false,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextFormField(
                controller: controller,
                readOnly: isReadOnly,
                onTap: onTap,
                keyboardType: keyboardType,
                style: const TextStyle(fontSize: 14),
                validator: (value) =>
                    value == null || value.isEmpty ? "" : null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  items: items
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDropdown(FacultyState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          const SizedBox(
            width: 140,
            child: Text(
              "Department",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedDepartmentId,
                  isExpanded: true,
                  hint: Text(
                    state.isLoading ? "Loading..." : "",
                    style: const TextStyle(fontSize: 12),
                  ),
                  items: state.departments.map((dept) {
                    return DropdownMenuItem<int>(
                      value: dept.id,
                      child: Text(dept.name),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _selectedDepartmentId = val),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          const SizedBox(
            width: 140,
            child: Text(
              "Designation",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  isExpanded: true,
                  items: _roleOptions.map((e) {
                    return DropdownMenuItem(
                      value: e['value'],
                      child: Text(e['label']!),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRole = val),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
