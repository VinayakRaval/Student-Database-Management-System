import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';
import '../../subjects/models/assign_subject_model.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignSubjectProvider.notifier).loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(assignSubjectProvider);
    final timetableState = ref.watch(timetableProvider);

    final auth = p.Provider.of<AuthProvider>(context);
    final role = (auth.role ?? '').toUpperCase();
    final isHod = role == AppRoles.hod;
    final int? userDeptId = auth.userData?['department'] is int
        ? auth.userData!['department'] as int
        : int.tryParse(auth.userData?['department']?.toString() ?? '');
    final String? userDeptName = auth.userData?['department_name']?.toString();

    // For HOD: Filter departments to ONLY show their assigned department!
    List<AssignOption> availableDepts = configState.departments;
    if (isHod && userDeptId != null) {
      final filtered = configState.departments.where((d) => d.id == userDeptId).toList();
      if (filtered.isNotEmpty) {
        availableDepts = filtered;
      } else {
        availableDepts = [AssignOption(id: userDeptId, name: userDeptName ?? "My Department")];
      }
    }

    ref.listen(timetableProvider, (prev, next) {
      if (next.isSuccess) {
        ref.invalidate(timetableListProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Timetable Created Successfully!"), backgroundColor: Colors.green));
        context.pop();
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red));
      }
    });

    // Auto-select department: For HOD, force userDeptId
    if (isHod && userDeptId != null) {
      if (_selectedDept != userDeptId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedDept != userDeptId) {
            setState(() {
              _selectedDept = userDeptId;
            });
            _fetchAssignments();
          }
        });
      }
    } else if (_selectedDept == null && availableDepts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDept == null) {
          setState(() {
            _selectedDept = availableDepts.first.id;
          });
          _fetchAssignments();
        }
      });
    }

    // Auto-select semester if available and not selected
    if (_selectedSem == null && configState.semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSem == null) {
          final sem3 = configState.semesters.firstWhere((s) => s.id == 3, orElse: () => configState.semesters.first);
          setState(() {
            _selectedSem = sem3.id;
          });
          _fetchAssignments();
        }
      });
    }

    // Auto-select academic year if available and not selected
    if (_selectedAy == null && configState.academicYears.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedAy == null) {
          setState(() {
            _selectedAy = configState.academicYears.first.id;
          });
          _fetchAssignments();
        }
      });
    }

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
            if (configState.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: LinearProgressIndicator(),
              ),

            // --- CONFIGURATION ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: isHod ? "Department (Your Assigned Department)" : "Department",
                      border: const OutlineInputBorder(),
                      prefixIcon: isHod ? const Icon(Icons.lock_outline, size: 20) : null,
                    ),
                    value: (availableDepts.any((e) => e.id == _selectedDept))
                        ? _selectedDept
                        : (availableDepts.isNotEmpty ? availableDepts.first.id : null),
                    hint: const Text("Select Department"),
                    items: availableDepts.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    onChanged: isHod
                        ? null
                        : (val) {
                            setState(() => _selectedDept = val);
                            _fetchAssignments();
                          },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: "Semester", border: OutlineInputBorder()),
                          value: (configState.semesters.any((e) => e.id == _selectedSem)) ? _selectedSem : null,
                          hint: const Text("Select Semester"),
                          items: configState.semesters.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                          onChanged: (val) { setState(() => _selectedSem = val); _fetchAssignments(); },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: "Academic Year", border: OutlineInputBorder()),
                          value: (configState.academicYears.any((e) => e.id == _selectedAy)) ? _selectedAy : null,
                          hint: const Text("Select Academic Year"),
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
    int? selectedAssignment = assignments.isNotEmpty ? assignments.first.id : null;
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
                    value: (assignments.any((a) => a.id == selectedAssignment)) ? selectedAssignment : null,
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