// lib/features/admissions/screens/student_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:frontend/core/widgets/custom_button.dart';
import 'package:frontend/features/admissions/providers/admission_provider.dart';
import 'dart:typed_data';
import 'package:frontend/core/widgets/photo_upload_card.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';

class StudentRegistrationScreen extends ConsumerStatefulWidget {
  final int startPage;
  const StudentRegistrationScreen({super.key, this.startPage = 1});

  @override
  ConsumerState<StudentRegistrationScreen> createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState
    extends ConsumerState<StudentRegistrationScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  String? _selectedSeatType;

  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  final _otpCtrl = TextEditingController();

  final _nameCtrl = TextEditingController();
  final _cetNoCtrl = TextEditingController();
  final _parentOccCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _motherCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _religionCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityTypeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otherResCtrl = TextEditingController();
  final _casteCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _permAddrCtrl = TextEditingController();
  final _AddrCtrl = TextEditingController();
  final _quotaCtrl = TextEditingController();
  final _rankCtrl = TextEditingController();
  final _admDateCtrl = TextEditingController();

  final _sslcRegCtrl = TextEditingController();
  final _sslcYearCtrl = TextEditingController();
  final _sslcObtCtrl = TextEditingController();
  final _sslcMaxCtrl = TextEditingController();
  final _pucRegCtrl = TextEditingController();
  final _pucYearCtrl = TextEditingController();
  final _pucObtCtrl = TextEditingController();
  final _pucMaxCtrl = TextEditingController();
  final _dipRegCtrl = TextEditingController();
  final _dipYearCtrl = TextEditingController();
  final _dipObtCtrl = TextEditingController();
  final _dipMaxCtrl = TextEditingController();

  Uint8List? studentPhoto;
  String? studentPhotoName;
  Uint8List? studentSignature;
  String? studentSignatureName;
  Uint8List? sslcMarksheet;
  String? sslcMarksheetName;
  Uint8List? pucMarksheet;
  String? pucMarksheetName;
  Uint8List? diplomaMarksheet;
  String? diplomaMarksheetName;
  Uint8List? kannadaCertificate;
  String? kannadaCertificateName;
  Uint8List? hkCertificate;
  String? hkCertificateName;
  Uint8List? casteCertificate;
  String? casteCertificateName;
  Uint8List? keaAcknowledgement;
  String? keaAcknowledgementName;
  Uint8List? studyCertificate;
  String? studyCertificateName;

  int? _selectedDeptId;
  int? _selectedSemId;
  int? _selectedYearId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.startPage - 1;
    _pageController = PageController(initialPage: _currentPage);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _pageController.jumpToPage(_currentPage),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _cetNoCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _religionCtrl.dispose();
    _fatherCtrl.dispose();
    _motherCtrl.dispose();
    _parentOccCtrl.dispose();
    _nationalityCtrl.dispose();
    _stateCtrl.dispose();
    _cityTypeCtrl.dispose();
    _phoneCtrl.dispose();
    _otherResCtrl.dispose();
    _casteCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _permAddrCtrl.dispose();
    _AddrCtrl.dispose();
    _quotaCtrl.dispose();
    _rankCtrl.dispose();
    _admDateCtrl.dispose();
    _sslcRegCtrl.dispose();
    _sslcYearCtrl.dispose();
    _sslcObtCtrl.dispose();
    _sslcMaxCtrl.dispose();
    _pucRegCtrl.dispose();
    _pucYearCtrl.dispose();
    _pucObtCtrl.dispose();
    _pucMaxCtrl.dispose();
    _dipRegCtrl.dispose();
    _dipYearCtrl.dispose();
    _dipObtCtrl.dispose();
    _dipMaxCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page >= 0 && page <= 2) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = page);
    }
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter Student Name"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_cetNoCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter CET / Reg No"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_dobCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Date of Birth"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_fatherCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter Father's Name"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_motherCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter Mother's Name"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter Mobile Number"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_emailCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter Email Address"), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_currentPage == 1) {
      if (_permAddrCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter Permanent Address"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedDeptId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Department"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedSemId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Semester"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedYearId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Academic Year"), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedSeatType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Seat Type"), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _selectDate(TextEditingController ctrl) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2030),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF13246E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter email first")));
      return;
    }
    setState(() => _sendingOtp = true);
    try {
      final dio = ApiClient().dio;
      await dio.post('/userlogin/register/send-otp/', data: {'email': email});
      setState(() => _otpSent = true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("OTP sent to $email")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
      }
    }
    setState(() => _sendingOtp = false);
  }

  Future<void> _verifyOtp() async {
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter OTP")));
      return;
    }
    try {
      final dio = ApiClient().dio;
      await dio.post(
        '/userlogin/register/verify-otp/',
        data: {'email': email, 'otp': otp},
      );
      setState(() => _otpVerified = true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Email verified!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      }
    }
  }

  void _submit() async {
    if (_isSubmitting) return;

    // 1. Personal details validation (Page 1)
    if (_nameCtrl.text.trim().isEmpty) {
      _goToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Student Name"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_cetNoCtrl.text.trim().isEmpty) {
      _goToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter CET / Reg No"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_dobCtrl.text.trim().isEmpty) {
      _goToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Date of Birth"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_fatherCtrl.text.trim().isEmpty) {
      _goToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Father's Name"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_motherCtrl.text.trim().isEmpty) {
      _goToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Mother's Name"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _goToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Mobile Number"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _goToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Email Address"), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Communication & Academic details validation (Page 2)
    if (_permAddrCtrl.text.trim().isEmpty) {
      _goToPage(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Permanent Address"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedDeptId == null) {
      _goToPage(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Department"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedSemId == null) {
      _goToPage(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Semester"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedYearId == null) {
      _goToPage(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Academic Year"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedSeatType == null) {
      _goToPage(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Seat Type"), backgroundColor: Colors.red),
      );
      return;
    }

    // 3. Education details validation (Page 3)
    final hasDiploma = _dipRegCtrl.text.trim().isNotEmpty || _dipObtCtrl.text.trim().isNotEmpty;
    final hasSslc = _sslcRegCtrl.text.trim().isNotEmpty || _sslcObtCtrl.text.trim().isNotEmpty;
    final hasPuc = _pucRegCtrl.text.trim().isNotEmpty || _pucObtCtrl.text.trim().isNotEmpty;

    if (!hasDiploma && !hasSslc && !hasPuc) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter education qualification details (10th, PUC, or Diploma)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4. Documents validation
    if (studentPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload Student Photo"), backgroundColor: Colors.red),
      );
      return;
    }
    if (studentSignature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload Student Signature"), backgroundColor: Colors.red),
      );
      return;
    }

    // 5. Safe mark parsing
    final sslcObt = int.tryParse(_sslcObtCtrl.text.trim());
    final sslcMax = int.tryParse(_sslcMaxCtrl.text.trim());
    final pucObt = int.tryParse(_pucObtCtrl.text.trim());
    final pucMax = int.tryParse(_pucMaxCtrl.text.trim());
    final dipObt = int.tryParse(_dipObtCtrl.text.trim());
    final dipMax = int.tryParse(_dipMaxCtrl.text.trim());

    if (sslcObt != null && sslcMax != null && sslcObt > sslcMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("10th obtained marks cannot exceed maximum marks"), backgroundColor: Colors.red),
      );
      return;
    }
    if (pucObt != null && pucMax != null && pucObt > pucMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PUC obtained marks cannot exceed maximum marks"), backgroundColor: Colors.red),
      );
      return;
    }
    if (dipObt != null && dipMax != null && dipObt > dipMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Diploma obtained marks cannot exceed maximum marks"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formMap = <String, dynamic>{
        "name": _nameCtrl.text.trim(),
        "cet_no": _cetNoCtrl.text.trim().isEmpty ? null : _cetNoCtrl.text.trim(),
        "dob": _dobCtrl.text.trim(),
        "gender": _genderCtrl.text.trim().isEmpty ? "male" : _genderCtrl.text.trim(),
        "religion": _religionCtrl.text.trim().isEmpty ? "General" : _religionCtrl.text.trim(),
        "nationality": _nationalityCtrl.text.trim().isEmpty ? "Indian" : _nationalityCtrl.text.trim(),
        "state": _stateCtrl.text.trim().isEmpty ? "Karnataka" : _stateCtrl.text.trim(),
        "city_type": _cityTypeCtrl.text.trim().isEmpty ? "urban" : _cityTypeCtrl.text.trim(),
        "mobile_no": _phoneCtrl.text.trim(),
        "email": _emailCtrl.text.trim(),
        "father_name": _fatherCtrl.text.trim().isEmpty ? null : _fatherCtrl.text.trim(),
        "mother_name": _motherCtrl.text.trim().isEmpty ? null : _motherCtrl.text.trim(),
        "parent_occupation": _parentOccCtrl.text.trim().isEmpty ? "Self-employed" : _parentOccCtrl.text.trim(),
        "address": _AddrCtrl.text.trim().isEmpty ? _permAddrCtrl.text.trim() : _AddrCtrl.text.trim(),
        "permanent_address": _permAddrCtrl.text.trim(),
        "admission_quota": _quotaCtrl.text.trim().isEmpty ? "CET" : _quotaCtrl.text.trim(),
        "seat_type": _selectedSeatType ?? "general_merit",
        "rank": _rankCtrl.text.trim().isEmpty ? null : _rankCtrl.text.trim(),
        "date_of_admission": _admDateCtrl.text.trim().isEmpty
            ? DateFormat('yyyy-MM-dd').format(DateTime.now())
            : _admDateCtrl.text.trim(),
        "caste": _casteCtrl.text.trim().isEmpty ? null : _casteCtrl.text.trim(),
        "other_reservation": _otherResCtrl.text.trim().isEmpty ? null : _otherResCtrl.text.trim(),
        "sslc_regno": _sslcRegCtrl.text.trim().isEmpty ? null : _sslcRegCtrl.text.trim(),
        "sslc_year": _sslcYearCtrl.text.trim().isEmpty ? null : _sslcYearCtrl.text.trim(),
        "sslc_obtain_marks": sslcObt,
        "sslc_total_marks": sslcMax,
        "puc_regno": _pucRegCtrl.text.trim().isEmpty ? null : _pucRegCtrl.text.trim(),
        "puc_year": _pucYearCtrl.text.trim().isEmpty ? null : _pucYearCtrl.text.trim(),
        "puc_obtain_marks": pucObt,
        "puc_total_marks": pucMax,
        "diploma_regno": _dipRegCtrl.text.trim().isEmpty ? null : _dipRegCtrl.text.trim(),
        "diploma_year": _dipYearCtrl.text.trim().isEmpty ? null : _dipYearCtrl.text.trim(),
        "diploma_obtain_marks": dipObt,
        "diploma_total_marks": dipMax,
        "department_id": _selectedDeptId,
        "semester_id": _selectedSemId,
        "academic_year_id": _selectedYearId,
      };

      final attachments = <String, Uint8List?>{
        "photo": studentPhoto,
        "signature": studentSignature,
        "sslc_marksheet": sslcMarksheet,
        "puc_marksheet": pucMarksheet,
        "diploma_marksheet": diplomaMarksheet,
        "kannada_medium_certificate": kannadaCertificate,
        "hyderabad_karnataka_certificate": hkCertificate,
        "caste_certificate": casteCertificate,
        "kea_acknowledgement": keaAcknowledgement,
        "study_certificate": studyCertificate,
      };

      final success = await ref
          .read(admissionProvider.notifier)
          .registerStudentFromMap(formMap, attachments: attachments);

      if (!mounted) return;

      if (success != null) {
        final auth = p.Provider.of<AuthProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Student Registration Successful! Password invitation dispatched to ${_emailCtrl.text.trim()}."),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        if (auth.isLoggedIn) {
          context.go('/admissions/list');
        } else {
          context.go('/login');
        }
      } else {
        final error = ref.read(admissionProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? "Registration Failed"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error during registration: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(admissionProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF13246E)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final auth = p.Provider.of<AuthProvider>(context, listen: false);
              if (auth.isLoggedIn) {
                context.go('/admissions/list');
              } else {
                context.go('/');
              }
            }
          },
        ),
        title: const Text(
          "Register new students",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(30),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPage1(context),
              _buildPage2(context),
              _buildPage3(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage1(BuildContext context) {
    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? '').toUpperCase();
    final isStaff = auth.isLoggedIn && (role == AppRoles.admission || role == AppRoles.principal || role == AppRoles.system || role == AppRoles.hod);

    return Column(
      children: [
        const Text(
          "Personal Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildLabelRow("Name", _nameCtrl, isRequired: true),
                          _buildLabelRow("CET No", _cetNoCtrl, isRequired: true),
                          _buildDropdownRow(
                            label: "Gender",
                            value: _genderCtrl.text,
                            isRequired: true,
                            items: const {
                              "male": "Male",
                              "female": "Female",
                              "other": "Other",
                            },
                            onChanged: (v) =>
                                setState(() => _genderCtrl.text = v),
                          ),
                          _buildDateRow(
                            label: "Date of Birth",
                            controller: _dobCtrl,
                            isRequired: true,
                          ),
                          _buildLabelRow("Father's Name", _fatherCtrl, isRequired: true),
                          _buildLabelRow("Mother's Name", _motherCtrl, isRequired: true),
                          _buildLabelRow("Parent Occupation", _parentOccCtrl, isRequired: true),
                          _buildLabelRow("Phone", _phoneCtrl, isRequired: true),
                          _buildLabelRow("Email-ID", _emailCtrl, isRequired: true),
                          if (!_otpVerified)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  const SizedBox(width: 150),
                                  if (_otpSent)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 35,
                                              child: TextField(
                                                controller: _otpCtrl,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: "Enter OTP",
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                          ),
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                keyboardType:
                                                    TextInputType.number,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: _verifyOtp,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                            child: const Text("Verify"),
                                          ),
                                          if (isStaff) ...[
                                            const SizedBox(width: 6),
                                            TextButton(
                                              onPressed: () => setState(() => _otpVerified = true),
                                              child: const Text("Skip"),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  else ...[
                                    ElevatedButton(
                                      onPressed: _sendingOtp ? null : _sendOtp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF13246E,
                                        ),
                                      ),
                                      child: _sendingOtp
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text("Send OTP"),
                                    ),
                                    if (isStaff) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => setState(() => _otpVerified = true),
                                        child: const Text("Skip (Staff)"),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          if (_otpVerified)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  SizedBox(width: 150),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Email Verified",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildDropdownRow(
                            label: "City Type",
                            value: _cityTypeCtrl.text,
                            isRequired: true,
                            items: const {"rural": "Rural", "urban": "Urban"},
                            onChanged: (v) =>
                                setState(() => _cityTypeCtrl.text = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        children: [
                          _buildLabelRow("Religion", _religionCtrl, isRequired: true),
                          _buildLabelRow("Nationality", _nationalityCtrl, isRequired: true),
                          _buildLabelRow("State", _stateCtrl, isRequired: true),
                          _buildLabelRow("Caste", _casteCtrl),
                          _buildLabelRow("Other Reservation", _otherResCtrl),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 120,
              child: CustomButton(text: "Next", onPressed: _nextPage),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required Map<String, String> items,
    required Function(String) onChanged,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                children: isRequired
                    ? [
                        const TextSpan(
                          text: " *",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value.isEmpty ? null : value,
                  hint: Text("Select $label"),
                  items: items.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => onChanged(v!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                children: isRequired
                    ? [
                        const TextSpan(
                          text: " *",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: TextField(
                controller: controller,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: "YYYY-MM-DD",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    onPressed: () => _selectDate(controller),
                  ),
                  border: InputBorder.none,
                ),
                onTap: () => _selectDate(controller),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Communication Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildLabelRow("Permanent Address", _permAddrCtrl, isRequired: true),
                _buildLabelRow("Correspondent Address", _AddrCtrl),
                const Divider(thickness: 1, color: Colors.grey, height: 30),
                const SizedBox(height: 20),
                const Text(
                  "Academic Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildDeptDropdown(),
                _buildSemDropdown(),
                _buildYearDropdown(),
                const Text(
                  "Admission Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildLabelRow("Admission Quota", _quotaCtrl, isRequired: true),
                          _buildLabelRow("Rank", _rankCtrl),
                          _buildLabelRow(
                            "Admission Date",
                            _admDateCtrl,
                            isDate: true,
                            isRequired: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: RichText(
                                    text: const TextSpan(
                                      text: "Seat Type",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: " *",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedSeatType,
                                        hint: const Text("Select Type"),
                                        items: const [
                                          DropdownMenuItem(
                                            value: "general_merit",
                                            child: Text("General Merit (GM)"),
                                          ),
                                          DropdownMenuItem(
                                            value: "snq",
                                            child: Text("SNQ"),
                                          ),
                                          DropdownMenuItem(
                                            value: "lateral",
                                            child: Text("Lateral"),
                                          ),
                                        ],
                                        onChanged: (v) => setState(
                                          () => _selectedSeatType = v,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 100,
              child: CustomButton(text: "Prev", onPressed: _prevPage),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: CustomButton(text: "Next", onPressed: _nextPage),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeptDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: RichText(
              text: const TextSpan(
                text: "Department",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: " *",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final a = ref.watch(departmentsProvider);
                return a.when(
                  loading: () => const SizedBox(
                    height: 35,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Text("Error"),
                  data: (items) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedDeptId,
                        hint: const Text("Select"),
                        items: items
                            .map(
                              (d) => DropdownMenuItem<int>(
                                value: d['id'],
                                child: Text("${d['name']}"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedDeptId = v),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: RichText(
              text: const TextSpan(
                text: "Semester",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: " *",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final a = ref.watch(semestersProvider);
                return a.when(
                  loading: () => const SizedBox(
                    height: 35,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Text("Error"),
                  data: (items) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedSemId,
                        hint: const Text("Select"),
                        items: items
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s['id'],
                                child: Text("Sem ${s['sem_number']}"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSemId = v),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: RichText(
              text: const TextSpan(
                text: "Academic Year",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: " *",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final a = ref.watch(academicYearsProvider);
                return a.when(
                  loading: () => const SizedBox(
                    height: 35,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Text("Error"),
                  data: (items) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYearId,
                        hint: const Text("Select"),
                        items: items
                            .map(
                              (y) => DropdownMenuItem<int>(
                                value: y['id'],
                                child: Text("${y['year_name']}"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedYearId = v),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Basic Education Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _headerCell("Board", flex: 2),
                          _headerCell("Reg no", flex: 2),
                          _headerCell("Passing", flex: 2),
                          _headerCell("Obtained", flex: 2),
                          _headerCell("Maximum", flex: 2),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 1),
                      _eduRow(
                        "10th/CBSE/ICSE",
                        _sslcRegCtrl,
                        _sslcYearCtrl,
                        _sslcObtCtrl,
                        _sslcMaxCtrl,
                      ),
                      const SizedBox(height: 8),
                      _eduRow(
                        "PUC/12th",
                        _pucRegCtrl,
                        _pucYearCtrl,
                        _pucObtCtrl,
                        _pucMaxCtrl,
                      ),
                      const SizedBox(height: 8),
                      _eduRow(
                        "Diploma",
                        _dipRegCtrl,
                        _dipYearCtrl,
                        _dipObtCtrl,
                        _dipMaxCtrl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Documents & Uploads",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    PhotoUploadCard(
                      title: "Upload Photo *",
                      initialBytes: studentPhoto,
                      fileName: studentPhotoName,
                      onChanged: (b, n) => setState(() {
                        studentPhoto = b;
                        studentPhotoName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "Upload Signature *",
                      initialBytes: studentSignature,
                      fileName: studentSignatureName,
                      onChanged: (b, n) => setState(() {
                        studentSignature = b;
                        studentSignatureName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "SSLC Marksheet",
                      initialBytes: sslcMarksheet,
                      fileName: sslcMarksheetName,
                      onChanged: (b, n) => setState(() {
                        sslcMarksheet = b;
                        sslcMarksheetName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "PUC Marksheet",
                      initialBytes: pucMarksheet,
                      fileName: pucMarksheetName,
                      onChanged: (b, n) => setState(() {
                        pucMarksheet = b;
                        pucMarksheetName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "Diploma Marksheet",
                      initialBytes: diplomaMarksheet,
                      fileName: diplomaMarksheetName,
                      onChanged: (b, n) => setState(() {
                        diplomaMarksheet = b;
                        diplomaMarksheetName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "Kannada Medium Cert",
                      initialBytes: kannadaCertificate,
                      fileName: kannadaCertificateName,
                      onChanged: (b, n) => setState(() {
                        kannadaCertificate = b;
                        kannadaCertificateName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "HK Certificate",
                      initialBytes: hkCertificate,
                      fileName: hkCertificateName,
                      onChanged: (b, n) => setState(() {
                        hkCertificate = b;
                        hkCertificateName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "Caste Certificate",
                      initialBytes: casteCertificate,
                      fileName: casteCertificateName,
                      onChanged: (b, n) => setState(() {
                        casteCertificate = b;
                        casteCertificateName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "KEA Acknowledgement",
                      initialBytes: keaAcknowledgement,
                      fileName: keaAcknowledgementName,
                      onChanged: (b, n) => setState(() {
                        keaAcknowledgement = b;
                        keaAcknowledgementName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "Study Certificate",
                      initialBytes: studyCertificate,
                      fileName: studyCertificateName,
                      onChanged: (b, n) => setState(() {
                        studyCertificate = b;
                        studyCertificateName = n;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 120,
                      child: CustomButton(text: "Prev", onPressed: _prevPage),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13246E),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Submit",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelRow(
    String label,
    TextEditingController controller, {
    bool isDate = false,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                children: isRequired
                    ? [
                        const TextSpan(
                          text: " *",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 35,
              child: TextField(
                controller: controller,
                readOnly: isDate,
                onTap: isDate ? () => _selectDate(controller) : null,
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    ),
  );

  Widget _eduRow(
    String title,
    TextEditingController r,
    TextEditingController y,
    TextEditingController o,
    TextEditingController m,
  ) => Row(
    children: [
      Expanded(
        flex: 2,
        child: Container(
          height: 40,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 10),
          color: Colors.grey[300],
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
      const SizedBox(width: 6),
      _eduInput(r, flex: 2),
      const SizedBox(width: 6),
      _eduInput(y, flex: 2),
      const SizedBox(width: 6),
      _eduInput(o, flex: 2),
      const SizedBox(width: 6),
      _eduInput(m, flex: 2),
    ],
  );

  Widget _eduInput(TextEditingController ctrl, {int flex = 1}) => Expanded(
    flex: flex,
    child: SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ),
  );
}
