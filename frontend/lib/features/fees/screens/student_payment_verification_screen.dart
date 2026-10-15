import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class StudentPaymentVerificationScreen extends ConsumerStatefulWidget {
  const StudentPaymentVerificationScreen({super.key});

  @override
  ConsumerState<StudentPaymentVerificationScreen> createState() =>
      _StudentPaymentVerificationScreenState();
}

class _StudentPaymentVerificationScreenState
    extends ConsumerState<StudentPaymentVerificationScreen> {
  List<dynamic>? _payments;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'pending', 'verified'

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/fees/payments/');
      setState(() {
        _payments = response.data is List
            ? response.data
            : (response.data['results'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredPayments {
    if (_payments == null) return [];
    if (_selectedFilter == 'pending') {
      return _payments!.where((p) => p['verified'] != true).toList();
    }
    if (_selectedFilter == 'verified') {
      return _payments!.where((p) => p['verified'] == true).toList();
    }
    return _payments!;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredPayments;
    final totalCount = _payments?.length ?? 0;
    final pendingCount = _payments?.where((p) => p['verified'] != true).length ?? 0;
    final verifiedCount = _payments?.where((p) => p['verified'] == true).length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Student Payments Verification",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayments,
            tooltip: "Refresh Payments",
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _filterChip("All ($totalCount)", 'all'),
                const SizedBox(width: 8),
                _filterChip("Pending ($pendingCount)", 'pending', color: Colors.orange),
                const SizedBox(width: 8),
                _filterChip("Verified ($verifiedCount)", 'verified', color: Colors.green),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Error: $_error", style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fetchPayments,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFilter == 'pending'
                                      ? "No pending payments to verify."
                                      : "No payment records found.",
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = list[index];
                              final verified = p['verified'] == true;
                              final studentName = p['student_name'] ?? 'Student #${p['student_fee'] ?? 'N/A'}';
                              final studentUsn = p['student_usn'];
                              final dept = p['department_name'];
                              final sem = p['semester_name'];

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _PaymentDetailScreen(payment: p),
                                    ),
                                  ).then((_) => _fetchPayments());
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              studentName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Color(0xFF13246E),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: verified
                                                  ? Colors.green.withValues(alpha: 0.1)
                                                  : Colors.orange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              verified ? "VERIFIED" : "PENDING",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: verified
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (studentUsn != null && studentUsn.toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "USN: $studentUsn${dept != null ? ' • $dept' : ''}${sem != null ? ' • $sem' : ''}",
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                        ),
                                      ],
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Mode: ${(p['mode'] ?? 'N/A').toString().toUpperCase()}",
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Txn: ${p['upi_txn_id'] ?? p['bank_reference_no'] ?? 'N/A'}",
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                "₹${p['amount'] ?? '0.00'}",
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                              Text(
                                                p['paid_on']?.toString().substring(0, 10) ?? '',
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
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

  Widget _filterChip(String label, String value, {Color? color}) {
    final isSelected = _selectedFilter == value;
    final activeColor = color ?? const Color(0xFF13246E);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
    );
  }
}

class _PaymentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> payment;
  const _PaymentDetailScreen({required this.payment});

  @override
  State<_PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<_PaymentDetailScreen> {
  bool _isProcessing = false;
  late Map<String, dynamic> _payment;

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
  }

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiClient().dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$base$cleanPath';
  }

  Future<void> _verifyPayment() async {
    setState(() => _isProcessing = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        '/fees/payments/${_payment['id']}/verify/',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          final receiptNo = res.data is Map ? (res.data['receipt_no'] ?? '') : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Payment Verified! Receipt: $receiptNo"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = res.data is Map ? (res.data['detail'] ?? "Verification failed") : "Error: ${res.statusCode}";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRejectDialog() {
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Payment Proof"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please specify reason for rejecting this payment (e.g. invalid receipt, incorrect amount):"),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Enter rejection reason...",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final remark = remarkCtrl.text.trim();
              if (remark.isEmpty) return;
              Navigator.pop(ctx);
              await _rejectPayment(remark);
            },
            child: const Text("Confirm Reject"),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPayment(String remark) async {
    setState(() => _isProcessing = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        '/fees/payments/${_payment['id']}/reject/',
        data: {"remark": remark},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment rejected successfully."),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = res.data is Map ? (res.data['detail'] ?? "Rejection failed") : "Error: ${res.statusCode}";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = _payment['verified'] == true;
    final receiptFile = _payment['upi_screenshot'] ?? _payment['bank_statement_file'];
    final remark = _payment['remark'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Payment #${_payment['id']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Amount Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: verified
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      verified ? "VERIFIED" : "PENDING VERIFICATION",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: verified ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "₹${_payment['amount'] ?? '0.00'}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF13246E),
                    ),
                  ),
                  if (_payment['receipt_no'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Receipt: ${_payment['receipt_no']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rejection remark if any
            if (remark != null && remark.toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Notes / Remarks",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$remark",
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Student & Payment Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _detailRow("Student Name", "${_payment['student_name'] ?? 'N/A'}"),
                  _detailRow("USN", "${_payment['student_usn'] ?? 'N/A'}"),
                  _detailRow("Department", "${_payment['department_name'] ?? 'N/A'}"),
                  _detailRow("Semester", "${_payment['semester_name'] ?? 'N/A'}"),
                  _detailRow("Payment Method", (_payment['mode'] ?? 'N/A').toString().toUpperCase()),
                  _detailRow(
                    "Transaction / Ref No.",
                    "${_payment['upi_txn_id'] ?? _payment['bank_reference_no'] ?? 'N/A'}",
                  ),
                  _detailRow(
                    "Submission Date",
                    _payment['paid_on']?.toString().substring(0, 10) ?? 'N/A',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Receipt Screenshot / Document
            if (receiptFile != null) ...[
              const Text(
                "Payment Proof / Receipt",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 380),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _buildImageUrl(receiptFile.toString()),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text("Receipt document could not be previewed"),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Verification Actions
            if (!verified) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _showRejectDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "REJECT",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _verifyPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "VERIFY PAYMENT",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
