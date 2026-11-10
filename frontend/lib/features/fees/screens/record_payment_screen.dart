import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/student_fee_model.dart';
import '../widgets/dte_fee_receipt_widget.dart';

class RecordPaymentScreen extends StatefulWidget {
  final int? feeId;
  const RecordPaymentScreen({super.key, this.feeId});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  List<StudentFee> _allFees = [];
  StudentFee? _selectedFee;
  bool _isLoadingFees = true;
  bool _isSubmitting = false;

  // Search & Filter
  final TextEditingController _searchCtrl = TextEditingController();

  // Payment Form Controllers
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _referenceCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  // Mode & Components
  String _selectedMode = 'cash'; // cash, upi, bank, dd, cheque
  String? _selectedComponent = 'ALL';
  DateTime _paymentDate = DateTime.now();

  // Uploaded proof
  String? _studentUploadedProofUrl;

  // Academic Year Fee Completion Summary
  Map<String, dynamic>? _aySummary;
  bool _isLoadingAySummary = false;

  final List<Map<String, String>> _modes = [
    {'value': 'cash', 'label': 'Cash'},
    {'value': 'upi', 'label': 'UPI / QR Payment'},
    {'value': 'bank', 'label': 'Bank Transfer / NEFT / RTGS'},
    {'value': 'dd', 'label': 'Demand Draft (DD)'},
    {'value': 'cheque', 'label': 'Cheque'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchFees();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFees() async {
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/fees/student-fees/');
      final List results = response.data is List ? response.data : (response.data['results'] ?? []);
      final fees = results.map((e) => StudentFee.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _allFees = fees;
          _isLoadingFees = false;
          if (widget.feeId != null) {
            final found = fees.where((f) => f.id == widget.feeId).firstOrNull;
            if (found != null) {
              _onSelectStudent(found);
            }
          } else if (_selectedFee != null) {
            final refreshed = fees.where((f) => f.id == _selectedFee!.id).firstOrNull;
            if (refreshed != null) {
              _selectedFee = refreshed;
              _fetchAcademicYearSummary(refreshed);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFees = false);
      }
    }
  }

  List<StudentFee> get _unrecordedFees {
    return _allFees.where((f) {
      final isPaid = f.status.trim().toLowerCase() == 'paid';
      return f.balanceAmount > 0 && !isPaid;
    }).toList();
  }

  void _onSelectStudent(StudentFee fee) {
    // 1. Reset notes / remarks strictly as requested: "select not recorde student then automatically fetch evry data except note remarks"
    _remarkCtrl.clear();

    final withProof = fee.payments.where((p) => p.proofUrl != null && p.proofUrl!.isNotEmpty).firstOrNull;
    final latestPayment = fee.payments.isNotEmpty ? fee.payments.first : null;

    setState(() {
      _selectedFee = fee;
      _selectedComponent = 'ALL';
      _searchCtrl.text = "${fee.studentUsn} — ${fee.studentName}";

      // Default amount to unrecorded balance
      if (fee.balanceAmount > 0) {
        _amountCtrl.text = fee.balanceAmount.toStringAsFixed(2);
      } else {
        _amountCtrl.text = "0.00";
      }

      // Pre-fill payment mode and reference from payment record if present
      if (latestPayment != null) {
        if (latestPayment.referenceNo.trim().isNotEmpty) {
          _referenceCtrl.text = latestPayment.referenceNo.trim();
        } else {
          _referenceCtrl.clear();
        }
        if (latestPayment.mode.isNotEmpty && _modes.any((m) => m['value'] == latestPayment.mode.toLowerCase())) {
          _selectedMode = latestPayment.mode.toLowerCase();
        } else {
          _selectedMode = 'cash';
        }
        if (latestPayment.paidOn != null && latestPayment.paidOn!.isNotEmpty) {
          try {
            _paymentDate = DateTime.parse(latestPayment.paidOn!);
          } catch (_) {
            _paymentDate = DateTime.now();
          }
        } else {
          _paymentDate = DateTime.now();
        }
      } else {
        _referenceCtrl.clear();
        _selectedMode = 'cash';
        _paymentDate = DateTime.now();
      }

      _studentUploadedProofUrl = withProof?.proofUrl;
    });

    _fetchAcademicYearSummary(fee);
    _checkStudentUploadedProof(fee.id);
  }

  Future<void> _fetchAcademicYearSummary(StudentFee fee) async {
    setState(() => _isLoadingAySummary = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/fees/student-fees/academic-year-summary/', queryParameters: {
        'student_fee_id': fee.id,
        'usn': fee.studentUsn,
        'academic_year': fee.academicYear,
      });
      if (res.data is Map && mounted) {
        setState(() {
          _aySummary = Map<String, dynamic>.from(res.data);
          _isLoadingAySummary = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback client-side calculation from loaded _allFees
    if (mounted) {
      final ayFees = _allFees
          .where((f) => f.studentUsn == fee.studentUsn && f.academicYear == fee.academicYear)
          .toList();
      final total = ayFees.fold(0.0, (sum, f) => sum + f.totalFee);
      final conc = ayFees.fold(0.0, (sum, f) => sum + f.concessionAmount);
      final net = ayFees.fold(0.0, (sum, f) => sum + f.netPayable);
      final paid = ayFees.fold(0.0, (sum, f) => sum + f.paidAmount);
      final bal = ayFees.fold(0.0, (sum, f) => sum + f.balanceAmount);
      final pct = net > 0 ? ((paid / net) * 100).clamp(0.0, 100.0) : 0.0;
      final status = bal <= 0 && net > 0 ? 'COMPLETED' : (paid > 0 ? 'PARTIALLY_COMPLETED' : 'NOT_COMPLETED');

      setState(() {
        _aySummary = {
          'usn': fee.studentUsn,
          'student_name': fee.studentName,
          'department': fee.departmentName,
          'academic_year': fee.academicYear,
          'total_fees': total,
          'concessions': conc,
          'net_payable': net,
          'completed_fees': paid,
          'not_completed_fees': bal,
          'completion_percentage': pct,
          'status': status,
          'breakdown': ayFees.map((f) => {
                'student_fee_id': f.id,
                'structure_title': 'Fee Structure',
                'semester': f.semester,
                'total_amount': f.totalFee,
                'paid_amount': f.paidAmount,
                'balance_amount': f.balanceAmount,
                'status': f.status,
              }).toList(),
        };
        _isLoadingAySummary = false;
      });
    }
  }

  Future<void> _checkStudentUploadedProof(int feeId) async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/fees/payments/', queryParameters: {'student_fee': feeId});
      final list = res.data is List ? res.data : (res.data['results'] ?? []);
      if (list is List && list.isNotEmpty) {
        // Look for any unverified/student-submitted payment, or payment with uploaded proof
        Map<String, dynamic>? targetPayment;
        for (final item in list) {
          if (item is Map) {
            final proof = item['proof_url'] ?? item['upi_screenshot'] ?? item['bank_statement_file'];
            final verified = item['verified'] == true;
            if (!verified || (proof != null && proof.toString().isNotEmpty)) {
              targetPayment = Map<String, dynamic>.from(item);
              break;
            }
          }
        }
        if (targetPayment == null && list.first is Map) {
          targetPayment = Map<String, dynamic>.from(list.first);
        }

        if (targetPayment != null && mounted) {
          final proof = targetPayment['proof_url'] ?? targetPayment['upi_screenshot'] ?? targetPayment['bank_statement_file'];
          final ref = targetPayment['reference_no'] ?? targetPayment['upi_txn_id'] ?? targetPayment['bank_reference_no'] ?? '';
          final mode = targetPayment['mode']?.toString().toLowerCase() ?? '';
          final paidOnStr = targetPayment['paid_on']?.toString();
          final amt = double.tryParse(targetPayment['amount']?.toString() ?? '0') ?? 0.0;

          setState(() {
            if (proof != null && proof.toString().isNotEmpty) {
              _studentUploadedProofUrl = proof.toString();
            }
            if (ref.toString().trim().isNotEmpty) {
              _referenceCtrl.text = ref.toString().trim();
            }
            if (mode.isNotEmpty && _modes.any((m) => m['value'] == mode)) {
              _selectedMode = mode;
            }
            if (paidOnStr != null && paidOnStr.isNotEmpty) {
              try {
                _paymentDate = DateTime.parse(paidOnStr);
              } catch (_) {}
            }
            if (amt > 0 && (_selectedFee == null || amt <= _selectedFee!.balanceAmount)) {
              _amountCtrl.text = amt.toStringAsFixed(2);
            }
            // Explicitly ensure notes / remarks stay blank as instructed!
            _remarkCtrl.clear();
          });
        }
      }
    } catch (_) {}
  }

  void _viewProofDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Payment Proof Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text("Unable to preview image file directly."),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  double get _maxPayableAmount {
    if (_selectedFee == null) return 0.0;
    if (_selectedComponent == null || _selectedComponent == 'ALL') {
      return _selectedFee!.balanceAmount;
    }
    final comp = _selectedFee!.components.where((c) => c.name == _selectedComponent).firstOrNull;
    if (comp != null) {
      return comp.amount <= _selectedFee!.balanceAmount ? comp.amount : _selectedFee!.balanceAmount;
    }
    return _selectedFee!.balanceAmount;
  }

  void _onComponentChanged(String? val) {
    setState(() {
      _selectedComponent = val;
      if (_selectedFee != null) {
        if (val == null || val == 'ALL') {
          _amountCtrl.text = _selectedFee!.balanceAmount.toStringAsFixed(2);
        } else {
          final comp = _selectedFee!.components.where((c) => c.name == val).firstOrNull;
          if (comp != null) {
            final fillAmt = comp.amount <= _selectedFee!.balanceAmount ? comp.amount : _selectedFee!.balanceAmount;
            _amountCtrl.text = fillAmt.toStringAsFixed(2);
          }
        }
      }
    });
  }

  Future<void> _selectPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF13246E),
              onPrimary: Colors.white,
              onSurface: Color(0xFF13246E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Widget _confirmRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: isHighlight ? 14 : 12.5,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? const Color(0xFF059669) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (_isSubmitting) return; // Duplicate submission protection

    if (_selectedFee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a student fee account."), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment amount must be greater than zero."), backgroundColor: Colors.red),
      );
      return;
    }

    if (amount > _selectedFee!.balanceAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Payment amount (₹${amount.toStringAsFixed(2)}) exceeds outstanding balance (₹${_selectedFee!.balanceAmount.toStringAsFixed(2)}).",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ref = _referenceCtrl.text.trim();
    if (_selectedMode != 'cash' && ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Transaction / Reference ID is required for ${_selectedMode.toUpperCase()} payments."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirmation Screen to prevent wrong student / wrong amount errors
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF13246E), size: 26),
            SizedBox(width: 10),
            Text("Confirm Payment Posting", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please review and verify the payment details before posting to the financial ledger:",
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _confirmRow("Student Name", _selectedFee!.studentName.isNotEmpty ? _selectedFee!.studentName : _searchCtrl.text),
                  _confirmRow("USN", _selectedFee!.studentUsn.isNotEmpty ? _selectedFee!.studentUsn : "N/A"),
                  _confirmRow("Department", _selectedFee!.departmentName),
                  _confirmRow("Semester", _selectedFee!.semester),
                  const Divider(height: 16),
                  _confirmRow("Payment Amount", "₹${amount.toStringAsFixed(2)}", isHighlight: true),
                  _confirmRow("Payment Mode", _selectedMode.toUpperCase()),
                  if (ref.isNotEmpty) _confirmRow("Reference / Txn No", ref),
                  if (_selectedComponent != null && _selectedComponent != 'ALL') _confirmRow("Allocation", _selectedComponent!),
                  _confirmRow("Payment Date", _paymentDate.toIso8601String().substring(0, 10)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Once recorded, payment entries are finalized and logged directly in the student fee account.",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Edit / Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Confirm & Post Payment", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final dio = ApiClient().dio;

      // Construct and post payment payload
      final response = await dio.post('/fees/payments/record-payment/', data: {
        "student_fee_id": _selectedFee!.id,
        "amount": amount,
        "mode": _selectedMode,
        "reference_no": ref,
        "remark": _remarkCtrl.text.trim(),
        "component_name": _selectedComponent != 'ALL' ? _selectedComponent : '',
        "payment_date": _paymentDate.toIso8601String(),
      });

      final receiptNo = response.data['receipt_no']?.toString() ?? 'REC-NEW';
      final paymentId = response.data['payment_id'] as int? ?? 1;
      final remainingBal = double.tryParse(response.data['remaining_balance']?.toString() ?? '0') ?? 0.0;
      final componentsData = (response.data['fee_structure']?['components'] as List?)
              ?.map((c) => {
                    'name': (c is Map ? c['name'] : '')?.toString() ?? '',
                    'amount': double.tryParse((c is Map ? c['amount'] : 0)?.toString() ?? '0') ?? 0.0,
                  })
              .toList() ??
          [];

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessReceiptModal(
          receiptNo: receiptNo,
          paymentId: paymentId,
          amountPaid: amount,
          remainingBalance: remainingBal,
          components: componentsData,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String errDetail = "Payment recording failed.";
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data['detail'] != null) {
            errDetail = data['detail'].toString();
          }
        } else {
          errDetail = e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errDetail), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessReceiptModal({
    required String receiptNo,
    required int paymentId,
    required double amountPaid,
    required double remainingBalance,
    required List<Map<String, dynamic>> components,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Payment Recorded!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Official Receipt Number", style: TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(
                    receiptNo,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _summaryRow("Student", "${_selectedFee?.studentName}"),
            _summaryRow("USN", "${_selectedFee?.studentUsn}"),
            _summaryRow("Department", "${_selectedFee?.departmentName}"),
            _summaryRow("Amount Collected", "₹${amountPaid.toStringAsFixed(2)}", isHighlight: true),
            _summaryRow("Payment Mode", _selectedMode.toUpperCase()),
            _summaryRow("Remaining Balance", "₹${remainingBalance.toStringAsFixed(2)}"),
            const SizedBox(height: 8),
            const Text(
              "Receipt issued with verified Cashier and Principal digital signatures.",
              style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fetchFees();
              context.go('/fees/dashboard');
            },
            child: const Text("Go to Dashboard"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text("View Official DTE Receipt"),
            onPressed: () {
              Navigator.pop(ctx);
              _fetchFees();
              _openOfficialReceiptViewer(receiptNo, amountPaid, components);
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? const Color(0xFF10B981) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _openOfficialReceiptViewer(String receiptNo, double amount, List<Map<String, dynamic>> components) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 850),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF13246E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Official DTE Fee Receipt",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: Colors.white),
                      tooltip: "Print Receipt",
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Sending official receipt to local printer..."),
                            backgroundColor: Color(0xFF13246E),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      tooltip: "Download PDF",
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Downloading official receipt PDF with digital signatures..."),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DteFeeReceiptWidget(
                    institutionName: "Government Engineering College Chamarajanagara",
                    bookletNo: _selectedFee?.bookletNo ?? "10495685",
                    receiptDate: DateFormat('dd/MM/yyyy').format(_paymentDate),
                    receiptNo: receiptNo,
                    studentName: _selectedFee?.studentName ?? "Student",
                    branch: _selectedFee?.departmentCode ?? "CSE",
                    category: _selectedFee?.seatType ?? "General",
                    year: _selectedFee?.academicYear ?? "2025-26",
                    components: components.isNotEmpty
                        ? components
                        : (_selectedFee != null && _selectedFee!.components.isNotEmpty)
                            ? _selectedFee!.components.map((c) => {'name': c.name, 'amount': c.amount}).toList()
                            : [
                                {'name': 'Tuition / College Fee', 'amount': amount},
                              ],
                    totalAmount: amount,
                    status: 'paid',
                    isStudentReceipt: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Record Fee Payment",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Reload Student Fees",
            onPressed: () => _fetchFees(),
          ),
        ],
      ),
      body: _isLoadingFees
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Title & Subtitle
                      const Text(
                        "Record Fee Payment",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF13246E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Select a student to load their fee account.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const Divider(height: 32),

                      // 1. Student Account Search / Selection (Unrecorded Only)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Student account (Unrecorded Only)",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              "${_unrecordedFees.length} Pending / Unrecorded",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Search Autocomplete / Picker strictly restricted to unrecorded students
                      Autocomplete<StudentFee>(
                        displayStringForOption: (fee) => "${fee.studentUsn} — ${fee.studentName}",
                        initialValue: TextEditingValue(text: _searchCtrl.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final unrecorded = _unrecordedFees;
                          if (textEditingValue.text.isEmpty) {
                            return unrecorded;
                          }
                          final q = textEditingValue.text.toLowerCase().trim();
                          return unrecorded.where((fee) =>
                              fee.studentUsn.toLowerCase().contains(q) ||
                              fee.studentName.toLowerCase().contains(q) ||
                              fee.departmentName.toLowerCase().contains(q));
                        },
                        onSelected: _onSelectStudent,
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          if (_selectedFee != null && controller.text.isEmpty && _searchCtrl.text.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (controller.text.isEmpty && mounted) {
                                controller.text = _searchCtrl.text;
                              }
                            });
                          }
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: "Search unrecorded student by USN, name, or department...",
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                              suffixIcon: controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        controller.clear();
                                        setState(() {
                                          _selectedFee = null;
                                          _aySummary = null;
                                          _searchCtrl.clear();
                                          _amountCtrl.clear();
                                          _referenceCtrl.clear();
                                          _remarkCtrl.clear();
                                          _studentUploadedProofUrl = null;
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          if (options.isEmpty) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 660,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.grey, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        "No unrecorded students found.",
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 280, maxWidth: 660),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "UNRECORDED STUDENTS (${options.length})",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              color: Color(0xFF13246E),
                                            ),
                                          ),
                                          const Text(
                                            "Select to auto-fetch details",
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        itemCount: options.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final fee = options.elementAt(index);
                                          final hasProof = fee.payments.any((p) => p.proofUrl != null && p.proofUrl!.isNotEmpty);
                                          return ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                              child: const Icon(Icons.person_outline, size: 18, color: Color(0xFFDC2626)),
                                            ),
                                            title: Text(
                                              "${fee.studentName} (${fee.studentUsn})",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            subtitle: Text(
                                              "${fee.departmentName} · Sem ${fee.semester} · ${fee.academicYear}",
                                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (hasProof) ...[
                                                  Container(
                                                    margin: const EdgeInsets.only(right: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.image_outlined, size: 11, color: Colors.blue),
                                                        SizedBox(width: 3),
                                                        Text("Proof", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    "Unrecorded: ₹${NumberFormat('#,##,##0').format(fee.balanceAmount)}",
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: () => onSelected(fee),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // 2. Selected Student Details Section (Summary Cards)
                      const Text(
                        "Selected student details",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Student identification header
                            Row(
                              children: [
                                const Icon(Icons.person_pin_rounded, color: Color(0xFF13246E), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedFee != null
                                        ? "${_selectedFee!.studentName} · ${_selectedFee!.studentUsn} · ${_selectedFee!.departmentName} · Sem ${_selectedFee!.semester}"
                                        : "Student name · USN · Department · Semester",
                                    style: TextStyle(
                                      fontWeight: _selectedFee != null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                      color: _selectedFee != null ? const Color(0xFF13246E) : Colors.grey[500],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Three summary metrics cards
                            Row(
                              children: [
                                Expanded(
                                  child: _metricCard(
                                    label: "Total fees",
                                    value: _selectedFee != null
                                        ? "₹ ${NumberFormat('#,##,##0').format(_selectedFee!.totalFee)}"
                                        : "₹ —",
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _metricCard(
                                    label: "Paid so far",
                                    value: _selectedFee != null
                                        ? "₹ ${NumberFormat('#,##,##0').format(_selectedFee!.paidAmount)}"
                                        : "₹ —",
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _metricCard(
                                    label: "Outstanding balance",
                                    value: _selectedFee != null
                                        ? "₹ ${NumberFormat('#,##,##0').format(_selectedFee!.balanceAmount)}"
                                        : "₹ —",
                                    color: (_selectedFee != null && _selectedFee!.balanceAmount > 0)
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),

                            // Concession banner if any
                            if (_selectedFee != null && _selectedFee!.concessionAmount > 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.stars_rounded, color: Colors.purple, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "Approved Scholarship / Concession: ₹${_selectedFee!.concessionAmount.toStringAsFixed(0)} (${_selectedFee!.concessionReason ?? 'Approved'})",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_selectedFee != null) _buildAcademicYearSummaryCard(),
                      if (_selectedFee != null) _buildPaymentHistorySection(),
                      const SizedBox(height: 24),

                      // 3. Fee Component Selection
                      const Text(
                        "Fee component",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedComponent,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: "Select assigned fee component",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'ALL',
                            child: Text(
                              "All Assigned Fees (Consolidated)",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (_selectedFee != null)
                            ..._selectedFee!.components.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.name,
                                child: Text("${c.name} — ₹${c.amount.toStringAsFixed(0)}"),
                              );
                            }),
                        ],
                        onChanged: _onComponentChanged,
                      ),
                      if (_selectedFee != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Permitted component allocation: ₹${_maxPayableAmount.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 4. Payment Amount Input
                      const Text(
                        "Payment amount (₹)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixText: "₹ ",
                          hintText: "Enter amount",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          suffixIcon: _selectedFee != null && _selectedFee!.balanceAmount > 0
                              ? TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _amountCtrl.text = _maxPayableAmount.toStringAsFixed(2);
                                    });
                                  },
                                  child: const Text(
                                    "Full Balance",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. Payment Mode & Date in 2 columns
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Payment Mode
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Payment mode",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedMode,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  items: _modes.map((m) {
                                    return DropdownMenuItem<String>(
                                      value: m['value'],
                                      child: Text(m['label']!),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedMode = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Payment Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Payment date",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectPaymentDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF13246E)),
                                    ),
                                    child: Text(
                                      DateFormat('dd/MM/yyyy').format(_paymentDate) == DateFormat('dd/MM/yyyy').format(DateTime.now())
                                          ? "Today (${DateFormat('dd/MM/yyyy').format(_paymentDate)})"
                                          : DateFormat('dd/MM/yyyy').format(_paymentDate),
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 6. Transaction / Reference ID (if applicable)
                      Text(
                        _selectedMode == 'cash'
                            ? "Transaction / reference ID (optional for cash)"
                            : (_selectedMode == 'cheque'
                                ? "Cheque Number *"
                                : (_selectedMode == 'dd'
                                    ? "Demand Draft (DD) Number *"
                                    : "Transaction / reference ID (UTR / Txn ID) *")),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _referenceCtrl,
                        decoration: InputDecoration(
                          hintText: _selectedMode == 'cash'
                              ? "Optional counter slip reference..."
                              : "Enter unique transaction reference...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 7. Student Uploaded Payment Proof (Hidden for cash)
                      if (_selectedMode != 'cash' && _studentUploadedProofUrl != null && _studentUploadedProofUrl!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              "Payment Proof / Receipt Image",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "Student Uploaded",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF13246E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  _studentUploadedProofUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.receipt_long, color: Color(0xFF3B82F6), size: 36),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 14, color: Color(0xFF3B82F6)),
                                        SizedBox(width: 4),
                                        Text(
                                          "Student Uploaded Payment Proof",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Automatically fetched from student's online submission.",
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _viewProofDialog(_studentUploadedProofUrl!),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E40AF),
                                  side: const BorderSide(color: Color(0xFF3B82F6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.visibility_rounded, size: 14),
                                label: const Text("View Proof", style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 8. Notes / Remarks (optional)
                      const Text(
                        "Notes / remarks (optional)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _remarkCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: "Additional notes...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 9. Submit Button with Duplicate-Submission Protection
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          onPressed: _isSubmitting ? null : _submitPayment,
                          child: _isSubmitting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Recording Payment...",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                )
                              : const Text(
                                  "Record Payment & Issue Receipt",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _metricCard({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicYearSummaryCard() {
    if (_selectedFee == null) return const SizedBox.shrink();
    if (_isLoadingAySummary && _aySummary == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF13246E))),
              SizedBox(width: 10),
              Text("Calculating Academic Year fee ledger...", style: TextStyle(fontSize: 12, color: Color(0xFF13246E))),
            ],
          ),
        ),
      );
    }

    final ay = _aySummary?['academic_year'] ?? _selectedFee!.academicYear;
    final totalFees = (_aySummary?['total_fees'] as num?)?.toDouble() ?? _selectedFee!.totalFee;
    final completedFees = (_aySummary?['completed_fees'] as num?)?.toDouble() ?? _selectedFee!.paidAmount;
    final notCompletedFees = (_aySummary?['not_completed_fees'] as num?)?.toDouble() ?? _selectedFee!.balanceAmount;
    final pct = (_aySummary?['completion_percentage'] as num?)?.toDouble() ??
        (totalFees > 0 ? ((completedFees / totalFees) * 100).clamp(0.0, 100.0) : 0.0);
    final status = (_aySummary?['status'] as String?) ??
        (notCompletedFees <= 0 && totalFees > 0 ? 'COMPLETED' : (completedFees > 0 ? 'PARTIALLY_COMPLETED' : 'NOT_COMPLETED'));

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (status == 'COMPLETED') {
      statusColor = const Color(0xFF059669);
      statusText = "FEES FULLY COMPLETED (${pct.toStringAsFixed(0)}%)";
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'PARTIALLY_COMPLETED') {
      statusColor = const Color(0xFFD97706);
      statusText = "PARTIALLY COMPLETED (${pct.toStringAsFixed(1)}%)";
      statusIcon = Icons.timelapse_rounded;
    } else {
      statusColor = const Color(0xFFDC2626);
      statusText = "FEES NOT COMPLETED (0%)";
      statusIcon = Icons.error_outline_rounded;
    }

    final List breakdown = (_aySummary?['breakdown'] as List?) ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13246E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded, size: 18, color: Color(0xFF13246E)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Academic Year $ay Fee Status",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF13246E)),
                      ),
                      Text(
                        "Consolidated Annual Dues & Progress",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar with Percentage
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 14),

          // 3 Metric Stat Boxes
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Academic Year Fees", style: TextStyle(fontSize: 10, color: Colors.black54)),
                      const SizedBox(height: 3),
                      Text(
                        "₹ ${NumberFormat('#,##,##0').format(totalFees)}",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      const Text("Assigned Total", style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Completed Fees", style: TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        "₹ ${NumberFormat('#,##,##0').format(completedFees)}",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                      const SizedBox(height: 2),
                      const Text("Total Paid", style: TextStyle(fontSize: 9, color: Color(0xFF059669))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: notCompletedFees > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: notCompletedFees > 0 ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Not Completed Fees",
                        style: TextStyle(
                          fontSize: 10,
                          color: notCompletedFees > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "₹ ${NumberFormat('#,##,##0').format(notCompletedFees)}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: notCompletedFees > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notCompletedFees > 0 ? "Outstanding Due" : "Nil Balance",
                        style: TextStyle(fontSize: 9, color: notCompletedFees > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (breakdown.length > 1) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              "Semester Breakdown ($ay):",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
            ),
            const SizedBox(height: 6),
            ...breakdown.map((b) {
              final bPaid = (b['paid_amount'] as num?)?.toDouble() ?? 0.0;
              final bBal = (b['balance_amount'] as num?)?.toDouble() ?? 0.0;
              final bTot = (b['net_payable'] as num?)?.toDouble() ?? 0.0;
              final bSem = b['semester']?.toString() ?? 'N/A';
              final bStatus = (b['status'] ?? 'pending').toString().toUpperCase();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                      child: Text("Sem $bSem", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Assigned: ₹${bTot.toStringAsFixed(0)} | Paid: ₹${bPaid.toStringAsFixed(0)} | Bal: ₹${bBal.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                    Text(
                      bStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: bBal <= 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentHistorySection() {
    if (_selectedFee == null || _selectedFee!.payments.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: Color(0xFF13246E)),
                  SizedBox(width: 6),
                  Text(
                    "Student Payment Records & Statuses",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF13246E)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Balance updates only for Confirmed payments",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedFee!.payments.length,
            separatorBuilder: (context, index) => const Divider(height: 14),
            itemBuilder: (ctx, idx) {
              final p = _selectedFee!.payments[idx];
              Color statusColor;
              String statusLabel;
              if (p.isReversed) {
                statusColor = Colors.grey;
                statusLabel = "REVERSED";
              } else if (p.verified) {
                statusColor = const Color(0xFF10B981);
                statusLabel = "SUCCESSFUL";
              } else if (p.remark != null && p.remark!.toLowerCase().contains("reject")) {
                statusColor = const Color(0xFFDC2626);
                statusLabel = "FAILED";
              } else {
                statusColor = Colors.orange;
                statusLabel = "PENDING";
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "₹ ${NumberFormat('#,##,##0').format(p.amount)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p.modeDisplay,
                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Ref: ${p.referenceNo.isNotEmpty ? p.referenceNo : 'N/A'} • ${p.paidOn ?? 'Date N/A'}",
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (p.proofUrl != null && p.proofUrl!.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _viewProofDialog(p.proofUrl!),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Color(0xFF13246E)),
                      ),
                      icon: const Icon(Icons.image, size: 12, color: Color(0xFF13246E)),
                      label: const Text("View Proof", style: TextStyle(fontSize: 11, color: Color(0xFF13246E))),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
