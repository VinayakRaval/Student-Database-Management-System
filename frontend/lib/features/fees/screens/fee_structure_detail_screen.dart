import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/constants/api_constants.dart';
import '../providers/fee_action_provider.dart';
import '../models/fee_structure_models.dart';
import '../widgets/dte_fee_receipt_widget.dart';

final _roleProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'role');
});

class FeeStructureDetailScreen extends ConsumerWidget {
  final int id;
  const FeeStructureDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFee = ref.watch(feeStructureDetailProvider(id));
    final roleAsync = ref.watch(_roleProvider);
    final role = roleAsync.value ?? 'STUDENT';
    final actionState = ref.watch(feeActionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Structure Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: "Print Official DTE Document",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Official DTE Document is ready for print/export."),
                  backgroundColor: Color(0xFF13246E),
                ),
              );
            },
          ),
        ],
      ),
      body: asyncFee.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (FeeStructure fee) {
          final isPending = fee.status.toLowerCase() == 'pending';
          final isRejected = fee.status.toLowerCase() == 'rejected';
          final showPrincipalActions = (role == AppRoles.principal) && isPending;
          final showEditAction = (role == AppRoles.accounts) && (isPending || isRejected);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRejected && fee.remarks != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.error_outline, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text("Corrections Required", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 8),
                              Text("Principal's Remark: ${fee.remarks}", style: const TextStyle(color: Colors.black87, fontSize: 15)),
                            ],
                          ),
                        ),
                      // Official Department of Technical Education Receipt / Structure Document (Image 1)
                      Center(
                        child: DteFeeReceiptWidget(
                          institutionName: "Government Engineering College Chamarajanagara",
                          bookletNo: fee.bookletNo ?? "10495${fee.id.toString().padLeft(3, '0')}",
                          receiptDate: fee.receiptDate ?? "01/01/2026",
                          receiptNo: fee.receiptNo ?? (821000 + fee.id).toString().padLeft(7, '0'),
                          studentName: "Applicable to All ${fee.seatType} Students",
                          branch: fee.department,
                          category: fee.seatType,
                          year: "${fee.academicYear} • ${fee.semesterDisplayName}",
                          components: fee.components.map((c) => {'name': c.name, 'amount': c.amount}).toList(),
                          totalAmount: fee.totalAmount,
                          status: fee.status,
                          approvedDate: fee.status.toLowerCase() == 'approved' ? "Approved by Principal" : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (showPrincipalActions || showEditAction)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showEditAction)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text("Edit Structure"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () => context.push('/fees/edit/${fee.id}'),
                            ),
                          ),
                        if (showPrincipalActions)
                          Row(children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: actionState.isLoading ? null : () => _showRejectDialog(context, ref, fee.id),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: const Text("REJECT"),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: actionState.isLoading ? null : () async {
                                    final success = await ref.read(feeActionProvider.notifier).approveStructure(fee.id);
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Structure Approved!"), backgroundColor: Colors.green));
                                      ref.invalidate(feeStructureListProvider('pending'));
                                      context.pop();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: actionState.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("APPROVE"),
                                ),
                              ),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  void _showRejectDialog(BuildContext context, WidgetRef ref, int id) {
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Fee Structure"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for rejection."),
            const SizedBox(height: 16),
            TextField(controller: remarkCtrl, decoration: const InputDecoration(labelText: "Reason", border: OutlineInputBorder()), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (remarkCtrl.text.isEmpty) return;
              ctx.pop();
              final success = await ref.read(feeActionProvider.notifier).rejectStructure(id, remarkCtrl.text);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Structure Rejected"), backgroundColor: Colors.red));
                ref.invalidate(feeStructureListProvider('pending'));
                context.pop();
              }
            },
            child: const Text("Confirm Reject"),
          )
        ],
      ),
    );
  }
}