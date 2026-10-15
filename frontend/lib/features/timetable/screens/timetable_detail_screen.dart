import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';

import 'package:frontend/core/constants/api_constants.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';

final _roleProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'role');
});

class TimetableDetailScreen extends ConsumerWidget {
  final int id;
  const TimetableDetailScreen({super.key, required this.id});

  final double _rowHeight = 80.0;
  final double _headerHeight = 50.0;
  final double _baseSlotWidth = 110.0;
  final double _dayColWidth = 50.0;
  final double _breakColWidth = 40.0;
  final double _lunchColWidth = 50.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTimetable = ref.watch(timetableDetailProvider(id));
    final auth = p.Provider.of<AuthProvider>(context);
    final roleAsync = ref.watch(_roleProvider);
    final role = (auth.role ?? roleAsync.value ?? 'HOD').toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Timetable View"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          if (role == AppRoles.hod || role == AppRoles.system)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await context.push('/timetable/edit/$id');
                ref.invalidate(timetableDetailProvider(id));
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(timetableDetailProvider(id)),
          ),
        ],
      ),
      body: asyncTimetable.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (timetable) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(timetable),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildFixedTemplateGrid(timetable.slots),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildFacultySummaryTable(timetable.slots),
                ),
                const SizedBox(height: 30),
                if ((role == AppRoles.principal || role == AppRoles.hod || role == AppRoles.system) && timetable.status == 'Pending')
                  _buildActionButtons(context, ref, timetable.id),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(TimeTable tt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          Text(
            "CLASS TIME TABLE FOR ${tt.academicYearLabel}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF13246E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "${tt.departmentName} | Semester ${tt.semesterNo}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildStatusBadge(tt.status),
        ],
      ),
    );
  }

  Widget _buildFixedTemplateGrid(List<TimeTableSlot> slots) {
    final List<Map<String, dynamic>> templateColumns = [
      {"start": "09:30", "end": "10:25", "type": "CLASS"},
      {"start": "10:25", "end": "11:20", "type": "CLASS"},
      {
        "start": "11:20",
        "end": "11:30",
        "type": "BREAK",
        "label": "B\nR\nE\nA\nK",
      },
      {"start": "11:30", "end": "12:25", "type": "CLASS"},
      {"start": "12:25", "end": "13:20", "type": "CLASS"},
      {
        "start": "13:20",
        "end": "14:00",
        "type": "LUNCH",
        "label": "L\nU\nN\nC\nH",
      },
      {"start": "14:00", "end": "14:55", "type": "CLASS"},
      {"start": "14:55", "end": "15:50", "type": "CLASS"},
    ];

    double totalHeight = _headerHeight + (_rowHeight * 6);
    double totalWidth = _dayColWidth;
    for (var col in templateColumns) {
      if (col['type'] == 'BREAK')
        totalWidth += _breakColWidth;
      else if (col['type'] == 'LUNCH')
        totalWidth += _lunchColWidth;
      else
        totalWidth += _baseSlotWidth;
    }

    return SizedBox(
      height: totalHeight,
      width: totalWidth,
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeaderRow(templateColumns),
              ...["MON", "TUE", "WED", "THU", "FRI", "SAT"].asMap().entries.map(
                (e) {
                  return _buildDayRow(e.value, e.key, templateColumns, slots);
                },
              ),
            ],
          ),
          ..._buildOverlays(templateColumns, totalHeight),
        ],
      ),
    );
  }

  List<Widget> _buildOverlays(
    List<Map<String, dynamic>> columns,
    double height,
  ) {
    List<Widget> overlays = [];
    double currentX = _dayColWidth;
    for (var col in columns) {
      double width = _baseSlotWidth;
      if (col['type'] == 'BREAK') width = _breakColWidth;
      if (col['type'] == 'LUNCH') width = _lunchColWidth;
      if (col['type'] == 'BREAK' || col['type'] == 'LUNCH') {
        overlays.add(
          Positioned(
            left: currentX,
            top: _headerHeight,
            child: _buildVerticalBar(
              col['label'],
              width,
              height - _headerHeight,
              const Color(0xFFFFCC80),
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
        color: color,
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Colors.brown,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildHeaderRow(List<Map<String, dynamic>> columns) {
    return Row(
      children: [
        _buildFixedHeaderCell("TIME", width: _dayColWidth),
        ...columns.map((col) {
          double width = _baseSlotWidth;
          if (col['type'] == 'BREAK') width = _breakColWidth;
          if (col['type'] == 'LUNCH') width = _lunchColWidth;
          return _buildHeaderCell(col['start'], col['end'], width);
        }),
      ],
    );
  }

  Widget _buildDayRow(
    String day,
    int idx,
    List<Map<String, dynamic>> columns,
    List<TimeTableSlot> allSlots,
  ) {
    return Container(
      height: _rowHeight,
      color: idx % 2 == 0 ? Colors.white : Colors.grey[50],
      child: Row(
        children: [
          _buildDayCell(day),
          ..._buildRowCells(day, columns, allSlots),
        ],
      ),
    );
  }

  List<Widget> _buildRowCells(
    String day,
    List<Map<String, dynamic>> columns,
    List<TimeTableSlot> allSlots,
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

      TimeTableSlot slot;
      try {
        slot = allSlots.firstWhere(
          (s) => s.day == day && s.startTime.startsWith(col['start']),
        );
      } catch (e) {
        slot = TimeTableSlot(
          id: -1,
          day: '',
          startTime: '',
          endTime: '',
          assignmentId: 0,
        );
      }

      if (slot.id != -1) {
        double mergeWidth = 0;
        int span = 0;
        for (int k = i; k < columns.length; k++) {
          double w = _baseSlotWidth;
          if (columns[k]['type'] == 'BREAK') w = _breakColWidth;
          if (columns[k]['type'] == 'LUNCH') w = _lunchColWidth;
          mergeWidth += w;
          span++;
          if (slot.endTime.startsWith(columns[k]['end'])) break;
        }
        final cellSlots = allSlots
            .where((s) => s.day == day && s.startTime.startsWith(col['start']))
            .toList();
        cells.add(_buildClassCell(cellSlots, mergeWidth));
        i += span;
      } else {
        cells.add(_buildEmptyCell(_baseSlotWidth));
        i++;
      }
    }
    return cells;
  }

  Widget _buildClassCell(List<TimeTableSlot> slots, double width) {
    return Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: slots.length,
        itemBuilder: (context, index) {
          final s = slots[index];
          return Center(
            child: Text(
              s.subjectCode ?? "Code",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCell(double width) {
    return Container(
      width: width,
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildFixedHeaderCell(String text, {required double width}) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFCFD8DC),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildHeaderCell(String start, String end, double width) {
    return Container(
      width: width,
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(2),
      child: Text(
        "$start\nTo\n$end",
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
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
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildFacultySummaryTable(List<TimeTableSlot> slots) {
    final Map<String, Map<String, String>> summary = {};
    for (var s in slots) {
      final code = s.subjectCode ?? "Unknown";
      if (!summary.containsKey(code)) {
        summary[code] = {
          "code": code,
          "name": s.subjectName ?? "Unknown Subject",
          "faculty": s.facultyName ?? "N/A",
        };
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Course Details",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[200]),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Code",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Course Name",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Faculty",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...summary.values.map(
              (item) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      item['code']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(item['name']!),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(item['faculty']!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color c = status == 'Approved' ? Colors.green : Colors.orange;
    return Chip(
      label: Text(status.toUpperCase(), style: TextStyle(color: c)),
      backgroundColor: c.withValues(alpha: 0.1),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, int id) {
    final remarksCtrl = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () =>
                _handleAction(context, ref, id, "Rejected", remarksCtrl),
            child: const Text("REJECT"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () =>
                _handleAction(context, ref, id, "Approved", remarksCtrl),
            child: const Text("APPROVE"),
          ),
        ),
      ],
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
}
