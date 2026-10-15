import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';

class TimetableEditScreen extends ConsumerStatefulWidget {
  final int id;
  const TimetableEditScreen({super.key, required this.id});

  @override
  ConsumerState<TimetableEditScreen> createState() => _TimetableEditScreenState();
}

class _TimetableEditScreenState extends ConsumerState<TimetableEditScreen> {
  bool _isLoading = true;
  TimeTable? _timetable;
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
          _slots = timetable.slots.map((s) => <String, dynamic>{
            "day": s.day,
            "assignment": s.assignmentId,
            "start_time": s.startTime,
            "end_time": s.endTime,
          }).toList();
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
          TextButton(
            onPressed: _submitUpdate,
            child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header (Read Only)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_timetable!.departmentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Semester ${_timetable!.semesterNo} • ${_timetable!.academicYearLabel}", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
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
        Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Chip(label: Text(day))),
        ...daySlots.map((slot) {
          final assignment = assignments.firstWhere((a) => a.id == slot['assignment'], orElse: () => AssignmentOption(id: 0, subjectName: 'Unknown', facultyName: ''));
          
          final start = slot['start_time'] as String;
          Widget? breakWidget;
          if (start.startsWith("11:30")) breakWidget = _buildBreakDivider("BREAK (11:20)");
          if (start.startsWith("14:00")) breakWidget = _buildBreakDivider("LUNCH (01:20)");

          return Column(
            children: [
              if (breakWidget != null) breakWidget,
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text("${slot['start_time']} - ${slot['end_time']}"),
                  subtitle: Text("${assignment.subjectName} (${assignment.facultyName})"),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _slots.remove(slot))),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildBreakDivider(String label) {
    return Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.symmetric(vertical: 4), width: double.infinity, color: Colors.amber[100], alignment: Alignment.center, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)));
  }

  void _showAddSlotDialog(List<AssignmentOption> assignments) {
    if (assignments.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No subjects."))); return; }
    String selectedDay = "MON";
    int? selectedAssignment = assignments.isNotEmpty ? assignments.first.id : null;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 30);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 25);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: const Text("Add Class Slot"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Day"), value: selectedDay,
                items: ["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => selectedDay = val!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Subject"), isExpanded: true,
                value: (assignments.any((a) => a.id == selectedAssignment)) ? selectedAssignment : null,
                items: assignments.map((a) => DropdownMenuItem(value: a.id, child: Text("${a.subjectName}\n(${a.facultyName})"))).toList(),
                onChanged: (val) => setState(() => selectedAssignment = val),
              ),
              const SizedBox(height: 15),
              const Text("Quick Select (Auto-skips breaks):", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Wrap(spacing: 5, children: [
                _timeChip("P1", 9, 30, 10, 25, setState, (s,e){ startTime=s; endTime=e; }),
                _timeChip("P2", 10, 25, 11, 20, setState, (s,e){ startTime=s; endTime=e; }),
                _timeChip("P3", 11, 30, 12, 25, setState, (s,e){ startTime=s; endTime=e; }),
                _timeChip("P4", 12, 25, 13, 20, setState, (s,e){ startTime=s; endTime=e; }),
                _timeChip("Post Lunch", 14, 00, 14, 55, setState, (s,e){ startTime=s; endTime=e; }),
              ]),
              const SizedBox(height: 15),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () async { final t = await showTimePicker(context: context, initialTime: startTime); if(t!=null) setState(()=>startTime=t); }, child: Text("Start: ${startTime.format(context)}"))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () async { final t = await showTimePicker(context: context, initialTime: endTime); if(t!=null) setState(()=>endTime=t); }, child: Text("End: ${endTime.format(context)}"))),
              ])
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            if (selectedAssignment == null) return;
            String formatTime(TimeOfDay t) { final now = DateTime.now(); return DateFormat("HH:mm:ss").format(DateTime(now.year, now.month, now.day, t.hour, t.minute)); }
            final Map<String, dynamic> newSlot = { "day": selectedDay, "assignment": selectedAssignment, "start_time": formatTime(startTime), "end_time": formatTime(endTime) };
            this.setState(() { _slots.add(newSlot); });
            Navigator.pop(ctx);
          }, child: const Text("Add"))
        ],
      );
    }));
  }

  Widget _timeChip(String label, int h1, int m1, int h2, int m2, Function setState, Function(TimeOfDay, TimeOfDay) onSelect) {
    return ActionChip(label: Text(label, style: const TextStyle(fontSize: 10)), onPressed: () { setState(() { onSelect(TimeOfDay(hour: h1, minute: m1), TimeOfDay(hour: h2, minute: m2)); }); });
  }
}