import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/student_fee_provider.dart';
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
  String _mode = "upi";
  Uint8List? _receiptBytes;
  String? _receiptFileName;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDetails());
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

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final studentMap = widget.studentMap ?? extra?['student_map'];
    final attachments = widget.attachments ?? extra?['attachments'];

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
                          Radio<String>(
                            value: 'bank',
                            groupValue: _mode,
                            onChanged: (v) => setState(() => _mode = v!),
                          ),
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
                          Radio<String>(
                            value: 'upi',
                            groupValue: _mode,
                            onChanged: (v) => setState(() => _mode = v!),
                          ),
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
                            if (!mounted) return;
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
                                  feeStructureId: feeStructId!,
                                  mode: _mode,
                                  txnId: _txnCtrl.text,
                                  fileBytes: _receiptBytes!,
                                  fileName: _receiptFileName ?? 'receipt.jpg',
                                );
                            if (!mounted) return;
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
}
