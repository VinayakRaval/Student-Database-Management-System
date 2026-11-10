import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as p;
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/validation_utils.dart';
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
  final _customDesignationController = TextEditingController();

  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  String? _selectedGender;
  String? _selectedRole = 'PROFESSOR';
  int? _selectedDepartmentId;
  XFile? _selectedPhoto;
  bool _isLoadingNextId = false;

  final List<String> _genderOptions = ['male', 'female', 'other'];

  @override
  void initState() {
    super.initState();
    _fetchNextFacultyId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHodDepartment();
    });

    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus && _phoneController.text.trim().isNotEmpty) {
        final err = ValidationUtils.validatePhone(_phoneController.text.trim());
        if (err != null) {
          ValidationUtils.showValidationPopup(
            context,
            title: "Invalid Phone Number",
            message: err,
          );
        }
      }
    });

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _emailController.text.trim().isNotEmpty) {
        final err = ValidationUtils.validateEmail(_emailController.text.trim());
        if (err != null) {
          ValidationUtils.showValidationPopup(
            context,
            title: "Invalid Email Address",
            message: err,
          );
        }
      }
    });
  }

  void _initHodDepartment() {
    try {
      final auth = p.Provider.of<AuthProvider>(context, listen: false);
      final role = (auth.role ?? auth.userData?['role'] ?? '').toString().toUpperCase();
      if (role == 'HOD' && auth.userData != null && auth.userData!['department'] != null) {
        final deptVal = auth.userData!['department'];
        final deptId = deptVal is int ? deptVal : int.tryParse(deptVal.toString());
        if (deptId != null && _selectedDepartmentId != deptId) {
          setState(() {
            _selectedDepartmentId = deptId;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regIdController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _qualificationController.dispose();
    _dobController.dispose();
    _customDesignationController.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchNextFacultyId({bool force = false}) async {
    setState(() => _isLoadingNextId = true);
    try {
      final dio = ApiClient().dio;
      final isGuest = _selectedRole == 'GUEST_FACULTY';
      final String desig = _selectedRole == 'GUEST_FACULTY'
          ? 'Guest Faculty'
          : (_selectedRole == 'CUSTOM'
              ? _customDesignationController.text.trim()
              : (_selectedRole ?? 'Professor'));
      final res = await dio.get('/faculty/next-id/', queryParameters: {
        'guest': isGuest,
        'designation': desig,
      });
      if (res.data != null && res.data['next_id'] != null) {
        if (mounted && (_regIdController.text.trim().isEmpty || force)) {
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
    if (!_formKey.currentState!.validate()) {
      ValidationUtils.showValidationErrorSnackBar(context);
      return;
    }

    final name = _nameController.text.trim();
    final regId = _regIdController.text.trim();
    final dob = _dobController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final qualification = _qualificationController.text.trim();

    if (name.isEmpty) {
      _showWarning('Name is mandatory');
      return;
    }
    if (regId.isEmpty) {
      _showWarning('Registration ID is required');
      return;
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      _showWarning('Gender is required. Please select an option.');
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
    final phoneError = ValidationUtils.validatePhone(phone);
    if (phoneError != null) {
      ValidationUtils.showValidationPopup(
        context,
        title: 'Invalid Phone Number',
        message: phoneError,
      );
      return;
    }
    if (email.isEmpty) {
      _showWarning('Email-ID is required');
      return;
    }
    final emailError = ValidationUtils.validateEmail(email);
    if (emailError != null) {
      ValidationUtils.showValidationPopup(
        context,
        title: 'Invalid Email Address',
        message: emailError,
      );
      return;
    }

    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? auth.userData?['role'] ?? '').toString().toUpperCase();
    final bool isHod = role == 'HOD';

    if (isHod && _selectedDepartmentId == null) {
      if (auth.userData != null && auth.userData!['department'] != null) {
        final deptVal = auth.userData!['department'];
        _selectedDepartmentId = deptVal is int ? deptVal : int.tryParse(deptVal.toString());
      }
    }

    if (_selectedDepartmentId == null) {
      _showWarning('Department is required. Please select a department.');
      return;
    }
    if (qualification.isEmpty) {
      _showWarning('Qualification is required');
      return;
    }
    if (_selectedRole == null || _selectedRole!.isEmpty) {
      _showWarning('Designation is required. Please select designation.');
      return;
    }
    if (_selectedRole == 'CUSTOM' && _customDesignationController.text.trim().isEmpty) {
      _showWarning('Please enter the custom designation.');
      return;
    }
    if (_selectedPhoto == null) {
      _showWarning('Faculty Photo is required. Please upload an image.');
      return;
    }

    final isGuest = _selectedRole == 'GUEST_FACULTY';
    final isCustom = _selectedRole == 'CUSTOM';
    final effectiveRole = (isGuest || isCustom) ? 'PROFESSOR' : _selectedRole!;
    final effectiveDesignation = isCustom
        ? _customDesignationController.text.trim()
        : (isGuest ? 'Guest Faculty' : (_selectedRole == 'PROFESSOR' ? 'Professor' : _selectedRole!));

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
      role: effectiveRole,
      designation: effectiveDesignation,
      employmentType: isGuest ? 'GUEST' : 'PERMANENT',
      isGuestFaculty: isGuest,
      photoFile: _selectedPhoto,
      dateOfJoining: null,
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
        final errLower = next.errorMessage!.toLowerCase();
        // Check if registration ID is duplicate and auto-fetch next available ID
        if (errLower.contains('already exists') &&
            (errLower.contains('faculty_id') ||
             errLower.contains('registration id') ||
             errLower.contains('employee id') ||
             errLower.contains('faculty id'))) {
          _fetchNextFacultyId(force: true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Registration ID was already taken. Automatically updated to the next available ID. Please click Submit again.",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (next.isSuccess) {
        final tempPassword = next.temporaryPassword;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
                SizedBox(width: 10),
                Text("Faculty Registered!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Faculty account created successfully for ${_nameController.text.trim()} (ID: ${_regIdController.text.trim()}).",
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.vpn_key_rounded, color: Color(0xFF16A34A), size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Initial password generated successfully. Share this temporary password securely with the faculty member. It will not be shown again.",
                          style: TextStyle(fontSize: 13, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (tempPassword != null && tempPassword.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "Generated Initial Temporary Password:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SelectableText(
                          tempPassword,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF13246E),
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF13246E)),
                          tooltip: "Copy Password",
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: tempPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Temporary password copied to clipboard!"),
                                backgroundColor: Color(0xFF13246E),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.security_rounded, size: 18, color: Color(0xFF92400E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Security Notice: The faculty member will be required to change their temporary password upon their first login.",
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (context.mounted) {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/faculty/list');
                    }
                  }
                },
                child: const Text("Done"),
              ),
            ],
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Container(
              width: isDesktop ? 1050 : double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAEA),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      "Register New Faculty",
                      style: TextStyle(
                        fontSize: 22,
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

                  // Fixed, properly aligned Submit Button at the bottom
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
                            borderRadius: BorderRadius.circular(10),
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
          isReadOnly: true,
          suffixIcon: IconButton(
            icon: _isLoadingNextId
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                : const Icon(Icons.refresh, size: 18, color: Color(0xFF13246E)),
            tooltip: 'Auto-Generate Unique Registration ID',
            onPressed: () {
              _regIdController.clear();
              _fetchNextFacultyId(force: true);
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
          focusNode: _phoneFocusNode,
          keyboardType: TextInputType.phone,
        ),
        _buildSnippedField(
          label: "Email-ID *",
          controller: _emailController,
          focusNode: _emailFocusNode,
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
              color: _selectedPhoto == null ? Colors.red.shade400 : const Color(0xFF13246E),
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

  Widget _buildFieldLabel(String label) {
    final cleanLabel = label.replaceAll(" *", "").trim();
    return SizedBox(
      width: 140,
      child: RichText(
        text: TextSpan(
          text: cleanLabel,
          style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
          children: const [
            TextSpan(
              text: " *",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnippedField({
    required String label,
    required TextEditingController controller,
    bool isReadOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildFieldLabel(label),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              readOnly: isReadOnly,
              onTap: onTap,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14),
              validator: validator ?? (val) {
                if (label.contains('*')) {
                  return ValidationUtils.mandatory(val);
                }
                return null;
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                errorStyle: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                isDense: true,
                suffixIcon: suffixIcon,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildFieldLabel(label),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              hint: const Text("Select Gender", style: TextStyle(fontSize: 13, color: Colors.black45)),
              isExpanded: true,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: onChanged,
              validator: (val) => ValidationUtils.mandatorySelect(val),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                errorStyle: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDropdown(FacultyState state) {
    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? auth.userData?['role'] ?? '').toString().toUpperCase();
    final bool isHod = role == 'HOD';

    if (isHod) {
      String displayDept = "Assigned Department";
      if (state.departments.isNotEmpty && _selectedDepartmentId != null) {
        final match = state.departments.where((d) => d.id == _selectedDepartmentId);
        if (match.isNotEmpty) {
          displayDept = match.first.name;
        }
      } else if (auth.userData != null && auth.userData!['department_name'] != null) {
        displayDept = auth.userData!['department_name'].toString();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            _buildFieldLabel("Department *"),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayDept,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "Auto-locked",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildFieldLabel("Department *"),
          ),
          Expanded(
            child: DropdownButtonFormField<int>(
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
              validator: (val) => ValidationUtils.mandatorySelect(val),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                errorStyle: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignationDropdown() {
    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? auth.userData?['role'] ?? '').toString().toUpperCase();
    final bool isHod = role == 'HOD';

    final options = isHod
        ? [
            {'label': 'Professor', 'value': 'PROFESSOR'},
            {'label': 'Guest Faculty', 'value': 'GUEST_FACULTY'},
          ]
        : [
            {'label': 'Professor', 'value': 'PROFESSOR'},
            {'label': 'Guest Faculty', 'value': 'GUEST_FACULTY'},
            {'label': 'Head of Department (HOD)', 'value': 'HOD'},
            {'label': 'Principal', 'value': 'PRINCIPAL'},
            {'label': 'Admission Officer', 'value': 'ADMISSION'},
            {'label': 'Accounts Officer', 'value': 'ACCOUNTS'},
            {'label': 'Custom Designation', 'value': 'CUSTOM'},
          ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildFieldLabel("Designation *"),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: options.any((e) => e['value'] == _selectedRole) ? _selectedRole : options.first['value'],
                  hint: const Text("Select Designation", style: TextStyle(fontSize: 13, color: Colors.black45)),
                  isExpanded: true,
                  items: options.map((e) {
                    return DropdownMenuItem(
                      value: e['value'],
                      child: Text(e['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final changed = _selectedRole != val;
                      setState(() => _selectedRole = val);
                      if (changed) {
                        _fetchNextFacultyId(force: true);
                      }
                    }
                  },
                  validator: (val) => ValidationUtils.mandatorySelect(val),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedRole == 'CUSTOM') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFieldLabel("Custom Designation *"),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      controller: _customDesignationController,
                      decoration: const InputDecoration(
                        hintText: "Enter designation (e.g. Visiting Professor)",
                        hintStyle: TextStyle(fontSize: 13, color: Colors.black45),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(bottom: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
