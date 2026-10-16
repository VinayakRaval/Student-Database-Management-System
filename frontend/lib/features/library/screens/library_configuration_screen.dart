import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/network/api_client.dart';

class LibraryConfigurationScreen extends StatefulWidget {
  const LibraryConfigurationScreen({super.key});

  @override
  State<LibraryConfigurationScreen> createState() => _LibraryConfigurationScreenState();
}

class _LibraryConfigurationScreenState extends State<LibraryConfigurationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  int? _configId;

  // Controllers
  final _academicYearCtrl = TextEditingController(text: '2025-2026');
  final _startDateCtrl = TextEditingController(text: '2025-08-01');
  final _endDateCtrl = TextEditingController(text: '2026-07-31');

  final _maxBooksStudentCtrl = TextEditingController(text: '3');
  final _maxBooksFacultyCtrl = TextEditingController(text: '5');
  final _loanDurationCtrl = TextEditingController(text: '14');

  final _cardTitleCtrl = TextEditingController(text: 'LIBRARY ISSUE CARD');
  final _cardPrefixCtrl = TextEditingController(text: 'LC');
  final _cardFormatCtrl = TextEditingController(text: 'LC-YYYY-NNNNNN');
  final _validityMonthsCtrl = TextEditingController(text: '12');

  final _librarianNameCtrl = TextEditingController(text: 'College Library Officer');
  final _librarianDesignationCtrl = TextEditingController(text: 'Chief Librarian');
  final _stampTitleCtrl = TextEditingController(text: 'DIGITAL STAMP');
  final _stampSubCtrl = TextEditingController(text: 'College Library Officer');

  final _borrowingFeeCtrl = TextEditingController(text: '0.00');
  final _lateFineCtrl = TextEditingController(text: '0.00');

  // Booleans
  bool _isActive = true;
  bool _allowStudents = true;
  bool _allowFaculty = true;
  bool _requireMembership = true;
  bool _requireHodApproval = true;
  bool _requirePrincipalApproval = false;

  @override
  void initState() {
    super.initState();
    _fetchConfiguration();
  }

  Future<void> _fetchConfiguration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/config/active/');
      if (res.data != null && res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        _configId = data['id'];
        _academicYearCtrl.text = data['academic_year'] ?? '2025-2026';
        _startDateCtrl.text = data['start_date'] ?? '2025-08-01';
        _endDateCtrl.text = data['end_date'] ?? '2026-07-31';

        _maxBooksStudentCtrl.text = (data['max_books_student'] ?? 3).toString();
        _maxBooksFacultyCtrl.text = (data['max_books_faculty'] ?? 5).toString();
        _loanDurationCtrl.text = (data['loan_duration_days'] ?? 14).toString();

        _cardTitleCtrl.text = data['card_title'] ?? 'LIBRARY ISSUE CARD';
        _cardPrefixCtrl.text = data['card_prefix'] ?? 'LC';
        _cardFormatCtrl.text = data['card_number_format'] ?? 'LC-YYYY-NNNNNN';
        _validityMonthsCtrl.text = (data['validity_months'] ?? 12).toString();

        _librarianNameCtrl.text = data['authorized_librarian_name'] ?? 'College Library Officer';
        _librarianDesignationCtrl.text = data['librarian_designation'] ?? 'Chief Librarian';
        _stampTitleCtrl.text = data['digital_stamp_title'] ?? 'DIGITAL STAMP';
        _stampSubCtrl.text = data['digital_stamp_sub'] ?? 'College Library Officer';

        _borrowingFeeCtrl.text = (data['borrowing_fee'] ?? '0.00').toString();
        _lateFineCtrl.text = (data['late_fine_per_day'] ?? '0.00').toString();

        _isActive = data['is_active'] ?? true;
        _allowStudents = data['allow_students'] ?? true;
        _allowFaculty = data['allow_faculty'] ?? true;
        _requireMembership = data['require_active_membership'] ?? true;
        _requireHodApproval = data['require_hod_approval'] ?? true;
        _requirePrincipalApproval = data['require_principal_approval'] ?? false;
      }
    } catch (e) {
      _errorMessage = "Could not load current configuration: $e";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(TextEditingController ctrl) async {
    DateTime initial = DateTime.now();
    try {
      if (ctrl.text.isNotEmpty) initial = DateTime.parse(ctrl.text);
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF13246E)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => ctrl.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _saveConfiguration() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final dio = ApiClient().dio;
      final payload = {
        'academic_year': _academicYearCtrl.text.trim(),
        'start_date': _startDateCtrl.text.trim().isEmpty ? null : _startDateCtrl.text.trim(),
        'end_date': _endDateCtrl.text.trim().isEmpty ? null : _endDateCtrl.text.trim(),
        'is_active': _isActive,
        'max_books_student': int.tryParse(_maxBooksStudentCtrl.text.trim()) ?? 3,
        'max_books_faculty': int.tryParse(_maxBooksFacultyCtrl.text.trim()) ?? 5,
        'loan_duration_days': int.tryParse(_loanDurationCtrl.text.trim()) ?? 14,
        'allow_students': _allowStudents,
        'allow_faculty': _allowFaculty,
        'require_active_membership': _requireMembership,
        'card_title': _cardTitleCtrl.text.trim(),
        'card_prefix': _cardPrefixCtrl.text.trim(),
        'card_number_format': _cardFormatCtrl.text.trim(),
        'validity_months': int.tryParse(_validityMonthsCtrl.text.trim()) ?? 12,
        'require_hod_approval': _requireHodApproval,
        'require_principal_approval': _requirePrincipalApproval,
        'authorized_librarian_name': _librarianNameCtrl.text.trim(),
        'librarian_designation': _librarianDesignationCtrl.text.trim(),
        'digital_stamp_title': _stampTitleCtrl.text.trim(),
        'digital_stamp_sub': _stampSubCtrl.text.trim(),
        'borrowing_fee': double.tryParse(_borrowingFeeCtrl.text.trim()) ?? 0.00,
        'late_fine_per_day': double.tryParse(_lateFineCtrl.text.trim()) ?? 0.00,
      };

      if (_configId != null) {
        await dio.put('/library/config/$_configId/', data: payload);
      } else {
        final res = await dio.post('/library/config/', data: payload);
        if (res.data != null && res.data['id'] != null) {
          _configId = res.data['id'];
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text("Library Configuration & Borrowing Rules successfully saved!")),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save configuration: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Library Configuration & Rules",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _saveConfiguration,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? "Saving..." : "Save Configuration"),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF13246E), Color(0xFF2E3AB5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF13246E).withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "CampusFlow Library Card & Borrowing Policy Desk",
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Configure borrowing quotas, digital signatures, and card formatting. Configured rules must exist before issuing cards to students and faculty.",
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Free Books Policy Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "College Free Borrowing Policy: All college books and reference materials are ₹0.00 free of charge. No borrowing charges and no late fines are levied.",
                                style: TextStyle(color: Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Grid of Config Sections
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 750;
                          return Column(
                            children: [
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildAcademicSection()),
                                    const SizedBox(width: 24),
                                    Expanded(child: _buildBorrowingRulesSection()),
                                  ],
                                )
                              else ...[
                                _buildAcademicSection(),
                                const SizedBox(height: 20),
                                _buildBorrowingRulesSection(),
                              ],
                              const SizedBox(height: 24),
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildEligibilitySection()),
                                    const SizedBox(width: 24),
                                    Expanded(child: _buildCardFormatSection()),
                                  ],
                                )
                              else ...[
                                _buildEligibilitySection(),
                                const SizedBox(height: 20),
                                _buildCardFormatSection(),
                              ],
                              const SizedBox(height: 24),
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildApprovalSection()),
                                    const SizedBox(width: 24),
                                    Expanded(child: _buildDigitalSignatureSection()),
                                  ],
                                )
                              else ...[
                                _buildApprovalSection(),
                                const SizedBox(height: 20),
                                _buildDigitalSignatureSection(),
                              ],
                              const SizedBox(height: 24),
                              _buildChargesSection(),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Bottom Save Button
                      Center(
                        child: SizedBox(
                          width: 280,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            onPressed: _isSaving ? null : _saveConfiguration,
                            icon: const Icon(Icons.check_circle_rounded, size: 20),
                            label: Text(
                              _isSaving ? "Saving..." : "Save Configuration",
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCardContainer({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF13246E), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAcademicSection() {
    return _buildCardContainer(
      title: "Academic Year & Schedule",
      icon: Icons.calendar_month_rounded,
      children: [
        _buildTextField("Academic Year (e.g. 2025-2026)", _academicYearCtrl),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(_startDateCtrl),
                child: IgnorePointer(
                  child: _buildTextField("Start Date", _startDateCtrl, icon: Icons.calendar_today_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(_endDateCtrl),
                child: IgnorePointer(
                  child: _buildTextField("End Date", _endDateCtrl, icon: Icons.calendar_today_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Active Configuration", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text("Enforce this set of borrowing limits and card rules", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          value: _isActive,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) => setState(() => _isActive = val),
        ),
      ],
    );
  }

  Widget _buildBorrowingRulesSection() {
    return _buildCardContainer(
      title: "Borrowing Quotas & Limits",
      icon: Icons.auto_stories_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField("Student Loan Limit (Books)", _maxBooksStudentCtrl, isNumber: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField("Faculty Loan Limit (Books)", _maxBooksFacultyCtrl, isNumber: true),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildTextField("Loan Duration (Calendar Days)", _loanDurationCtrl, isNumber: true),
        const SizedBox(height: 8),
        const Text(
          "Books borrowed will have their due date calculated automatically based on this loan duration.",
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEligibilitySection() {
    return _buildCardContainer(
      title: "Borrower Eligibility",
      icon: Icons.verified_user_rounded,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Student Borrowing Allowed", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text("Registered students are eligible to apply for library cards", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          value: _allowStudents,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) => setState(() => _allowStudents = val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Faculty Borrowing Allowed", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text("Professors & teaching faculty are eligible for library cards", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          value: _allowFaculty,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) => setState(() => _allowFaculty = val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Require Active Membership", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text("Borrower account must be active in CampusFlow SDMS", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          value: _requireMembership,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) => setState(() => _requireMembership = val),
        ),
      ],
    );
  }

  Widget _buildCardFormatSection() {
    return _buildCardContainer(
      title: "Library Issue Card Settings",
      icon: Icons.badge_rounded,
      children: [
        _buildTextField("Card Title Header", _cardTitleCtrl),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildTextField("Card Prefix", _cardPrefixCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField("Card Number Format", _cardFormatCtrl)),
          ],
        ),
        const SizedBox(height: 14),
        _buildTextField("Card Validity (Months)", _validityMonthsCtrl, isNumber: true),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            "Unique Card Number Format: LC-YYYY-NNNNNN (e.g. LC-2026-000001, LC-2026-000002). Enforced unique across all students and faculty.",
            style: TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalSection() {
    return _buildCardContainer(
      title: "Approval Workflow",
      icon: Icons.approval_rounded,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Require HOD Verification", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text("Student applications must be verified by department HOD before issuance", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          value: _requireHodApproval,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) => setState(() => _requireHodApproval = val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Require Principal Endorsement", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text("Optional escalation check for special permissions", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          value: _requirePrincipalApproval,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) => setState(() => _requirePrincipalApproval = val),
        ),
      ],
    );
  }

  Widget _buildDigitalSignatureSection() {
    return _buildCardContainer(
      title: "Librarian Digital Signature & Stamp",
      icon: Icons.fingerprint_rounded,
      children: [
        _buildTextField("Authorized Librarian Name", _librarianNameCtrl),
        const SizedBox(height: 14),
        _buildTextField("Librarian Designation", _librarianDesignationCtrl),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildTextField("Digital Stamp Title", _stampTitleCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField("Digital Stamp Subtitle", _stampSubCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _buildChargesSection() {
    return _buildCardContainer(
      title: "Library Charges & Penalties (Free Policy)",
      icon: Icons.currency_rupee_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField("Borrowing Fee (₹)", _borrowingFeeCtrl, isNumber: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField("Late Fine Per Day (₹)", _lateFineCtrl, isNumber: true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          "Notice: Per your college requirements, books are completely free to borrow and no overdue penalties are assessed (₹0 / ₹0).",
          style: TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
        ),
      ],
    );
  }
}
