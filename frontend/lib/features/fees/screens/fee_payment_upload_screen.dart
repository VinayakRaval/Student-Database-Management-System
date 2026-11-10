import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';
import '../models/student_fee_model.dart';
import '../providers/student_fee_provider.dart';
import '../widgets/payment_proof_dialog.dart';
import '../../admissions/providers/admission_provider.dart';

class FeePaymentScreen extends ConsumerStatefulWidget {
  final int feeId;
  final Map<String, dynamic>? studentMap;
  final Map<String, Uint8List?>? attachments;

  const FeePaymentScreen({
    super.key,
    required this.feeId,
    this.studentMap,
    this.attachments,
  });

  @override
  ConsumerState<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends ConsumerState<FeePaymentScreen> {
  final _txnCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _mode = "upi";
  Uint8List? _receiptBytes;
  String? _receiptFileName;
  final ImagePicker _picker = ImagePicker();

  StudentFee? _enrolledFee;
  bool _isLoadingFee = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDetails());
  }

  @override
  void dispose() {
    _txnCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final studentMap = widget.studentMap ?? extra?['student_map'];
    if (studentMap != null) {
      await ref
          .read(admissionProvider.notifier)
          .fetchFeeDetails(
            deptId: studentMap['department_id'],
            semId: studentMap['semester_id'],
            yearId: studentMap['academic_year_id'],
            seatType: studentMap['seat_type'],
          );
    } else {
      // Enrolled student fee flow: fetch StudentFee by id
      setState(() => _isLoadingFee = true);
      try {
        final dio = ApiClient().dio;
        final res = await dio.get('/fees/student-fees/${widget.feeId}/');
        if (mounted) {
          setState(() {
            _enrolledFee = StudentFee.fromJson(res.data);
            _isLoadingFee = false;
            if (_amountCtrl.text.isEmpty && _enrolledFee != null) {
              _amountCtrl.text = _enrolledFee!.balanceAmount > 0
                  ? _enrolledFee!.balanceAmount.toStringAsFixed(2)
                  : _enrolledFee!.totalFee.toStringAsFixed(2);
            }
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingFee = false);
      }
    }
  }

  Future<void> _pickReceipt() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _receiptBytes = bytes;
        _receiptFileName = picked.name;
      });
    }
  }

  Future<void> _submitEnrolledPayment() async {
    if (_receiptBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a fee receipt or screenshot as payment proof"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_txnCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter transaction / reference number"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final double amount = double.tryParse(_amountCtrl.text.trim()) ??
        (_enrolledFee?.balanceAmount ?? 0.0);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment amount must be greater than zero"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dio = ApiClient().dio;
      final formData = FormData.fromMap({
        "student_fee": widget.feeId,
        "amount": amount,
        "mode": _mode,
        "reference_no": _txnCtrl.text.trim(),
        "upi_transaction_id": _txnCtrl.text.trim(),
        "fee_receipt": MultipartFile.fromBytes(
          _receiptBytes!,
          filename: _receiptFileName ?? 'receipt.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await dio.post(
        '/fees/payments/',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ref.invalidate(studentFeeListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment proof uploaded successfully! Awaiting verification by Accounts."),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Re-fetch fee details to immediately display the uploaded payment record
        final res = await dio.get('/fees/student-fees/${widget.feeId}/');
        if (mounted) {
          setState(() {
            _enrolledFee = StudentFee.fromJson(res.data);
            _receiptBytes = null;
            _receiptFileName = null;
            _txnCtrl.clear();
            _isSubmitting = false;
            if (_enrolledFee != null) {
              _amountCtrl.text = _enrolledFee!.balanceAmount > 0
                  ? _enrolledFee!.balanceAmount.toStringAsFixed(2)
                  : "";
            }
          });
        }
      } else {
        throw Exception("Server returned ${response.statusCode}: ${response.data}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final studentMap = widget.studentMap ?? extra?['student_map'];
    final attachments = widget.attachments ?? extra?['attachments'];

    if (studentMap == null) {
      return _buildEnrolledStudentView();
    }

    // Existing Admission Registration Flow
    final uploadState = ref.watch(paymentUploadProvider);
    final uploadNotifier = ref.read(paymentUploadProvider.notifier);
    final admissionState = ref.watch(admissionProvider);
    final admissionNotifier = ref.read(admissionProvider.notifier);

    final feeAmount = admissionState.fetchedFeeAmount;
    final feeStructId = admissionState.fetchedFeeStructureId;
    final feeFound = feeStructId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Student Registration — Fee",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EBFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  "Fee Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: feeFound ? const Color(0xFF5A2F8A) : Colors.red,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: feeFound
                    ? Colors.white
                    : Colors.red.withValues(alpha: 0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feeFound
                        ? "Standard Fee Structure"
                        : "Fee Structure Not Found",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: feeFound ? Colors.black : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feeFound
                        ? "Total Payable: ₹${feeAmount?.toStringAsFixed(2)}"
                        : "Please check Dept/Sem/Seat Type.",
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Payment Mode
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mode = 'bank'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _mode == 'bank'
                              ? const Color(0xFF5A2F8A)
                              : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _mode == 'bank'
                            ? const Color(0xFFF4F3FA)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _mode == 'bank'
                                    ? const Color(0xFF5A2F8A)
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: _mode == 'bank'
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF5A2F8A),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text("Bank"),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mode = 'upi'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _mode == 'upi'
                              ? const Color(0xFF5A2F8A)
                              : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _mode == 'upi'
                            ? const Color(0xFFF4F3FA)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _mode == 'upi'
                                    ? const Color(0xFF5A2F8A)
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: _mode == 'upi'
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF5A2F8A),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text("UPI"),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _txnCtrl,
              decoration: InputDecoration(
                labelText: "UPI / Txn No.",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: _pickReceipt,
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: _receiptBytes == null
                    ? Column(
                        children: [
                          const Icon(
                            Icons.attach_file,
                            size: 40,
                            color: Color(0xFF6D2AA8),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Upload Fee Receipt (required)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: _pickReceipt,
                            child: const Text("Upload / Replace"),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _receiptBytes!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _pickReceipt,
                            child: const Text("Replace"),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 35),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF13246E),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Prev",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF13246E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (uploadState.isLoading || admissionState.isLoading)
                        ? null
                        : () async {
                            if (_receiptBytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please upload a receipt"),
                                ),
                              );
                              return;
                            }
                            if (_txnCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Enter UPI / Txn No."),
                                ),
                              );
                              return;
                            }
                            if (studentMap == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Missing registration data"),
                                ),
                              );
                              return;
                            }
                            if (!feeFound) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No Fee Structure found."),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final formMap = Map<String, dynamic>.from(
                              studentMap,
                            );
                            final studentId = await admissionNotifier
                                .registerStudentFromMap(
                                  formMap,
                                  attachments: attachments!,
                                );
                            if (!context.mounted) return;
                            if (studentId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ref.read(admissionProvider).errorMessage ??
                                        "Registration Failed",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final feeSuccess = await uploadNotifier
                                .submitPayment(
                                  studentId: studentId,
                                  feeStructureId: feeStructId,
                                  mode: _mode,
                                  txnId: _txnCtrl.text,
                                  fileBytes: _receiptBytes!,
                                  fileName: _receiptFileName ?? 'receipt.jpg',
                                );
                            if (!context.mounted) return;
                            if (feeSuccess) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Success!"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              context.go('/dashboard');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Student registered, payment failed: ${uploadState.error}",
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: (uploadState.isLoading || admissionState.isLoading)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
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
    );
  }

  Widget _buildEnrolledStudentView() {
    final fee = _enrolledFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Fee Payment & Proof Upload",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Details",
            onPressed: _fetchDetails,
          ),
        ],
      ),
      body: _isLoadingFee
          ? const Center(child: CircularProgressIndicator())
          : fee == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text("Failed to load fee information."),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchDetails,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fee Overview Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Sem ${fee.semester} Fee Details",
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF13246E),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: fee.status.toLowerCase() == 'paid'
                                        ? const Color(0xFFECFDF5)
                                        : (fee.status.toLowerCase() == 'partial'
                                            ? const Color(0xFFFFFBEB)
                                            : const Color(0xFFFEF2F2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    fee.status.toUpperCase(),
                                    style: TextStyle(
                                      color: fee.status.toLowerCase() == 'paid'
                                          ? const Color(0xFF059669)
                                          : (fee.status.toLowerCase() == 'partial'
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFFDC2626)),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${fee.academicYear} • ${fee.seatType} • ${fee.departmentName}",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _metric("Total Fee", "₹${fee.totalFee.toStringAsFixed(2)}"),
                                _metric("Paid Amount", "₹${fee.paidAmount.toStringAsFixed(2)}",
                                    color: const Color(0xFF059669)),
                                _metric("Balance Due", "₹${fee.balanceAmount.toStringAsFixed(2)}",
                                    color: const Color(0xFFDC2626)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Section: Uploaded Payment Records (with View Payment Proof button)
                      if (fee.payments.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF13246E)),
                                SizedBox(width: 8),
                                Text(
                                  "Uploaded Payment Proof Records",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${fee.payments.length} ${fee.payments.length == 1 ? 'record' : 'records'}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF13246E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: fee.payments.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final payment = fee.payments[idx];
                            return PaymentRecordTile(
                              payment: payment,
                              onViewProof: () => showPaymentProofDialog(context, payment),
                            );
                          },
                        ),
                      ],

                      // Section: Upload Payment Proof Form
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.upload_file_rounded, size: 20, color: Color(0xFF13246E)),
                                SizedBox(width: 8),
                                Text(
                                  "Upload New Payment Proof",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Submit bank transfer or UPI proof with reference number for verification.",
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),

                            // Payment Method Selector
                            const Text(
                              "Payment Method",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _mode = 'upi'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _mode == 'upi'
                                              ? const Color(0xFF13246E)
                                              : const Color(0xFFCBD5E1),
                                          width: _mode == 'upi' ? 1.8 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        color: _mode == 'upi'
                                            ? const Color(0xFFEFF6FF)
                                            : Colors.white,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.qr_code_rounded,
                                            size: 18,
                                            color: _mode == 'upi'
                                                ? const Color(0xFF13246E)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "UPI Payment",
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _mode = 'bank'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _mode == 'bank'
                                              ? const Color(0xFF13246E)
                                              : const Color(0xFFCBD5E1),
                                          width: _mode == 'bank' ? 1.8 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        color: _mode == 'bank'
                                            ? const Color(0xFFEFF6FF)
                                            : Colors.white,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.account_balance_rounded,
                                            size: 18,
                                            color: _mode == 'bank'
                                                ? const Color(0xFF13246E)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Bank Transfer",
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Payment Amount Field
                            const Text(
                              "Payment Amount (₹)",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: "Enter amount paid (e.g. 15000)",
                                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.8),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Transaction Reference
                            Text(
                              _mode == 'upi' ? "UPI Transaction ID" : "Bank Reference / UTR Number",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _txnCtrl,
                              decoration: InputDecoration(
                                hintText: _mode == 'upi'
                                    ? "e.g. UPI ref or transaction ID"
                                    : "e.g. Bank UTR / Cheque / DD Ref No.",
                                prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.8),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Receipt / Proof File Upload
                            const Text(
                              "Upload Payment Receipt / Screenshot",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _pickReceipt,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _receiptBytes != null
                                        ? const Color(0xFF13246E)
                                        : const Color(0xFFCBD5E1),
                                    style: BorderStyle.solid,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFFF8FAFC),
                                ),
                                child: _receiptBytes == null
                                    ? Column(
                                        children: [
                                          const Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 40,
                                            color: Color(0xFF13246E),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            "Select Receipt Image (JPEG, PNG)",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            "Click here to browse file from device",
                                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.memory(
                                              _receiptBytes!,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _receiptFileName ?? "receipt.jpg",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "${(_receiptBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB",
                                                  style: const TextStyle(
                                                      fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: _pickReceipt,
                                            icon: const Icon(Icons.sync_rounded, size: 16),
                                            label: const Text("Replace"),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFF13246E),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _submitEnrolledPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF13246E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.upload_file_rounded, size: 20),
                                label: Text(
                                  _isSubmitting ? "Uploading..." : "Submit Payment Proof",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _metric(String title, String val, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
