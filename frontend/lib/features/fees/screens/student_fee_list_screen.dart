import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/student_fee_provider.dart';
import '../models/student_fee_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final isPaid = fee.status.toLowerCase() == 'paid';
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

          // Upload Button (If balance exists)
          if (fee.balanceAmount > 0) ...[
            const SizedBox(height: 24),
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