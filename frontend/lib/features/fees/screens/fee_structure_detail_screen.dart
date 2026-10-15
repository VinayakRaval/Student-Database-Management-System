import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/constants/api_constants.dart';
import '../providers/fee_action_provider.dart';
import '../models/fee_structure_models.dart';

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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            Text(fee.department, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF13246E)), textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text("${fee.semesterDisplayName} • ${fee.academicYear}", style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                            const SizedBox(height: 12),
                            Chip(label: Text(fee.seatType, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: const Color(0xFF13246E)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: _getStatusColor(fee.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(fee.status.toUpperCase(), style: TextStyle(color: _getStatusColor(fee.status), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Fee Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13246E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${fee.components.length} Components",
                              style: const TextStyle(
                                color: Color(0xFF13246E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            if (fee.components.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text("No fee components have been added to this structure.", style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            else
                              ...fee.components.asMap().entries.map((entry) {
                                final idx = entry.key + 1;
                                final c = entry.value;
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.grey.shade100,
                                            child: Text(
                                              "$idx",
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(c.name, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
                                          ),
                                          Text("₹${c.amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                        ],
                                      ),
                                    ),
                                    if (idx < fee.components.length)
                                      Divider(height: 1, indent: 20, endIndent: 20, color: Colors.grey.shade100),
                                  ],
                                );
                              }),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text("TOTAL FEE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("₹${fee.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                              ]),
                            ),
                          ],
                        ),
                      ),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
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