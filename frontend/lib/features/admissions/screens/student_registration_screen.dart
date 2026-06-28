// lib/features/admissions/screens/student_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import 'package:frontend/core/widgets/custom_button.dart';
import '../models/student_registration_model.dart';
import 'package:frontend/features/admissions/providers/admission_provider.dart';
import 'dart:typed_data';
import 'package:frontend/core/widgets/photo_upload_card.dart';

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
  final _formKey = GlobalKey<FormState>();

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

  void _nextPage() {
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
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));
      await dio.post('/userlogin/register/send-otp/', data: {'email': email});
      setState(() => _otpSent = true);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("OTP sent to $email")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
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
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));
      await dio.post(
        '/userlogin/register/verify-otp/',
        data: {'email': email, 'otp': otp},
      );
      setState(() => _otpVerified = true);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Email verified!")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  void _submit() async {
    if (_selectedDeptId == null ||
        _selectedSemId == null ||
        _selectedYearId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select academic details")),
      );
      return;
    }
    if (_selectedSeatType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select Seat Type")));
      return;
    }
    final formMap = {
      "name": _nameCtrl.text,
      "cet_no": _cetNoCtrl.text.isEmpty ? null : _cetNoCtrl.text,
      "dob": _dobCtrl.text,
      "gender": _genderCtrl.text.isEmpty ? "male" : _genderCtrl.text,
      "religion": _religionCtrl.text,
      "nationality": _nationalityCtrl.text,
      "state": _stateCtrl.text.isEmpty ? "N/A" : _stateCtrl.text,
      "city_type": _cityTypeCtrl.text,
      "mobile_no": _phoneCtrl.text,
      "email": _emailCtrl.text,
      "father_name": _fatherCtrl.text,
      "mother_name": _motherCtrl.text,
      "parent_occupation": _parentOccCtrl.text.isEmpty
          ? null
          : _parentOccCtrl.text,
      "address": _permAddrCtrl.text,
      "permanent_address": _permAddrCtrl.text,
      "admission_quota": _quotaCtrl.text,
      "seat_type": _selectedSeatType ?? "general_merit",
      "rank": _rankCtrl.text.isEmpty ? null : _rankCtrl.text,
      "date_of_admission": _admDateCtrl.text,
      "caste": _casteCtrl.text.trim().isEmpty ? null : _casteCtrl.text.trim(),
      "other_reservation": _otherResCtrl.text.trim().isEmpty
          ? null
          : _otherResCtrl.text.trim(),
      "sslc_regno": _sslcRegCtrl.text,
      "sslc_year": _sslcYearCtrl.text,
      "sslc_obtain_marks": _sslcObtCtrl.text.isEmpty
          ? null
          : int.parse(_sslcObtCtrl.text),
      "sslc_total_marks": _sslcMaxCtrl.text.isEmpty
          ? null
          : int.parse(_sslcMaxCtrl.text),
      "puc_regno": _pucRegCtrl.text,
      "puc_year": _pucYearCtrl.text,
      "puc_obtain_marks": _pucObtCtrl.text.isEmpty
          ? null
          : int.parse(_pucObtCtrl.text),
      "puc_total_marks": _pucMaxCtrl.text.isEmpty
          ? null
          : int.parse(_pucMaxCtrl.text),
      "diploma_regno": _dipRegCtrl.text,
      "diploma_year": _dipYearCtrl.text,
      "diploma_obtain_marks": _dipObtCtrl.text.isEmpty
          ? null
          : int.parse(_dipObtCtrl.text),
      "diploma_total_marks": _dipMaxCtrl.text.isEmpty
          ? null
          : int.parse(_dipMaxCtrl.text),
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
    if (!mounted) return; // Add this line
    if (success != null) {
      context.go('/dashboard');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration Successful"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final error = ref
          .read(admissionProvider)
          .errorMessage; // This may also fail
      if (!mounted) return; // Add this too
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? "Registration Failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF13246E)),
          onPressed: () => context.pop(),
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
                          _buildLabelRow("Name", _nameCtrl),
                          _buildLabelRow("CET No", _cetNoCtrl),
                          _buildDropdownRow(
                            label: "Gender",
                            value: _genderCtrl.text,
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
                          ),
                          _buildLabelRow("Father's Name", _fatherCtrl),
                          _buildLabelRow("Mother's Name", _motherCtrl),
                          _buildLabelRow("Parent Occupation", _parentOccCtrl),
                          _buildLabelRow("Phone", _phoneCtrl),
                          _buildLabelRow("Email-ID", _emailCtrl),
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
                                        ],
                                      ),
                                    )
                                  else
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
                          _buildLabelRow("Religion", _religionCtrl),
                          _buildLabelRow("Nationality", _nationalityCtrl),
                          _buildLabelRow("State", _stateCtrl),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                _buildLabelRow("Permanent Address", _permAddrCtrl),
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
                          _buildLabelRow("Admission Quota", _quotaCtrl),
                          _buildLabelRow("Rank", _rankCtrl),
                          _buildLabelRow(
                            "Admission Date",
                            _admDateCtrl,
                            isDate: true,
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
                                const SizedBox(
                                  width: 140,
                                  child: Text(
                                    "Seat Type",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
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
          const SizedBox(
            width: 140,
            child: Text(
              "Department",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
          const SizedBox(
            width: 140,
            child: Text(
              "Semester",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
          const SizedBox(
            width: 140,
            child: Text(
              "Academic Year",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                      title: "Upload Photo",
                      initialBytes: studentPhoto,
                      fileName: studentPhotoName,
                      onChanged: (b, n) => setState(() {
                        studentPhoto = b;
                        studentPhotoName = n;
                      }),
                    ),
                    PhotoUploadCard(
                      title: "Upload Signature",
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
                      width: 140,
                      child: CustomButton(text: "Submit", onPressed: _submit),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
