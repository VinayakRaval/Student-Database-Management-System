import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as p;
import '../../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
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
  String? _selectedRole = 'PROFESSOR';
  int? _selectedDepartmentId;
  XFile? _selectedPhoto;
  bool _isLoadingNextId = false;

  final List<String> _genderOptions = ['male', 'female', 'other'];
  final List<Map<String, String>> _roleOptions = [
    {'label': 'Principal', 'value': 'PRINCIPAL'},
    {'label': 'HOD', 'value': 'HOD'},
    {'label': 'Professor', 'value': 'PROFESSOR'},
    {'label': 'Admission', 'value': 'ADMISSION'},
    {'label': 'Accounts', 'value': 'ACCOUNTS'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchNextFacultyId();
  }

  Future<void> _fetchNextFacultyId() async {
    setState(() => _isLoadingNextId = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/faculty/next-id/');
      if (res.data != null && res.data['next_id'] != null) {
        if (mounted && _regIdController.text.trim().isEmpty) {
          setState(() {
            _regIdController.text = res.data['next_id'].toString();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingNextId = false);
  }

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
    final name = _nameController.text.trim();
    final regId = _regIdController.text.trim();
    final dob = _dobController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final qualification = _qualificationController.text.trim();

    // ALL fields are required
    if (name.isEmpty) {
      _showWarning('Name is required');
      return;
    }
    if (regId.isEmpty) {
      _showWarning('Registration ID is required');
      return;
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      _showWarning('Please select Gender');
      return;
    }
    if (dob.isEmpty) {
      _showWarning('Date of Birth is required');
      return;
    }
    if (address.isEmpty) {
      _showWarning('Address is required');
      return;
    }
    if (phone.isEmpty) {
      _showWarning('Phone number is required');
      return;
    }
    if (email.isEmpty) {
      _showWarning('Email-ID is required');
      return;
    }
    if (_selectedDepartmentId == null) {
      _showWarning('Please select a Department');
      return;
    }
    if (qualification.isEmpty) {
      _showWarning('Qualification is required');
      return;
    }
    if (_selectedRole == null || _selectedRole!.isEmpty) {
      _showWarning('Please select Designation');
      return;
    }
    if (_selectedPhoto == null) {
      _showWarning('Please upload Faculty Photo');
      return;
    }

    final facultyData = FacultyRegistrationModel(
      facultyId: regId,
      name: name,
      gender: _selectedGender!,
      dob: dob,
      address: address,
      phone: phone,
      email: email,
      departmentId: _selectedDepartmentId!,
      qualification: qualification,
      role: _selectedRole!,
      photoFile: _selectedPhoto,
    );

    ref.read(facultyProvider.notifier).registerFaculty(facultyData);
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facultyState = ref.watch(facultyProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // Auto-detect and pre-select department if logged in user is HOD
    if (_selectedDepartmentId == null && facultyState.departments.isNotEmpty) {
      try {
        final auth = p.Provider.of<AuthProvider>(context, listen: false);
        if (auth.userData != null && auth.userData!['department'] != null) {
          final deptVal = auth.userData!['department'];
          final deptId = deptVal is int ? deptVal : int.tryParse(deptVal.toString());
          if (deptId != null && facultyState.departments.any((d) => d.id == deptId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedDepartmentId == null) {
                setState(() => _selectedDepartmentId = deptId);
              }
            });
          }
        }
      } catch (_) {}
    }

    ref.listen(facultyProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Faculty registered successfully! Password setup invitation dispatched to ${_emailController.text.trim()}',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Container(
              width: isDesktop ? 1050 : double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAEA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      "Personal Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildLeftColumn(facultyState),
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 2,
                              child: _buildRightColumn(facultyState),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildRightColumn(facultyState),
                            const SizedBox(height: 24),
                            _buildLeftColumn(facultyState),
                          ],
                        ),
                  const SizedBox(height: 32),

                  // Dedicated, perfectly-aligned Submit Button at the bottom
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 190,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: facultyState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: Text(
                          facultyState.isLoading ? "Submitting..." : "Submit",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13246E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 3,
                        ),
                        onPressed: facultyState.isLoading ? null : _submitForm,
                      ),
                    ),
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
        _buildSnippedField(label: "Name *", controller: _nameController),
        _buildSnippedField(
          label: "Registration ID *",
          controller: _regIdController,
          suffixIcon: IconButton(
            icon: _isLoadingNextId
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                : const Icon(Icons.refresh, size: 18, color: Color(0xFF13246E)),
            tooltip: 'Suggest Next ID',
            onPressed: () {
              _regIdController.clear();
              _fetchNextFacultyId();
            },
          ),
        ),

        _buildDropdownRow(
          label: "Gender *",
          value: _selectedGender,
          items: _genderOptions,
          onChanged: (val) => setState(() => _selectedGender = val),
        ),

        _buildSnippedField(
          label: "Date of Birth *",
          controller: _dobController,
          isReadOnly: true,
          onTap: _pickDate,
          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
        ),

        _buildSnippedField(label: "Address *", controller: _addressController),
        _buildSnippedField(
          label: "Phone *",
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        _buildSnippedField(
          label: "Email-ID *",
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),

        _buildDepartmentDropdown(facultyState),

        _buildSnippedField(
          label: "Qualification *",
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
          height: 190,
          width: 190,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedPhoto == null ? Colors.red.shade300 : const Color(0xFF13246E),
              width: 1.5,
            ),
          ),
          child: _selectedPhoto == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.person, size: 75, color: Colors.grey),
                    SizedBox(height: 6),
                    Text(
                      "Photo Required *",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: kIsWeb
                      ? Image.network(_selectedPhoto!.path, fit: BoxFit.cover)
                      : Image.file(
                          io.File(_selectedPhoto!.path),
                          fit: BoxFit.cover,
                        ),
                ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: 160,
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.upload_file, size: 18, color: Colors.white),
            label: Text(
              _selectedPhoto == null ? "Upload Image *" : "Change Image",
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
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
    Widget? suffixIcon,
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
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  isDense: true,
                  suffixIcon: suffixIcon,
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
                  hint: const Text("Select Gender", style: TextStyle(fontSize: 13, color: Colors.black45)),
                  isExpanded: true,
                  items: items
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
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
              "Department *",
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
                    state.isLoading ? "Loading..." : "Select Department",
                    style: const TextStyle(fontSize: 13, color: Colors.black45),
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
              "Designation *",
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
                  hint: const Text("Select Designation", style: TextStyle(fontSize: 13, color: Colors.black45)),
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
