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

class FeeStructureListScreen extends ConsumerStatefulWidget {
  const FeeStructureListScreen({super.key});

  @override
  ConsumerState<FeeStructureListScreen> createState() =>
      _FeeStructureListScreenState();
}

class _FeeStructureListScreenState
    extends ConsumerState<FeeStructureListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(_roleProvider);
    final role = roleAsync.value ?? 'STUDENT';
    final String apiFilter = (role == AppRoles.principal) ? 'pending' : 'all';
    final listAsync = ref.watch(feeStructureListProvider(apiFilter));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          role == AppRoles.principal ? "Pending Approvals" : "Fee Structures",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(feeStructureListProvider(apiFilter)),
            tooltip: "Refresh Structures",
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Error: $e", style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.invalidate(feeStructureListProvider(apiFilter)),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
        data: (allList) {
          // Compute counts
          final totalCount = allList.length;
          final pendingCount = allList
              .where((s) => s.status.toLowerCase() == 'pending')
              .length;
          final approvedCount = allList
              .where((s) => s.status.toLowerCase() == 'approved')
              .length;
          final rejectedCount = allList
              .where((s) => s.status.toLowerCase() == 'rejected')
              .length;

          // Apply filters
          final query = _searchCtrl.text.trim().toLowerCase();
          final filteredList = allList.where((item) {
            // Status match
            if (_statusFilter != 'all' &&
                item.status.toLowerCase() != _statusFilter) {
              return false;
            }
            // Search query match
            if (query.isNotEmpty) {
              final dept = item.department.toLowerCase();
              final year = item.academicYear.toLowerCase();
              final sem = item.semester.toLowerCase();
              final seat = item.seatType.toLowerCase();
              final componentsMatch = item.components.any(
                (c) => c.name.toLowerCase().contains(query),
              );
              return dept.contains(query) ||
                  year.contains(query) ||
                  sem.contains(query) ||
                  seat.contains(query) ||
                  componentsMatch;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Search & Filter Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search by department, semester, seat type, or component...",
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip("All ($totalCount)", 'all'),
                          const SizedBox(width: 8),
                          _filterChip("Pending ($pendingCount)", 'pending', color: Colors.orange),
                          const SizedBox(width: 8),
                          _filterChip("Approved ($approvedCount)", 'approved', color: Colors.green),
                          const SizedBox(width: 8),
                          _filterChip("Rejected ($rejectedCount)", 'rejected', color: Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Structures List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              allList.isEmpty
                                  ? "No fee structures found."
                                  : "No structures match the current filter.",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final FeeStructure item = filteredList[index];
                          return _FeeStructureCard(
                            item: item,
                            userRole: role,
                            onRefresh: () => ref.invalidate(
                              feeStructureListProvider(apiFilter),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: role == AppRoles.accounts
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              onPressed: () => context.push('/fees/create').then((_) {
                ref.invalidate(feeStructureListProvider(apiFilter));
              }),
              label: const Text("Create Structure"),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _filterChip(String label, String value, {Color? color}) {
    final isSelected = _statusFilter == value;
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
        if (val) setState(() => _statusFilter = value);
      },
    );
  }
}

class _FeeStructureCard extends StatefulWidget {
  final FeeStructure item;
  final String userRole;
  final VoidCallback onRefresh;

  const _FeeStructureCard({
    required this.item,
    required this.userRole,
    required this.onRefresh,
  });

  @override
  State<_FeeStructureCard> createState() => _FeeStructureCardState();
}

class _FeeStructureCardState extends State<_FeeStructureCard> {
  bool _isComponentsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isApproved = item.status.toLowerCase() == 'approved';
    final isRejected = item.status.toLowerCase() == 'rejected';
    final isPending = item.status.toLowerCase() == 'pending';

    final Color statusColor = isApproved
        ? Colors.green
        : isRejected
            ? Colors.red
            : Colors.orange;

    final Color statusBg = statusColor.withValues(alpha: 0.1);

    final canEdit = widget.userRole == AppRoles.accounts &&
        (isPending || isRejected);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRejected
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: isRejected ? 1.5 : 1.0,
        ),
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
          // Header: Department, Semester, Status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.department,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF13246E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13246E).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.semesterDisplayName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF13246E),
                                  ),
                                ),
                              ),
                              if (item.academicYear.isNotEmpty)
                                Text(
                                  "• ${item.academicYear}",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.seatType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // Rejection remark alert if rejected
                if (isRejected && item.remarks != null && item.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Reason: ${item.remarks}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
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

          const Divider(height: 1),

          // FEE COMPONENTS BREAKDOWN (Fix for: How many components added all show in view structure)
          Container(
            color: const Color(0xFFFAFBFC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isComponentsExpanded = !_isComponentsExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                              color: Color(0xFF13246E),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "Components Added:",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.components.isEmpty
                                    ? Colors.grey.shade200
                                    : const Color(0xFF13246E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${item.components.length} ${item.components.length == 1 ? 'Component' : 'Components'}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.components.isEmpty
                                      ? Colors.grey.shade700
                                      : const Color(0xFF13246E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _isComponentsExpanded ? "Hide" : "Show All",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF13246E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              _isComponentsExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: const Color(0xFF13246E),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (item.components.isEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      "No fee components added to this structure.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ] else if (_isComponentsExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: item.components.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final c = entry.value;
                        final isLast = idx == item.components.length;
                        return Container(
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Text(
                                "$idx.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF374151),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                "₹${c.amount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  // Collapsed summary preview chips
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...item.components.take(3).map(
                            (c) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                "${c.name}: ₹${c.amount.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                      if (item.components.length > 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "+${item.components.length - 3} more",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Footer: Total Amount and Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL STRUCTURE FEE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "₹${item.totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (canEdit) ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/fees/edit/${item.id}').then((_) {
                          widget.onRefresh();
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF13246E),
                          side: const BorderSide(color: Color(0xFF13246E)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text("Edit", style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: () =>
                          context.push('/fees/detail/${item.id}').then((_) {
                        widget.onRefresh();
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text("View Details", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
