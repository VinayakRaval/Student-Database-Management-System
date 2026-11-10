import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';

import 'package:frontend/core/constants/api_constants.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';
import 'student_schedule_screen.dart';

final _roleProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return storage.read(key: 'role');
});

class TimetableListScreen extends ConsumerStatefulWidget {
  final String? filterType;

  const TimetableListScreen({super.key, this.filterType});

  @override
  ConsumerState<TimetableListScreen> createState() => _TimetableListScreenState();
}

class _TimetableListScreenState extends ConsumerState<TimetableListScreen> {
  String _selectedAcademicYear = 'All AY';
  String _selectedSemester = 'All Semesters';

  final List<String> _semesterOptions = const [
    'All Semesters',
    'Odd Semesters (1, 3, 5, 7)',
    'Even Semesters (2, 4, 6, 8)',
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = p.Provider.of<AuthProvider>(context);
    final roleAsync = ref.watch(_roleProvider);
    final role = (auth.role ?? roleAsync.value ?? 'HOD').toUpperCase();

    // If authenticated user is a student, automatically display their official approved semester timetable
    if (role == AppRoles.student) {
      return const StudentScheduleScreen();
    }

    var filter = widget.filterType ?? 'all';

    if (widget.filterType == null) {
      if (role == AppRoles.principal || role == AppRoles.system) {
        filter = 'all';
      } else if (role == AppRoles.hod) {
        filter = 'hod';
      } else if (role == AppRoles.professor) {
        filter = 'faculty';
      } else if (role == AppRoles.student) {
        filter = 'student';
      } else {
        filter = 'hod';
      }
    }

    final timetableAsync = ref.watch(timetableListProvider(filter));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          role == AppRoles.student ? 'My Timetable' : 'Timetables',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh timetables',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(timetableListProvider(filter));
            },
          ),
        ],
      ),
      body: timetableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF13246E))),
        error: (error, stackTrace) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Unable to load timetables',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(timetableListProvider(filter));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (timetables) {
          final List<String> availableYears = ['All AY'];
          for (var t in timetables) {
            if (t.academicYearLabel.isNotEmpty && !availableYears.contains(t.academicYearLabel)) {
              availableYears.add(t.academicYearLabel);
            }
          }
          if (!availableYears.contains('2026-2027')) availableYears.add('2026-2027');
          if (!availableYears.contains('2025-2026')) availableYears.add('2025-2026');

          // Filter by selected academic year and semester
          final filtered = timetables.where((t) {
            if (_selectedAcademicYear != 'All AY' && t.academicYearLabel.isNotEmpty) {
              if (t.academicYearLabel != _selectedAcademicYear) return false;
            }
            if (_selectedSemester == 'Odd Semesters (1, 3, 5, 7)') {
              if (t.semesterNo % 2 == 0) return false;
            } else if (_selectedSemester == 'Even Semesters (2, 4, 6, 8)') {
              if (t.semesterNo % 2 != 0) return false;
            } else if (_selectedSemester != 'All Semesters') {
              final semNum = int.tryParse(_selectedSemester.replaceAll('Semester ', '').trim());
              if (semNum != null && t.semesterNo != semNum) return false;
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(timetableListProvider(filter));
              await ref.read(timetableListProvider(filter).future);
            },
            child: Column(
              children: [
                // Top Filter Bar with Academic Year & Semester Filters
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: Color(0xFF13246E), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                role == AppRoles.student ? "My Class Schedule" : "Department Timetables",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Text(
                            "${filtered.length} found",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Academic Year Filter
                          Expanded(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: availableYears.contains(_selectedAcademicYear) ? _selectedAcademicYear : 'All AY',
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                  items: availableYears.map((ay) {
                                    return DropdownMenuItem(
                                      value: ay,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF1E293B)),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              ay,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedAcademicYear = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Semester Dropdown Filter
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSemester,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                  items: _semesterOptions.map((sem) {
                                    return DropdownMenuItem(
                                      value: sem,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.layers_rounded, size: 13, color: Color(0xFF1E293B)),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              sem,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedSemester = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Timetables List
                Expanded(
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 56,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'No timetables found matching selected filters.',
                                style: TextStyle(color: Colors.grey, fontSize: 15),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _TimetableCard(item: filtered[index], role: role);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: (role == AppRoles.hod || role == AppRoles.system)
          ? FloatingActionButton.extended(
              heroTag: 'timetable_create_fab',
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
              onPressed: () => context.push('/timetable/create'),
            )
          : null,
    );
  }
}

class _TimetableCard extends ConsumerWidget {
  final TimeTable item;
  final String role;

  const _TimetableCard({required this.item, required this.role});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text("Delete Timetable?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete ${item.departmentName} Sem ${item.semesterNo} (${item.academicYearLabel}) v${item.version}? This cannot be undone.",
          style: const TextStyle(fontSize: 14),
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
              final success = await ref.read(timetableProvider.notifier).deleteTimetable(item.id);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Timetable deleted successfully."),
                      backgroundColor: Colors.green,
                    ),
                  );
                  ref.invalidate(timetableListProvider);
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
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = item.status.toLowerCase();

    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;

    final titleText = item.formattedTitle.isNotEmpty
        ? item.formattedTitle
        : '${TimeTable.getOrdinalSuffix(item.semesterNo)} Sem Time Table Academic Year ${item.academicYearLabel} (${item.semesterType})';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          context.push('/timetable/detail/${item.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          titleText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.departmentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF13246E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (role == AppRoles.hod || role == AppRoles.system || role == AppRoles.principal)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                          tooltip: "Delete Timetable",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDelete(context, ref),
                        ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.classTeacherName != null && item.classTeacherName!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin_rounded, size: 13, color: Color(0xFF13246E)),
                          const SizedBox(width: 4),
                          Text(
                            'Class Teacher: ${item.classTeacherName}',
                            style: const TextStyle(color: Color(0xFF13246E), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (item.effectiveDateFormatted != null || item.effectiveDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'W.E.F: ${item.effectiveDateFormatted ?? item.effectiveDate}',
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.semesterType,
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'v${item.version}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
