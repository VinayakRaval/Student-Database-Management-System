import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';

import 'package:frontend/core/constants/api_constants.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';
import '../widgets/official_timetable_header.dart';

final _roleProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'role');
});

class TimetableDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const TimetableDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TimetableDetailScreen> createState() => _TimetableDetailScreenState();
}

class _TimetableDetailScreenState extends ConsumerState<TimetableDetailScreen> {
  bool _isGridView = true;

  final double _rowHeight = 92.0;
  final double _headerHeight = 52.0;
  final double _baseSlotWidth = 140.0;
  final double _dayColWidth = 55.0;
  final double _breakColWidth = 40.0;
  final double _lunchColWidth = 65.0;

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final asyncTimetable = ref.watch(timetableDetailProvider(id));
    final auth = p.Provider.of<AuthProvider>(context);
    final roleAsync = ref.watch(_roleProvider);
    final role = (auth.role ?? roleAsync.value ?? 'HOD').toUpperCase();
    final isGridView = _isGridView;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Time Table Details"),
        centerTitle: true,
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: "Print / Landscape Preview",
            onPressed: () {
              asyncTimetable.whenData((tt) => _showPrintPreviewDialog(context, tt));
            },
          ),
          if (role == AppRoles.hod || role == AppRoles.system || role == AppRoles.principal) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: "Edit Timetable",
              onPressed: () async {
                await context.push('/timetable/edit/$id');
                ref.invalidate(timetableDetailProvider(id));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFCA5A5)),
              tooltip: "Delete Timetable",
              onPressed: () => _confirmDeleteTimetable(context, ref, id),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(timetableDetailProvider(id)),
          ),
        ],
      ),
      body: asyncTimetable.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text(
                  "Failed to Load Timetable",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF13246E)),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Retry"),
                  onPressed: () => ref.invalidate(timetableDetailProvider(id)),
                ),
              ],
            ),
          ),
        ),
        data: (timetable) {
          final isAuthorized = role == AppRoles.hod || role == AppRoles.system;
          final effectiveDt = timetable.effectiveDate != null ? DateTime.tryParse(timetable.effectiveDate!) : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Official College Timetable Header
                OfficialTimetableHeader(
                  departmentName: timetable.departmentName,
                  semesterNo: timetable.semesterNo,
                  academicYear: timetable.academicYearLabel,
                  classTeacherName: timetable.classTeacherName,
                  effectiveDate: effectiveDt,
                  isReadOnly: !isAuthorized,
                  onEffectiveDateChanged: isAuthorized
                      ? (newDate) async {
                          final str = DateFormat('yyyy-MM-dd').format(newDate);
                          final ok = await ref.read(timetableProvider.notifier).patchTimetable(timetable.id, {'effective_date': str});
                          if (ok) {
                            ref.invalidate(timetableDetailProvider(id));
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 16),

                // Top Status & Approval Action Bar (Status on one side, Approve/Reject on the other side)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Timetable Status: ",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                          ),
                          _buildStatusBadge(timetable.status),
                          if (timetable.classTeacherName != null && timetable.classTeacherName!.isNotEmpty) ...[
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_pin_rounded, size: 15, color: Color(0xFF13246E)),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Class Teacher: ${timetable.classTeacherName}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Color(0xFF13246E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (role == AppRoles.principal || role == AppRoles.hod || role == AppRoles.system) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (timetable.status == 'Pending' || timetable.status == 'Pending Reapproval' || timetable.status.toLowerCase().contains('pending')) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () {
                                  final remarksCtrl = TextEditingController();
                                  _handleAction(context, ref, timetable.id, "Rejected", remarksCtrl);
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                ),
                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                label: const Text("Approve Timetable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () {
                                  final remarksCtrl = TextEditingController();
                                  _handleAction(context, ref, timetable.id, "Approved", remarksCtrl);
                                },
                              ),
                            ] else if (timetable.status == 'Approved') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, size: 16, color: Color(0xFF15803D)),
                                    SizedBox(width: 5),
                                    Text("Approved Timetable", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Weekly Timetable Grid
                if (timetable.slots.isEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "No Timetable Slots Scheduled Yet",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "This timetable does not have scheduled classes or lab batches yet.",
                                style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                        if (isAuthorized)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.edit, size: 15),
                            label: const Text("Edit Schedule", style: TextStyle(fontSize: 11)),
                            onPressed: () async {
                              await context.push('/timetable/edit/$id');
                              ref.invalidate(timetableDetailProvider(id));
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isGridView ? "Weekly Schedule Grid" : "Weekly Schedule List",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF13246E)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isGridView = true),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isGridView ? const Color(0xFF13246E) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.grid_on_rounded,
                                    size: 14,
                                    color: isGridView ? Colors.white : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Grid View",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isGridView ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _isGridView = false),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: !isGridView ? const Color(0xFF13246E) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.view_agenda_outlined,
                                    size: 14,
                                    color: !isGridView ? Colors.white : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "List View",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !isGridView ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isGridView)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildFixedTemplateGrid(context, timetable.slots, availableWidth: constraints.maxWidth),
                      );
                    },
                  )
                else
                  _buildTimetableListView(timetable.slots),
                const SizedBox(height: 20),

                // 3. Official Subject Summary Table (Positioned at the bottom of the Weekly Timetable Grid)
                OfficialSubjectSummaryTable(
                  subjectDetails: timetable.subjectDetails,
                  teachingHoursSummary: timetable.teachingHoursSummary,
                ),
                const SizedBox(height: 20),

                // 4. Official Signature Areas
                const OfficialSignatureArea(),
                const SizedBox(height: 24),
                if (role == AppRoles.hod || role == AppRoles.system || role == AppRoles.principal) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade400, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text("Delete Timetable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () => _confirmDeleteTimetable(context, ref, timetable.id),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteTimetable(BuildContext context, WidgetRef ref, int timetableId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Delete Timetable?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this department timetable? This will permanently remove all scheduled slots, batch configurations, and history.",
          style: TextStyle(fontSize: 14, height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(timetableProvider.notifier).deleteTimetable(timetableId);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Timetable deleted successfully."),
                      backgroundColor: Colors.green,
                    ),
                  );
                  ref.invalidate(timetableListProvider);
                  context.pop();
                } else {
                  final err = ref.read(timetableProvider).errorMessage ?? "Failed to delete timetable.";
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );
  }



  Widget _buildTimetableListView(List<TimeTableSlot> slots) {
    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: const Text(
          "No timetable slots scheduled yet.",
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
    }

    final Map<String, List<TimeTableSlot>> grouped = {};
    for (var slot in slots) {
      final day = slot.day.toUpperCase();
      if (!grouped.containsKey(day)) grouped[day] = [];
      grouped[day]!.add(slot);
    }

    const daysOrder = ["MON", "TUE", "WED", "THU", "FRI", "SAT"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: daysOrder.map((day) {
        if (!grouped.containsKey(day)) return const SizedBox.shrink();
        final daySlots = grouped[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF13246E)),
                  const SizedBox(width: 8),
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF13246E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13246E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${daySlots.length} sessions",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF13246E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...daySlots.expand((slot) => _buildListViewSlotCards(slot)),
            const SizedBox(height: 6),
          ],
        );
      }).toList(),
    );
  }

  List<Widget> _buildListViewSlotCards(TimeTableSlot slot) {
    if ((slot.isBatchWise || slot.batches.isNotEmpty) && slot.batches.isNotEmpty) {
      return slot.batches.map((b) {
        final String rawBatchName = b.batchName.trim();
        final String batchName = rawBatchName.isNotEmpty ? rawBatchName : "Batch Not Assigned";
        final String subjectName = (b.subjectName != null && b.subjectName!.isNotEmpty) ? b.subjectName! : (slot.subjectName ?? "Unknown Subject");
        final String subjectCode = (b.subjectCode != null && b.subjectCode!.isNotEmpty) ? b.subjectCode! : (slot.subjectCode ?? "");
        final String facultyName = (b.facultyName != null && b.facultyName!.isNotEmpty) ? b.facultyName! : (slot.facultyName ?? "Faculty Not Assigned");
        final String labRoom = b.labRoom.trim().isNotEmpty ? b.labRoom.trim() : (slot.labRoom.trim().isNotEmpty ? slot.labRoom.trim() : "Lab 1");
        final String startTime = (b.startTime != null && b.startTime!.isNotEmpty) ? b.startTime! : slot.startTime;
        final String endTime = (b.endTime != null && b.endTime!.isNotEmpty) ? b.endTime! : slot.endTime;

        return _buildClassCard(
          startTime: startTime,
          endTime: endTime,
          subjectName: subjectName,
          subjectCode: subjectCode,
          batchName: batchName,
          facultyName: facultyName,
          labRoom: labRoom,
          branchName: b.subjectDepartment ?? slot.subjectDepartment ?? "",
          isLab: true,
        );
      }).toList();
    }

    if (slot.isBatchWise || slot.batches.isNotEmpty) {
      final String rawBatchName = (slot.batchName ?? "").trim();
      final String batchName = rawBatchName.isNotEmpty ? rawBatchName : "Batch Not Assigned";
      final String subjectName = slot.subjectName ?? "Unknown Subject";
      final String subjectCode = slot.subjectCode ?? "";
      final String facultyName = slot.facultyName ?? "Faculty Not Assigned";
      final String labRoom = slot.labRoom.trim().isNotEmpty ? slot.labRoom.trim() : "Lab 1";

      return [
        _buildClassCard(
          startTime: slot.startTime,
          endTime: slot.endTime,
          subjectName: subjectName,
          subjectCode: subjectCode,
          batchName: batchName,
          facultyName: facultyName,
          labRoom: labRoom,
          branchName: slot.subjectDepartment ?? "",
          isLab: true,
        )
      ];
    }

    // Theory slot
    return [
      _buildClassCard(
        startTime: slot.startTime,
        endTime: slot.endTime,
        subjectName: slot.subjectName ?? "Unknown Subject",
        subjectCode: slot.subjectCode ?? "",
        batchName: null,
        facultyName: slot.facultyName ?? "Faculty Not Assigned",
        labRoom: slot.labRoom.trim().isNotEmpty ? slot.labRoom.trim() : "Classroom",
        branchName: slot.subjectDepartment ?? "",
        isLab: false,
      )
    ];
  }

  Widget _buildClassCard({
    required String startTime,
    required String endTime,
    required String subjectName,
    required String subjectCode,
    required String? batchName,
    required String facultyName,
    required String labRoom,
    required String branchName,
    required bool isLab,
  }) {
    final tRange12 = TimeTable.formatTimeRange12(startTime, endTime);
    final sTime12 = TimeTable.formatTime12(startTime);
    final eTime12 = TimeTable.formatTime12(endTime);
    final isUnassignedBatch = batchName == "Batch Not Assigned";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isLab ? const Color(0xFFBFDBFE) : Colors.grey.shade300,
          width: isLab ? 1.2 : 1.0,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Time Column
                Container(
                  width: 95,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLab ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLab ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        sTime12,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF13246E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(Icons.arrow_downward, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(height: 2),
                      Text(
                        eTime12,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF13246E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isLab ? const Color(0xFFDBEAFE) : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLab ? "2 hrs" : "1 hr",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isLab ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Name
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Badges Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (subjectCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13246E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subjectCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isLab) ...[
                            if (batchName != null && !isUnassignedBatch)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.group, size: 12, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 3),
                                    Text(
                                      batchName,
                                      style: const TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isUnassignedBatch)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFCD34D)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFF92400E)),
                                    SizedBox(width: 3),
                                    Text(
                                      "Batch Not Assigned",
                                      style: TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: const Text(
                                "LAB / PRACTICAL",
                                style: TextStyle(
                                  color: Color(0xFF6B21A8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Text(
                                "THEORY",
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Faculty & Room
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Color(0xFF13246E)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              facultyName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF13246E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (labRoom.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(isLab ? Icons.computer : Icons.meeting_room_outlined, size: 14, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text(
                              labRoom,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Highlighted Pipe-Delimited Summary Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isLab
                          ? "$tRange12  |  $subjectName  |  ${batchName ?? 'Batch Not Assigned'}  |  $facultyName  |  ${labRoom.isNotEmpty ? labRoom : 'Lab'}"
                          : "$tRange12  |  $subjectName  |  $facultyName  |  ${labRoom.isNotEmpty ? labRoom : 'Room'}",
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildFixedTemplateGrid(
    BuildContext context,
    List<TimeTableSlot> slots, {
    double? availableWidth,
  }) {
    final List<Map<String, dynamic>> templateColumns = [
      {"start": "09:30", "end": "10:30", "type": "CLASS"},
      {"start": "10:30", "end": "11:30", "type": "CLASS"},
      {"start": "11:30", "end": "12:30", "type": "CLASS"},
      {"start": "12:30", "end": "13:30", "type": "CLASS"},
      {
        "start": "13:30",
        "end": "14:00",
        "type": "LUNCH",
        "label": "LUNCH",
      },
      {"start": "14:00", "end": "15:00", "type": "CLASS"},
      {"start": "15:00", "end": "16:00", "type": "CLASS"},
    ];

    final fixedColsWidth = _dayColWidth + _lunchColWidth;
    final double remainingWidth = (availableWidth != null && availableWidth > fixedColsWidth)
        ? (availableWidth - fixedColsWidth)
        : (6 * _baseSlotWidth);
    final double slotWidth = (remainingWidth / 6.0).clamp(135.0, 320.0);
    final double totalWidth = math.max(availableWidth ?? 0, fixedColsWidth + (6 * slotWidth));
    final double totalHeight = _headerHeight + (_rowHeight * 6);

    return SizedBox(
      height: totalHeight,
      width: totalWidth,
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeaderRow(templateColumns, slotWidth),
              ...["MON", "TUE", "WED", "THU", "FRI", "SAT"].asMap().entries.map(
                (e) {
                  return _buildDayRow(context, e.value, e.key, templateColumns, slots, slotWidth);
                },
              ),
            ],
          ),
          ..._buildOverlays(templateColumns, totalHeight, slotWidth),
        ],
      ),
    );
  }

  List<Widget> _buildOverlays(
    List<Map<String, dynamic>> columns,
    double height,
    double slotWidth,
  ) {
    List<Widget> overlays = [];
    double currentX = _dayColWidth;
    for (var col in columns) {
      double width = slotWidth;
      if (col['type'] == 'BREAK') width = _breakColWidth;
      if (col['type'] == 'LUNCH') width = _lunchColWidth;
      if (col['type'] == 'BREAK' || col['type'] == 'LUNCH') {
        overlays.add(
          Positioned(
            left: currentX,
            top: _headerHeight,
            child: _buildVerticalBar(
              col['label'] as String,
              width,
              height - _headerHeight,
              const Color(0xFFFEF3C7),
            ),
          ),
        );
      }
      currentX += width;
    }
    return overlays;
  }

  Widget _buildVerticalBar(
    String text,
    double width,
    double height,
    Color color,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: const Text(
              "LUNCH",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: Color(0xFF92400E),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "BREAK",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 9,
              color: Color(0xFFB45309),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(List<Map<String, dynamic>> columns, double slotWidth) {
    return Row(
      children: [
        _buildFixedHeaderCell("TIME", width: _dayColWidth),
        ...columns.map((col) {
          double width = slotWidth;
          if (col['type'] == 'BREAK') width = _breakColWidth;
          if (col['type'] == 'LUNCH') {
            return _buildLunchHeaderCell(_lunchColWidth);
          }
          return _buildHeaderCell(col['start'] as String, col['end'] as String, width);
        }),
      ],
    );
  }

  Widget _buildLunchHeaderCell(double width) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "LUNCH",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF92400E),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 2),
          Text(
            "13:30-14:00",
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF78350F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(
    BuildContext context,
    String day,
    int idx,
    List<Map<String, dynamic>> columns,
    List<TimeTableSlot> allSlots,
    double slotWidth,
  ) {
    return Container(
      height: _rowHeight,
      color: idx % 2 == 0 ? Colors.white : Colors.grey[50],
      child: Row(
        children: [
          _buildDayCell(day),
          ..._buildRowCells(context, day, columns, allSlots, slotWidth),
        ],
      ),
    );
  }

  static bool _timeMatches(String? t1, String? t2) {
    if (t1 == null || t2 == null) return false;
    String norm1 = t1.trim();
    String norm2 = t2.trim();
    if (norm1.length == 4 && norm1.indexOf(':') == 1) norm1 = '0$norm1';
    if (norm2.length == 4 && norm2.indexOf(':') == 1) norm2 = '0$norm2';
    final len = math.min(5, math.min(norm1.length, norm2.length));
    return norm1.substring(0, len) == norm2.substring(0, len);
  }

  static int _compareTime(String t1, String t2) {
    String norm1 = t1.trim();
    String norm2 = t2.trim();
    if (norm1.length == 4 && norm1.indexOf(':') == 1) norm1 = '0$norm1';
    if (norm2.length == 4 && norm2.indexOf(':') == 1) norm2 = '0$norm2';
    final sub1 = norm1.substring(0, math.min(5, norm1.length));
    final sub2 = norm2.substring(0, math.min(5, norm2.length));
    return sub1.compareTo(sub2);
  }

  List<Widget> _buildRowCells(
    BuildContext context,
    String day,
    List<Map<String, dynamic>> columns,
    List<TimeTableSlot> allSlots,
    double slotWidth,
  ) {
    List<Widget> cells = [];
    int i = 0;
    while (i < columns.length) {
      final col = columns[i];
      if (col['type'] == 'BREAK') {
        cells.add(SizedBox(width: _breakColWidth));
        i++;
        continue;
      }
      if (col['type'] == 'LUNCH') {
        cells.add(SizedBox(width: _lunchColWidth));
        i++;
        continue;
      }

      final cellSlots = allSlots.where(
        (s) => s.day.toUpperCase() == day.toUpperCase() && _timeMatches(s.startTime, col['start'] as String),
      ).toList();

      if (cellSlots.isNotEmpty) {
        final primarySlot = cellSlots.first;
        double mergeWidth = 0;
        int span = 0;
        for (int k = i; k < columns.length; k++) {
          double w = slotWidth;
          if (columns[k]['type'] == 'BREAK') w = _breakColWidth;
          if (columns[k]['type'] == 'LUNCH') w = _lunchColWidth;
          mergeWidth += w;
          span++;
          if (_compareTime(primarySlot.endTime, columns[k]['end'] as String) <= 0) {
            break;
          }
        }

        final tRange = "${primarySlot.startTime.substring(0, math.min(5, primarySlot.startTime.length))} - ${primarySlot.endTime.substring(0, math.min(5, primarySlot.endTime.length))}";
        cells.add(_buildClassCell(context, cellSlots, mergeWidth, day: day, timeRange: tRange));
        i += span;
      } else {
        cells.add(_buildEmptyCell(slotWidth));
        i++;
      }
    }
    return cells;
  }

  Widget _buildClassCell(
    BuildContext context,
    List<TimeTableSlot> slots,
    double width, {
    required String day,
    required String timeRange,
  }) {
    final hasBatches = slots.any((s) => s.isBatchWise || s.batches.isNotEmpty);
    List<_DisplayItem> items = [];

    if (hasBatches) {
      for (var s in slots) {
        if (s.batches.isNotEmpty) {
          for (var b in s.batches) {
            items.add(_DisplayItem(
              subjectCode: (b.subjectCode != null && b.subjectCode!.isNotEmpty) ? b.subjectCode! : (s.subjectCode ?? 'Code'),
              subjectName: (b.subjectName != null && b.subjectName!.isNotEmpty) ? b.subjectName! : (s.subjectName ?? 'Subject'),
              facultyName: (b.facultyName != null && b.facultyName!.isNotEmpty) ? b.facultyName! : (s.facultyName ?? 'Faculty'),
              batchName: b.batchName,
              labRoom: b.labRoom,
              credits: b.credits,
              theoryHours: b.theoryHours,
              practicalHours: b.practicalHours,
            ));
          }
        } else {
          items.add(_DisplayItem(
            subjectCode: s.subjectCode ?? 'Code',
            subjectName: s.subjectName ?? 'Subject',
            facultyName: s.facultyName ?? 'Faculty',
            batchName: s.batchName,
            labRoom: s.labRoom,
            credits: s.credits,
            theoryHours: s.theoryHours,
            practicalHours: s.practicalHours,
          ));
        }
      }
    } else {
      for (var s in slots) {
        items.add(_DisplayItem(
          subjectCode: s.subjectCode ?? 'Code',
          subjectName: s.subjectName ?? 'Subject',
          facultyName: s.facultyName ?? 'Faculty',
          batchName: s.batchName,
          labRoom: s.labRoom,
          credits: s.credits,
          theoryHours: s.theoryHours,
          practicalHours: s.practicalHours,
        ));
      }
    }

    final tooltipText = items.map((it) {
      final bStr = it.batchName != null && it.batchName!.isNotEmpty ? " [${it.batchName}]" : "";
      final rStr = it.labRoom.isNotEmpty ? " (Room: ${it.labRoom})" : "";
      return "$day $timeRange$bStr\n${it.subjectCode}: ${it.subjectName}\nFaculty: ${it.facultyName}$rStr";
    }).join("\n---\n");

    return Tooltip(
      message: tooltipText,
      padding: const EdgeInsets.all(8),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSlotDetailsDialog(context, day, timeRange, items),
          child: Container(
            width: width,
            height: _rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: _buildCellContent(items, width),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(List<_DisplayItem> items, double width) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (items.length == 1) {
      final item = items.first;
      final hasBatch = item.batchName != null && item.batchName!.isNotEmpty;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasBatch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
              ),
              child: Text(
                item.batchName!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF1D4ED8)),
              ),
            ),
          Text(
            item.subjectCode,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF13246E),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            item.subjectName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              color: Color(0xFF334155),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.facultyName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 9.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      );
    }

    // Multiple batches
    if (width >= 230) {
      return Row(
        children: items.map((it) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13246E),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          it.batchName ?? "B",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          it.subjectCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF13246E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    it.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF334155)),
                  ),
                  Text(
                    it.facultyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                  ),
                  if (it.labRoom.isNotEmpty)
                    Text(
                      it.labRoom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.map((it) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (it.batchName != null && it.batchName!.isNotEmpty) ...[
                  Text(
                    "${it.batchName}: ",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF13246E)),
                  ),
                ],
                Expanded(
                  child: Text(
                    "${it.subjectCode} (${it.facultyName})",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyCell(double width) {
    return Container(
      width: width,
      height: _rowHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: Text(
        "—",
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFixedHeaderCell(String text, {required double width}) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF0F172A),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String start, String end, double width) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Text(
        "$start\nTo\n$end",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF1E293B),
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildDayCell(String day) {
    return Container(
      width: _dayColWidth,
      height: _rowHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Text(
        day,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
      ),
    );
  }

  void _showSlotDetailsDialog(
    BuildContext context,
    String day,
    String timeRange,
    List<_DisplayItem> items,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: Color(0xFF13246E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$day Schedule Details",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF13246E)),
                  ),
                  Text(
                    timeRange,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                ...items.map((it) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (it.batchName != null && it.batchName!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13246E),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  it.batchName!,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                "${it.subjectCode} - ${it.subjectName}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Faculty: ${it.facultyName}",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        if (it.labRoom.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.meeting_room_outlined, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                "Room / Location: ${it.labRoom}",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              "Credits: ${it.credits}",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Theory: ${it.theoryHours}h",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            if (it.practicalHours > 0) ...[
                              const SizedBox(width: 12),
                              Text(
                                "Practical: ${it.practicalHours}h",
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toLowerCase();
    final isApproved = s == 'approved';
    final isRejected = s == 'rejected';
    final Color c = isApproved ? const Color(0xFF15803D) : (isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706));
    final Color bg = isApproved ? const Color(0xFFDCFCE7) : (isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }



  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    int id,
    String action,
    TextEditingController ctrl,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$action Timetable"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Remarks"),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(timetableProvider.notifier)
                  .approveTimetable(id, action, remarks: ctrl.text);
              if (context.mounted) {
                context.pop();
                ref.invalidate(timetableListProvider);
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  void _showPrintPreviewDialog(BuildContext context, TimeTable timetable) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 980,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.print, color: Color(0xFF13246E)),
                      SizedBox(width: 8),
                      Text(
                        "Official Printable Timetable Preview",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF13246E)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OfficialTimetableHeader(
                          departmentName: timetable.departmentName,
                          semesterNo: timetable.semesterNo,
                          academicYear: timetable.academicYearLabel,
                          effectiveDate: timetable.effectiveDate != null ? DateTime.tryParse(timetable.effectiveDate!) : null,
                          isPrintMode: true,
                          isReadOnly: true,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildFixedTemplateGrid(context, timetable.slots, availableWidth: constraints.maxWidth),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        OfficialSubjectSummaryTable(
                          subjectDetails: timetable.subjectDetails,
                          teachingHoursSummary: timetable.teachingHoursSummary,
                          isPrintMode: true,
                        ),
                        const SizedBox(height: 20),
                        const OfficialSignatureArea(isPrintMode: true),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text("Print Landscape"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Printing layout configured for Landscape A4."), backgroundColor: Color(0xFF13246E)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DisplayItem {
  final String subjectCode;
  final String subjectName;
  final String facultyName;
  final String? batchName;
  final String labRoom;
  final int credits;
  final int theoryHours;
  final int practicalHours;

  _DisplayItem({
    required this.subjectCode,
    required this.subjectName,
    required this.facultyName,
    this.batchName,
    this.labRoom = '',
    this.credits = 4,
    this.theoryHours = 3,
    this.practicalHours = 0,
  });
}
