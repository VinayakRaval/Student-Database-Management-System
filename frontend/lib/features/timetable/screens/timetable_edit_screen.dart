import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';
import '../widgets/add_slot_dialog.dart';
import '../widgets/official_timetable_header.dart';

class TimetableEditScreen extends ConsumerStatefulWidget {
  final int id;
  const TimetableEditScreen({super.key, required this.id});

  @override
  ConsumerState<TimetableEditScreen> createState() => _TimetableEditScreenState();
}

class _TimetableEditScreenState extends ConsumerState<TimetableEditScreen> {
  bool _isLoading = true;
  TimeTable? _timetable;
  DateTime? _effectiveDate;
  List<Map<String, dynamic>> _slots = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final timetable = await ref.read(timetableDetailProvider(widget.id).future);
      await ref.read(timetableProvider.notifier).fetchAssignments(timetable.departmentId, timetable.semesterId, timetable.academicYearId);

      if (mounted) {
        setState(() {
          _timetable = timetable;
          _effectiveDate = timetable.effectiveDate != null ? DateTime.tryParse(timetable.effectiveDate!) : null;
          _slots = timetable.slots.map((s) => s.toMap()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load timetable: $e"), backgroundColor: Colors.red),
        );
        context.pop();
      }
    }
  }

  void _submitUpdate() async {
    if (_timetable == null) return;
    final payload = {
      "department": _timetable!.departmentId,
      "semester": _timetable!.semesterId,
      "academic_year": _timetable!.academicYearId,
      "effective_date": _effectiveDate != null ? DateFormat('yyyy-MM-dd').format(_effectiveDate!) : null,
      "remarks": "Updated via App",
      "slots": _slots 
    };
    final success = await ref.read(timetableProvider.notifier).updateTimetable(widget.id, payload);
    if (success && mounted) {
      ref.invalidate(timetableListProvider);
      ref.invalidate(timetableDetailProvider(widget.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Timetable updated successfully!"), backgroundColor: Colors.green),
      );
      context.go('/timetable/list'); 
    } else if (mounted) {
      final err = ref.read(timetableProvider).errorMessage ?? "Failed to update timetable";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timetableProvider);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Edit Timetable (v${_timetable!.version})"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: "Delete Timetable",
            onPressed: _confirmDeleteTimetable,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _submitUpdate,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Official Timetable Header with editable W.E.F Date
            OfficialTimetableHeader(
              departmentName: _timetable!.departmentName,
              semesterNo: _timetable!.semesterNo,
              academicYear: _timetable!.academicYearLabel,
              classTeacherName: _timetable!.classTeacherName,
              effectiveDate: _effectiveDate,
              onEffectiveDateChanged: (newDate) {
                setState(() {
                  _effectiveDate = newDate;
                });
              },
            ),
            const SizedBox(height: 20),
            
            // Slots List with Breaks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Weekly Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add Slot"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                  onPressed: () => _showAddSlotDialog(state.availableAssignments),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((day) => _buildDaySection(day, state.availableAssignments)),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(String day, List<AssignmentOption> assignments) {
    final daySlots = _slots.where((s) => s['day'] == day).toList();
    daySlots.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time']));

    if (daySlots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Chip(
            backgroundColor: const Color(0xFF13246E),
            label: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        ...daySlots.map((slot) {
          final isBatchWise = slot['is_batch_wise'] == true || (slot['batches'] is List && (slot['batches'] as List).isNotEmpty);
          final batches = isBatchWise ? (slot['batches'] as List? ?? []) : [];

          final start = slot['start_time'] as String;
          Widget? breakWidget;
          if (start.startsWith("11:30")) breakWidget = _buildBreakDivider("BREAK (11:20)");
          if (start.startsWith("14:00")) breakWidget = _buildBreakDivider("LUNCH (01:20)");

          if (isBatchWise) {
            return Column(
              children: [
                ?breakWidget,
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.science_outlined, color: Color(0xFF13246E), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              TimeTable.formatTimeRange12(slot['start_time'], slot['end_time']),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${batches.length} BATCHES",
                                style: const TextStyle(color: Color(0xFF3730A3), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (slot['allow_co_teaching'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "CO-TEACHING",
                                  style: TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _slots.remove(slot)),
                            ),
                          ],
                        ),
                        const Divider(height: 12, color: Color(0xFFF1F5F9)),
                        // Display Batch rows (Req 9)
                        ...batches.map((b) {
                          final bMap = Map<String, dynamic>.from(b as Map);
                          final bAssign = assignments.firstWhere(
                            (a) => a.id == bMap['assignment'],
                            orElse: () => AssignmentOption(id: 0, subjectName: 'Unknown', facultyName: ''),
                          );
                          final bName = bMap['batch_name'] ?? 'Batch';
                          final room = (bMap['lab_room'] != null && bMap['lab_room'].toString().isNotEmpty)
                              ? " • Room: ${bMap['lab_room']}"
                              : "";
                          final timeStr = (bMap['start_time'] != null && bMap['start_time'] != slot['start_time'])
                              ? " (${TimeTable.formatTimeRange12(bMap['start_time'], bMap['end_time'])})"
                              : "";

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13246E),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${bAssign.subjectName}$room$timeStr • Prof: ${bAssign.facultyName}",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final assignment = assignments.firstWhere(
            (a) => a.id == slot['assignment'],
            orElse: () => AssignmentOption(id: 0, subjectName: 'Unknown', facultyName: ''),
          );
          
          final hasDept = assignment.subjectDepartment != null && assignment.subjectDepartment!.trim().isNotEmpty;
          final deptTag = hasDept ? " [${assignment.subjectDepartment}]" : "";
          final codeTag = (assignment.subjectCode != null && assignment.subjectCode!.trim().isNotEmpty) ? " (${assignment.subjectCode})" : "";

          return Column(
            children: [
              ?breakWidget,
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFF13246E)),
                  title: Text(TimeTable.formatTimeRange12(slot['start_time'], slot['end_time']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text("${assignment.subjectName}$codeTag$deptTag (${assignment.facultyName})", style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _slots.remove(slot))),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildBreakDivider(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      color: Colors.amber[100],
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
    );
  }

  void _showAddSlotDialog(List<AssignmentOption> assignments) {
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No subjects available.")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AddClassSlotDialog(
        availableAssignments: assignments,
        onSave: (newSlot) {
          setState(() {
            _slots.add(newSlot);
          });
        },
      ),
    );
  }

  void _confirmDeleteTimetable() {
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
          "Are you sure you want to permanently delete this department timetable? This action cannot be undone.",
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
              final success = await ref.read(timetableProvider.notifier).deleteTimetable(widget.id);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Timetable deleted successfully."), backgroundColor: Colors.green),
                  );
                  ref.invalidate(timetableListProvider);
                  context.go('/timetable/list');
                } else {
                  final err = ref.read(timetableProvider).errorMessage ?? "Failed to delete timetable.";
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
