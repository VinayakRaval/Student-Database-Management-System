import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/student_fee_provider.dart';
import '../models/student_fee_model.dart';
import '../widgets/dte_fee_receipt_widget.dart';
import '../widgets/payment_proof_dialog.dart';

class StudentFeeListScreen extends ConsumerWidget {
  const StudentFeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(studentFeeListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "My Fee Details",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Fees",
            onPressed: () => ref.invalidate(studentFeeListProvider),
          ),
        ],
      ),
      body: feesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (fees) {
          if (fees.isEmpty) {
            return const Center(child: Text("No fees assigned to you."));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: fees.length,
            separatorBuilder: (c, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _StudentFeeCard(fee: fees[index]);
            },
          );
        },
      ),
    );
  }
}

class _StudentFeeCard extends StatelessWidget {
  final StudentFee fee;
  const _StudentFeeCard({required this.fee});

  void _showOfficialReceiptDialog(BuildContext context, StudentFee fee) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: Colors.white),
                      tooltip: "Print Official Receipt",
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Sending official DTE receipt to printer / PDF export..."),
                            backgroundColor: Color(0xFF13246E),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DteFeeReceiptWidget(
                    institutionName: "Government Engineering College Chamarajanagara",
                    bookletNo: fee.bookletNo ?? "10495685",
                    receiptDate: fee.receiptDate ?? "01/01/2045",
                    receiptNo: fee.formattedReceiptNo ?? (fee.receiptNo ?? "0821183"),
                    studentName: fee.studentName.isNotEmpty ? fee.studentName : "Student",
                    branch: fee.departmentCode.isNotEmpty ? fee.departmentCode : "CSE",
                    category: fee.seatType,
                    year: fee.academicYear,
                    components: fee.components.isNotEmpty
                        ? fee.components.map((c) => {'name': c.name, 'amount': c.amount}).toList()
                        : [
                            {'name': 'Tuition Fee', 'amount': fee.paidAmount > 0 ? fee.paidAmount : fee.totalFee},
                          ],
                    totalAmount: fee.paidAmount > 0 ? fee.paidAmount : fee.totalFee,
                    status: fee.status,
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
    final isPaid = fee.status.toLowerCase() == 'paid';
    final hasPayment = fee.paidAmount > 0 || isPaid || fee.receiptNo != null;
    final statusColor = isPaid ? Colors.green : (fee.status == 'partial' ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sem ${fee.semester}", 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13246E))
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fee.status.toUpperCase(), 
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${fee.academicYear} • ${fee.seatType}", 
            style: TextStyle(color: Colors.grey[600])
          ),
          const Divider(height: 30),

          // Amounts
          _row("Total Fee", "₹${fee.totalFee.toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          _row("Paid", "₹${fee.paidAmount.toStringAsFixed(2)}", color: Colors.green),
          const SizedBox(height: 8),
          _row("Balance", "₹${fee.balanceAmount.toStringAsFixed(2)}", color: Colors.red, isBold: true),

          // Uploaded Payment Records & Proofs
          if (fee.payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF13246E)),
                    SizedBox(width: 6),
                    Text(
                      "Uploaded Payment Records",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF13246E),
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
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fee.payments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, pIndex) {
                final payment = fee.payments[pIndex];
                return PaymentRecordTile(
                  payment: payment,
                  onViewProof: () => showPaymentProofDialog(context, payment),
                );
              },
            ),
          ],

          // View Official DTE Receipt Button (If paid or payment recorded)
          if (hasPayment) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showOfficialReceiptDialog(context, fee),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF13246E),
                  side: const BorderSide(color: Color(0xFF13246E), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 20),
                label: const Text(
                  "View Official Fee Receipt (DTE)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // Upload Button (If balance exists)
          if (fee.balanceAmount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/fees/pay/${fee.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text("Upload Payment Proof"),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(
          value, 
          style: TextStyle(
            color: color ?? Colors.black87, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 16
          )
        ),
      ],
    );
  }
}