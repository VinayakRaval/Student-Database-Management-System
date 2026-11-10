import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/timetable_model.dart';

class AddClassSlotDialog extends StatefulWidget {
  final List<AssignmentOption> availableAssignments;
  final String? initialDay;
  final Map<String, dynamic>? initialSlot;
  final Function(Map<String, dynamic> slotData) onSave;

  const AddClassSlotDialog({
    super.key,
    required this.availableAssignments,
    this.initialDay,
    this.initialSlot,
    required this.onSave,
  });

  @override
  State<AddClassSlotDialog> createState() => _AddClassSlotDialogState();
}

class _BatchDraft {
  String name;
  int? assignmentId;
  String labRoom;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool customTime;
  bool allowCoTeaching;

  _BatchDraft({
    required this.name,
    this.assignmentId,
    this.labRoom = '',
    this.startTime,
    this.endTime,
    this.customTime = false,
    this.allowCoTeaching = false,
  });
}

class _AddClassSlotDialogState extends State<AddClassSlotDialog> {
  late String _selectedDay;
  int? _selectedAssignmentId;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  // Selected periods (e.g. {1}, {2}, or paired {1, 2}, {3, 4}, {5, 6})
  final Set<int> _selectedPeriods = {1};

  String _typeFilter = 'THEORY'; // 'THEORY' or 'PRACTICAL'
  bool _isBatchWise = false;
  bool _allowCoTeaching = false;
  final List<_BatchDraft> _batches = [];

  List<AssignmentOption> get _filteredAssignments {
    if (_typeFilter == 'PRACTICAL') {
      return widget.availableAssignments.where((a) => (a.isLab || a.hasLab || a.subjectType == 'LAB' || a.subjectType == 'BOTH') && a.subjectType != 'THEORY' && a.subjectType != 'PROJECT').toList();
    } else {
      return widget.availableAssignments.where((a) => a.hasTheory && a.subjectType != 'LAB').toList();
    }
  }

  /// Strictly lab/practical assignments only, filtering out pure theory and project subjects
  List<AssignmentOption> get _labAssignments {
    return widget.availableAssignments.where((a) => (a.isLab || a.hasLab || a.subjectType == 'LAB' || a.subjectType == 'BOTH') && a.subjectType != 'THEORY' && a.subjectType != 'PROJECT').toList();
  }

  void _setTypeFilter(String type) {
    if (_typeFilter == type) return;
    setState(() {
      _typeFilter = type;
      final filtered = _filteredAssignments;
      if (filtered.any((a) => a.id == _selectedAssignmentId)) {
        // Current assignment is valid
      } else if (filtered.isNotEmpty) {
        _selectedAssignmentId = filtered.first.id;
      } else {
        _selectedAssignmentId = null;
      }

      if (_typeFilter == 'THEORY') {
        _isBatchWise = false;
        _selectedPeriods.clear();
        _selectedPeriods.add(1);
        final pData = _periods.first;
        _startTime = pData['start'] as TimeOfDay;
        _endTime = pData['end'] as TimeOfDay;
      } else {
        _isBatchWise = true;
        _selectedPeriods.clear();
        _selectedPeriods.addAll([5, 6]);
        _startTime = const TimeOfDay(hour: 14, minute: 0);
        _endTime = const TimeOfDay(hour: 16, minute: 0);
        _enableLabDefaults();
      }
    });
  }

  final List<Map<String, dynamic>> _periods = [
    {"period": 1, "label": "Period 1", "start": const TimeOfDay(hour: 9, minute: 30), "end": const TimeOfDay(hour: 10, minute: 30)},
    {"period": 2, "label": "Period 2", "start": const TimeOfDay(hour: 10, minute: 30), "end": const TimeOfDay(hour: 11, minute: 30)},
    {"period": 3, "label": "Period 3", "start": const TimeOfDay(hour: 11, minute: 30), "end": const TimeOfDay(hour: 12, minute: 30)},
    {"period": 4, "label": "Period 4", "start": const TimeOfDay(hour: 12, minute: 30), "end": const TimeOfDay(hour: 13, minute: 30)},
    {"period": 5, "label": "Period 5", "start": const TimeOfDay(hour: 14, minute: 0), "end": const TimeOfDay(hour: 15, minute: 0)},
    {"period": 6, "label": "Period 6", "start": const TimeOfDay(hour: 15, minute: 0), "end": const TimeOfDay(hour: 16, minute: 0)},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay ?? widget.initialSlot?['day'] ?? "MON";

    // Determine initial type filter based on slot data if editing
    if (widget.initialSlot?['is_batch_wise'] == true || (widget.initialSlot?['batches'] is List && (widget.initialSlot!['batches'] as List).isNotEmpty)) {
      _typeFilter = 'PRACTICAL';
    } else if (widget.initialSlot?['assignment'] != null) {
      final assignId = widget.initialSlot!['assignment'] is int
          ? widget.initialSlot!['assignment']
          : int.tryParse(widget.initialSlot!['assignment'].toString());
      final opt = widget.availableAssignments.where((a) => a.id == assignId).firstOrNull;
      if (opt != null && opt.isLab && !opt.hasTheory) {
        _typeFilter = 'PRACTICAL';
      }
    }

    // Set default or initial assignment matching _typeFilter
    if (widget.initialSlot?['assignment'] != null) {
      _selectedAssignmentId = widget.initialSlot!['assignment'] is int
          ? widget.initialSlot!['assignment']
          : int.tryParse(widget.initialSlot!['assignment'].toString());
    } else {
      final filtered = _filteredAssignments;
      if (filtered.isNotEmpty) {
        _selectedAssignmentId = filtered.first.id;
      } else if (widget.availableAssignments.isNotEmpty) {
        _selectedAssignmentId = widget.availableAssignments.first.id;
      }
    }

    // Set default times
    if (widget.initialSlot?['start_time'] != null && widget.initialSlot?['end_time'] != null) {
      _startTime = _parseTimeOfDay(widget.initialSlot!['start_time'].toString());
      _endTime = _parseTimeOfDay(widget.initialSlot!['end_time'].toString());
      _matchPeriodsToTimes(_startTime, _endTime);
    } else {
      _startTime = const TimeOfDay(hour: 9, minute: 30);
      _endTime = const TimeOfDay(hour: 10, minute: 30);
      _selectedPeriods.clear();
      _selectedPeriods.add(1);
    }

    // Initialize batches if existing or requested
    if (widget.initialSlot?['is_batch_wise'] == true || (widget.initialSlot?['batches'] is List && (widget.initialSlot!['batches'] as List).isNotEmpty)) {
      _isBatchWise = true;
      _allowCoTeaching = widget.initialSlot?['allow_co_teaching'] == true;
      final rawBatches = widget.initialSlot!['batches'] as List? ?? [];
      for (var b in rawBatches) {
        final bMap = Map<String, dynamic>.from(b as Map);
        _batches.add(_BatchDraft(
          name: bMap['batch_name']?.toString() ?? 'B${_batches.length + 1}',
          assignmentId: bMap['assignment'] is int ? bMap['assignment'] : int.tryParse(bMap['assignment']?.toString() ?? ''),
          labRoom: bMap['lab_room']?.toString() ?? '',
          startTime: bMap['start_time'] != null ? _parseTimeOfDay(bMap['start_time'].toString()) : null,
          endTime: bMap['end_time'] != null ? _parseTimeOfDay(bMap['end_time'].toString()) : null,
          customTime: bMap['start_time'] != null && bMap['start_time'].toString().isNotEmpty,
          allowCoTeaching: bMap['allow_co_teaching'] == true,
        ));
      }
    }
  }

  void _matchPeriodsToTimes(TimeOfDay start, TimeOfDay end) {
    _selectedPeriods.clear();
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    // Check for pairs
    if (startMin == 9 * 60 + 30 && endMin == 11 * 60 + 30) {
      _selectedPeriods.addAll([1, 2]);
    } else if (startMin == 11 * 60 + 30 && endMin == 13 * 60 + 30) {
      _selectedPeriods.addAll([3, 4]);
    } else if (startMin == 14 * 60 && endMin == 16 * 60) {
      _selectedPeriods.addAll([5, 6]);
    } else {
      // Single period match
      for (var p in _periods) {
        final ps = (p['start'] as TimeOfDay).hour * 60 + (p['start'] as TimeOfDay).minute;
        final pe = (p['end'] as TimeOfDay).hour * 60 + (p['end'] as TimeOfDay).minute;
        if (startMin == ps && endMin == pe) {
          _selectedPeriods.add(p['period'] as int);
          break;
        }
      }
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 30);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat("hh:mm a").format(dt);
  }

  String _formatTime24(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat("HH:mm:ss").format(dt);
  }

  AssignmentOption? get _currentAssignment {
    if (_selectedAssignmentId == null || widget.availableAssignments.isEmpty) return null;
    return widget.availableAssignments.firstWhere(
      (a) => a.id == _selectedAssignmentId,
      orElse: () => widget.availableAssignments.first,
    );
  }

  bool get _isCurrentLabSubject {
    return _typeFilter == 'PRACTICAL' && (_currentAssignment?.isLab ?? false);
  }

  bool get _shouldShowBatchSection {
    return _typeFilter == 'PRACTICAL' || _isCurrentLabSubject;
  }

  void _onPeriodTapped(int periodNum) {
    setState(() {
      // In Theory mode, strictly allow only a single period to be selected at a time
      _selectedPeriods.clear();
      _selectedPeriods.add(periodNum);
      _applySelectedPeriodsTimes();
    });
  }

  void _onPairSelected(int p1, int p2) {
    setState(() {
      _selectedPeriods.clear();
      _selectedPeriods.addAll([p1, p2]);
      _applySelectedPeriodsTimes();
    });
  }

  void _applySelectedPeriodsTimes() {
    if (_selectedPeriods.contains(1) && _selectedPeriods.contains(2)) {
      _startTime = const TimeOfDay(hour: 9, minute: 30);
      _endTime = const TimeOfDay(hour: 11, minute: 30);
      _enableLabDefaults();
    } else if (_selectedPeriods.contains(3) && _selectedPeriods.contains(4)) {
      _startTime = const TimeOfDay(hour: 11, minute: 30);
      _endTime = const TimeOfDay(hour: 13, minute: 30);
      _enableLabDefaults();
    } else if (_selectedPeriods.contains(5) && _selectedPeriods.contains(6)) {
      _startTime = const TimeOfDay(hour: 14, minute: 0);
      _endTime = const TimeOfDay(hour: 16, minute: 0);
      _enableLabDefaults();
    } else if (_selectedPeriods.isNotEmpty) {
      final pNum = _selectedPeriods.first;
      final pData = _periods.firstWhere((p) => p['period'] == pNum);
      _startTime = pData['start'] as TimeOfDay;
      _endTime = pData['end'] as TimeOfDay;

      // If switching back to single period and subject is not lab, turn off batches
      if (!_isCurrentLabSubject) {
        _isBatchWise = false;
      }
    }
  }

  void _enableLabDefaults() {
    _isBatchWise = true;
    final defaultLabId = _labAssignments.isNotEmpty
        ? (_labAssignments.any((a) => a.id == _selectedAssignmentId)
            ? _selectedAssignmentId
            : _labAssignments.first.id)
        : _selectedAssignmentId;
    if (_batches.isEmpty) {
      _batches.addAll([
        _BatchDraft(name: "B1", assignmentId: defaultLabId, labRoom: "Lab 1"),
        _BatchDraft(name: "B2", assignmentId: defaultLabId, labRoom: "Lab 2"),
      ]);
    }
  }

  void _addBatch() {
    setState(() {
      int nextNum = _batches.length + 1;
      while (_batches.any((b) => b.name.trim().toUpperCase() == "B$nextNum")) {
        nextNum++;
      }
      final defaultLabId = _labAssignments.isNotEmpty
          ? (_labAssignments.any((a) => a.id == _selectedAssignmentId)
              ? _selectedAssignmentId
              : _labAssignments.first.id)
          : _selectedAssignmentId;
      _batches.add(_BatchDraft(
        name: "B$nextNum",
        assignmentId: defaultLabId,
        labRoom: "",
        allowCoTeaching: _allowCoTeaching,
      ));
    });
  }



  void _onSaveSlot() {
    if (!_isBatchWise && _selectedAssignmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Subject & Faculty.")),
      );
      return;
    }

    // Time validation (End time must be after Start time)
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    if (startMin >= endMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Start time must be before End time.")),
      );
      return;
    }

    final actualBatchWise = _shouldShowBatchSection && _isBatchWise;

    if (actualBatchWise) {
      if (_batches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add at least one batch or uncheck Batch-wise Lab Scheduling.")),
        );
        return;
      }

      final seenNames = <String>{};
      for (var b in _batches) {
        final bName = b.name.trim();
        if (bName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please provide a name for all batches.")),
          );
          return;
        }
        final lower = bName.toLowerCase();
        if (seenNames.contains(lower)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Duplicate batch name '$bName'. Each batch must have a unique name.")),
          );
          return;
        }
        seenNames.add(lower);

        if (b.assignmentId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Please select a Subject & Faculty for Batch ${b.name}.")),
          );
          return;
        }
        if (b.customTime && b.startTime != null && b.endTime != null) {
          final bStart = b.startTime!.hour * 60 + b.startTime!.minute;
          final bEnd = b.endTime!.hour * 60 + b.endTime!.minute;
          if (bStart >= bEnd) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Start time must be before End time for Batch ${b.name}.")),
            );
            return;
          }
        }
      }

      // Check simultaneous multi-batch conflicts locally for quick feedback
      if (!_allowCoTeaching && _batches.length > 1) {
        for (int i = 0; i < _batches.length; i++) {
          for (int j = i + 1; j < _batches.length; j++) {
            final b1 = _batches[i];
            final b2 = _batches[j];
            if (b1.assignmentId == b2.assignmentId && b1.assignmentId != null) {
              final a1Start = b1.customTime && b1.startTime != null ? b1.startTime! : _startTime;
              final a1End = b1.customTime && b1.endTime != null ? b1.endTime! : _endTime;
              final a2Start = b2.customTime && b2.startTime != null ? b2.startTime! : _startTime;
              final a2End = b2.customTime && b2.endTime != null ? b2.endTime! : _endTime;

              final a1s = a1Start.hour * 60 + a1Start.minute;
              final a1e = a1End.hour * 60 + a1End.minute;
              final a2s = a2Start.hour * 60 + a2Start.minute;
              final a2e = a2End.hour * 60 + a2End.minute;

              if (a1s < a2e && a1e > a2s && !b1.allowCoTeaching && !b2.allowCoTeaching) {
                final assign = widget.availableAssignments.firstWhere((a) => a.id == b1.assignmentId);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Simultaneous Faculty Conflict"),
                    content: Text(
                      "${assign.facultyName} is assigned to both Batch ${b1.name} and Batch ${b2.name} at overlapping times.\n\n"
                      "To permit the same faculty to teach multiple simultaneous batches, enable 'Permit Co-teaching / Simultaneous Supervision'.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                        onPressed: () {
                          setState(() {
                            _allowCoTeaching = true;
                            for (var b in _batches) {
                              b.allowCoTeaching = true;
                            }
                          });
                          Navigator.pop(ctx);
                          _onSaveSlot();
                        },
                        child: const Text("Enable Co-teaching & Save"),
                      )
                    ],
                  ),
                );
                return;
              }
            }
          }
        }
      }
    }

    final Map<String, dynamic> slotData = {
      "day": _selectedDay,
      "start_time": _formatTime24(_startTime),
      "end_time": _formatTime24(_endTime),
      "assignment": actualBatchWise ? (_batches.first.assignmentId ?? _selectedAssignmentId) : _selectedAssignmentId,
      "is_batch_wise": actualBatchWise,
      "allow_co_teaching": _allowCoTeaching,
    };

    if (actualBatchWise) {
      slotData["batches"] = _batches.map((b) => {
        "batch_name": b.name,
        "assignment": b.assignmentId,
        "lab_room": b.labRoom,
        "start_time": b.customTime && b.startTime != null ? _formatTime24(b.startTime!) : _formatTime24(_startTime),
        "end_time": b.customTime && b.endTime != null ? _formatTime24(b.endTime!) : _formatTime24(_endTime),
        "allow_co_teaching": b.allowCoTeaching || _allowCoTeaching,
      }).toList();
    }

    widget.onSave(slotData);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final showBatchSection = _shouldShowBatchSection;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 750),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER MATCHING IMAGE 1 ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: Color(0xFF1A73E8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "Add Class Slot",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    splashRadius: 20,
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- DAY * DROPDOWN ---
              RichText(
                text: const TextSpan(
                  text: "Day ",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  children: [TextSpan(text: "*", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedDay,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                items: ["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((d) {
                  return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontWeight: FontWeight.w500)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDay = val);
                },
              ),
              const SizedBox(height: 16),

              // --- CLASS TYPE FILTER BUTTONS (THEORY & PRACTICAL) ---
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _setTypeFilter('THEORY'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _typeFilter == 'THEORY' ? const Color(0xFF13246E) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _typeFilter == 'THEORY' ? const Color(0xFF13246E) : const Color(0xFFCBD5E1),
                            width: _typeFilter == 'THEORY' ? 2 : 1,
                          ),
                          boxShadow: _typeFilter == 'THEORY'
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF13246E).withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 18,
                              color: _typeFilter == 'THEORY' ? Colors.white : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Theory",
                              style: TextStyle(
                                color: _typeFilter == 'THEORY' ? Colors.white : const Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _setTypeFilter('PRACTICAL'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _typeFilter == 'PRACTICAL' ? const Color(0xFF13246E) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _typeFilter == 'PRACTICAL' ? const Color(0xFF13246E) : const Color(0xFFCBD5E1),
                            width: _typeFilter == 'PRACTICAL' ? 2 : 1,
                          ),
                          boxShadow: _typeFilter == 'PRACTICAL'
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF13246E).withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.biotech_rounded,
                              size: 18,
                              color: _typeFilter == 'PRACTICAL' ? Colors.white : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Practical",
                              style: TextStyle(
                                color: _typeFilter == 'PRACTICAL' ? Colors.white : const Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- SUBJECT & FACULTY * DROPDOWN (ONLY FOR THEORY; PRACTICAL SELECTS PER BATCH) ---
              if (_typeFilter != 'PRACTICAL') ...[
                RichText(
                  text: const TextSpan(
                    text: "Theory Subject & Faculty ",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    children: [TextSpan(text: "*", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final filtered = _filteredAssignments;
                    if (filtered.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.grey.shade600, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "No theory subjects found.",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final effectiveValue = filtered.any((a) => a.id == _selectedAssignmentId)
                        ? _selectedAssignmentId
                        : filtered.first.id;

                    return DropdownButtonFormField<int>(
                      value: effectiveValue,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      items: filtered.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            "${a.subjectName} 📖 (Theory) • ${a.facultyDisplay}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAssignmentId = val;
                          _isBatchWise = false;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // --- QUICK SELECT PERIODS (PERIOD 1 TO 6 FOR THEORY, 2-PERIOD LAB BLOCKS FOR LAB) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _typeFilter == 'PRACTICAL'
                        ? "Select 2-Period Lab Session:"
                        : "Quick Select Period (Auto-skips breaks):",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  if (_typeFilter == 'PRACTICAL')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "🧪 Lab Mode Active",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // When Theory subject is selected -> Individual Period Pills (Period 1 to 6)
              // When Lab subject is selected -> Theory individual periods are hidden, Lab Blocks are shown
              if (_typeFilter != 'PRACTICAL') ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periods.map((p) {
                      final pNum = p['period'] as int;
                      final isSelected = _selectedPeriods.contains(pNum);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: InkWell(
                          onTap: () => _onPeriodTapped(pNum),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF13246E) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF13246E) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              p['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                // Lab: Consecutive 2-Period Lab Blocks (1+2, 3+4, 5+6)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPairChip("Period 1 + 2 (Lab)", 1, 2),
                      const SizedBox(width: 8),
                      _buildPairChip("Period 3 + 4 (Lab)", 3, 4),
                      const SizedBox(width: 8),
                      _buildPairChip("Period 5 + 6 (Lab)", 5, 6),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // --- SIDE-BY-SIDE START & END TIME DROPDOWNS (12-HOUR FORMAT) ---
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            text: "Start: ",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            children: [TextSpan(text: "*", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: _startTime);
                            if (t != null) {
                              setState(() {
                                _startTime = t;
                                _selectedPeriods.clear();
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF1E293B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatTimeOfDay(_startTime),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            text: "End: ",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            children: [TextSpan(text: "*", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: _endTime);
                            if (t != null) {
                              setState(() {
                                _endTime = t;
                                _selectedPeriods.clear();
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF1E293B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatTimeOfDay(_endTime),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- BATCH-WISE LAB TIMETABLE CONFIGURATION (IMAGE 3 DESIGN) ---
              // Automatically hidden if Theory subject, shown only for Lab subjects or 2-period lab blocks
              if (showBatchSection) ...[
                // Card 1: Schedule as Batches (B1, B2...) (Optional)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _isBatchWise,
                        activeColor: const Color(0xFF13246E),
                        onChanged: (val) {
                          setState(() {
                            _isBatchWise = val ?? false;
                            if (_isBatchWise && _batches.isEmpty) {
                              _batches.addAll([
                                _BatchDraft(name: "B1", assignmentId: _selectedAssignmentId, labRoom: "Lab 1"),
                                _BatchDraft(name: "B2", assignmentId: _selectedAssignmentId, labRoom: "Lab 2"),
                              ]);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Schedule as Batches (B1, B2...) (Optional)",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Assign distinct practical subjects, rooms, and faculty per batch",
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card 2: Permit Co-teaching / Simultaneous Multi-batch Supervision
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _allowCoTeaching,
                        activeColor: const Color(0xFF13246E),
                        onChanged: (val) {
                          setState(() {
                            _allowCoTeaching = val ?? false;
                            for (var b in _batches) {
                              b.allowCoTeaching = _allowCoTeaching;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Permit Co-teaching / Simultaneous Multi-batch Supervision",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Section 3: Lab Batches List (Exact Image 3 Layout)
                if (_isBatchWise) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row with Outlined "+ Add Batch" on right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Lab batches (optional)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Add and manage lab batches for this class.",
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                "Add Batch",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF13246E),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _addBatch,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Batch Cards matching Image 3
                        ..._batches.asMap().entries.map((entry) {
                          final bIdx = entry.key;
                          final batch = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row 1: B1 Badge, Batch Name input, Red Trash Button
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF13246E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        batch.name.isNotEmpty ? batch.name : "B${bIdx + 1}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: batch.name,
                                        decoration: const InputDecoration(
                                          labelText: "Batch Name",
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                        onChanged: (v) {
                                          batch.name = v.trim();
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    InkWell(
                                      onTap: _batches.length > 1
                                          ? () => setState(() => _batches.removeAt(bIdx))
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFEE2E2)),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Row 2: Practical Subject & Faculty (Full Width, Room Allotment removed)
                                DropdownButtonFormField<int>(
                                  value: (_labAssignments.any((a) => a.id == batch.assignmentId))
                                      ? batch.assignmentId
                                      : (_labAssignments.isNotEmpty ? _labAssignments.first.id : null),
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: "Practical Subject & Faculty",
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  items: _labAssignments.map((a) {
                                    return DropdownMenuItem(
                                      value: a.id,
                                      child: Text(
                                        "${a.subjectName} (${a.facultyDisplay})",
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => batch.assignmentId = val),
                                ),
                                const SizedBox(height: 8),

                                // Row 3: Custom Time Checkbox
                                Row(
                                  children: [
                                    Checkbox(
                                      value: batch.customTime,
                                      activeColor: const Color(0xFF13246E),
                                      onChanged: (val) {
                                        setState(() {
                                          batch.customTime = val ?? false;
                                          if (batch.customTime) {
                                            batch.startTime ??= _startTime;
                                            batch.endTime ??= _endTime;
                                          }
                                        });
                                      },
                                    ),
                                    const Text("Custom Time", style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                  ],
                                ),
                                if (batch.customTime) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          onPressed: () async {
                                            final t = await showTimePicker(context: context, initialTime: batch.startTime ?? _startTime);
                                            if (t != null) setState(() => batch.startTime = t);
                                          },
                                          child: Text(
                                            "Start: ${_formatTimeOfDay(batch.startTime ?? _startTime)}",
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          onPressed: () async {
                                            final t = await showTimePicker(context: context, initialTime: batch.endTime ?? _endTime);
                                            if (t != null) setState(() => batch.endTime = t);
                                          },
                                          child: Text(
                                            "End: ${_formatTimeOfDay(batch.endTime ?? _endTime)}",
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // --- BOTTOM ACTIONS MATCHING IMAGE 1 ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF13246E),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _onSaveSlot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPairChip(String label, int p1, int p2) {
    final isSelected = _selectedPeriods.contains(p1) && _selectedPeriods.contains(p2);
    return InkWell(
      onTap: () => _onPairSelected(p1, p2),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_rounded,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
