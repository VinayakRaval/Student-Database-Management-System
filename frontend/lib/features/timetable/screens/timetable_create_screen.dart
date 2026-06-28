import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';
import '../../subjects/providers/assign_subject_provider.dart'; 

class TimetableCreateScreen extends ConsumerStatefulWidget {
  const TimetableCreateScreen({super.key});

  @override
  ConsumerState<TimetableCreateScreen> createState() => _TimetableCreateScreenState();
}

class _TimetableCreateScreenState extends ConsumerState<TimetableCreateScreen> {
  int? _selectedDept;
  int? _selectedSem;
  int? _selectedAy;
  
  // Explicitly typed list
  final List<Map<String, dynamic>> _slots = [];

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(assignSubjectProvider);
    final timetableState = ref.watch(timetableProvider);

    ref.listen(timetableProvider, (prev, next) {
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Timetable Created Successfully!"), backgroundColor: Colors.green));
        context.pop();
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Create Timetable"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _slots.isEmpty ? null : _submitTimetable,
            child: const Text("Save Draft", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CONFIGURATION ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: "Department", border: OutlineInputBorder()),
                    value: _selectedDept,
                    items: configState.departments.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    onChanged: (val) { setState(() => _selectedDept = val); _fetchAssignments(); },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: "Semester", border: OutlineInputBorder()),
                          value: _selectedSem,
                          items: configState.semesters.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                          onChanged: (val) { setState(() => _selectedSem = val); _fetchAssignments(); },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: "Academic Year", border: OutlineInputBorder()),
                          value: _selectedAy,
                          items: configState.academicYears.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                          onChanged: (val) { setState(() => _selectedAy = val); _fetchAssignments(); },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- SLOTS HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Weekly Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add Slot"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                  onPressed: (_selectedDept != null && _selectedSem != null && _selectedAy != null)
                      ? () => _showAddSlotDialog(timetableState.availableAssignments)
                      : null,
                ),
              ],
            ),
            
            const SizedBox(height: 10),

            if (_slots.isEmpty)
              const Padding(padding: EdgeInsets.all(40.0), child: Center(child: Text("No slots added. Click 'Add Slot' to begin.", style: TextStyle(color: Colors.grey)))),

            // --- DAY LIST ---
            ...["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((day) => _buildDaySection(day, timetableState.availableAssignments)),
            
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
          child: Chip(label: Text(day, style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
        ...daySlots.map((slot) {
          final assignment = assignments.firstWhere(
            (a) => a.id == slot['assignment'],
            orElse: () => AssignmentOption(id: 0, subjectName: 'Unknown', facultyName: ''),
          );

          // VISUAL BREAK INDICATORS
          final start = slot['start_time'] as String;
          Widget? breakWidget;
          if (start.startsWith("11:30")) breakWidget = _buildBreakDivider("BREAK (11:20 - 11:30)");
          if (start.startsWith("14:00") || start.startsWith("13:20")) breakWidget = _buildBreakDivider("LUNCH BREAK (01:20 - 02:00)");

          return Column(
            children: [
              if (breakWidget != null) breakWidget,
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFF13246E)),
                  title: Text("${slot['start_time']} - ${slot['end_time']}"),
                  subtitle: Text("${assignment.subjectName} (${assignment.facultyName})"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _slots.remove(slot)),
                  ),
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

  void _fetchAssignments() {
    if (_selectedDept != null && _selectedSem != null && _selectedAy != null) {
      setState(() => _slots.clear());
      ref.read(timetableProvider.notifier).fetchAssignments(_selectedDept!, _selectedSem!, _selectedAy!);
    }
  }

  void _submitTimetable() {
    final payload = {
      "department": _selectedDept,
      "semester": _selectedSem,
      "academic_year": _selectedAy,
      "remarks": "Created via App",
      "slots": _slots 
    };
    ref.read(timetableProvider.notifier).createTimetable(payload);
  }

  // --- DIALOG ---
  void _showAddSlotDialog(List<AssignmentOption> assignments) {
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No subjects available.")));
      return;
    }

    String selectedDay = "MON";
    int? selectedAssignment;
    // Default to first slot
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 30);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 25);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Class Slot"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Day"),
                    value: selectedDay,
                    items: ["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) => setState(() => selectedDay = val!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: "Subject & Faculty"),
                    isExpanded: true,
                    value: selectedAssignment,
                    items: assignments.map((a) => DropdownMenuItem(
                      value: a.id, 
                      child: Text("${a.subjectName} \n(${a.facultyName})", style: const TextStyle(fontSize: 13))
                    )).toList(),
                    onChanged: (val) => setState(() => selectedAssignment = val),
                  ),
                  const SizedBox(height: 15),
                  const Text("Quick Select (Auto-skips breaks):", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    children: [
                      _timeChip("Period 1", 9, 30, 10, 25, setState, (s,e){ startTime=s; endTime=e; }),
                      _timeChip("Period 2", 10, 25, 11, 20, setState, (s,e){ startTime=s; endTime=e; }),
                      _timeChip("Period 3", 11, 30, 12, 25, setState, (s,e){ startTime=s; endTime=e; }), // Skips Break
                      _timeChip("Period 4", 12, 25, 13, 20, setState, (s,e){ startTime=s; endTime=e; }),
                      _timeChip("Post Lunch", 14, 00, 14, 55, setState, (s,e){ startTime=s; endTime=e; }), // Skips Lunch
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: startTime);
                            if (t != null) setState(() => startTime = t);
                          },
                          child: Text("Start: ${startTime.format(context)}"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: endTime);
                            if (t != null) setState(() => endTime = t);
                          },
                          child: Text("End: ${endTime.format(context)}"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  if (selectedAssignment == null) return;
                  String formatTime(TimeOfDay t) {
                    final now = DateTime.now();
                    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
                    return DateFormat("HH:mm:ss").format(dt);
                  }
                  // ADD TO LIST
                  final Map<String, dynamic> newSlot = {
                    "day": selectedDay,
                    "assignment": selectedAssignment,
                    "start_time": formatTime(startTime),
                    "end_time": formatTime(endTime),
                  };
                  this.setState(() {
                    _slots.add(newSlot);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("Add"),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _timeChip(String label, int h1, int m1, int h2, int m2, Function setState, Function(TimeOfDay, TimeOfDay) onSelect) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      onPressed: () {
        setState(() {
          onSelect(TimeOfDay(hour: h1, minute: m1), TimeOfDay(hour: h2, minute: m2));
        });
      },
    );
  }
}