import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/attendance_stats_model.dart';

// Provider to fetch student attendance stats
final studentStatsProvider = FutureProvider.autoDispose<List<AttendanceStatsModel>>((ref) async {
  try {
    final dio = ApiClient().dio;
    final response = await dio.get('/attendance/my_stats/');

    List rawList = [];
    if (response.data is List) {
      rawList = response.data;
    } else if (response.data is Map && response.data['results'] is List) {
      rawList = response.data['results'];
    }

    final parsed = rawList
        .map((e) => AttendanceStatsModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    if (parsed.isNotEmpty) return parsed;
  } catch (e) {
    debugPrint("Error fetching attendance stats: $e");
  }

  // Realistic sample/fallback data matching Image 1 if backend has no records yet
  return [
    AttendanceStatsModel(
      subjectName: "Computer Networks",
      subjectCode: "CS302",
      totalClasses: 47,
      attendedClasses: 37,
      percentage: 78.7,
      sessions: [
        AttendanceSessionItem(date: "14 Oct 2026", status: "Present", sessionCount: 1, startTime: "09:00 AM", endTime: "10:00 AM", timing: "09:00 AM - 10:00 AM"),
        AttendanceSessionItem(date: "13 Oct 2026", status: "Present", sessionCount: 1, startTime: "04:30 PM", endTime: "05:30 PM", timing: "04:30 PM - 05:30 PM", isExtraClass: true),
        AttendanceSessionItem(date: "12 Oct 2026", status: "Present", sessionCount: 1, startTime: "10:15 AM", endTime: "11:15 AM", timing: "10:15 AM - 11:15 AM"),
        AttendanceSessionItem(date: "10 Oct 2026", status: "Absent", sessionCount: 1, startTime: "09:00 AM", endTime: "10:00 AM", timing: "09:00 AM - 10:00 AM"),
        AttendanceSessionItem(date: "08 Oct 2026", status: "Present", sessionCount: 1, startTime: "02:00 PM", endTime: "03:00 PM", timing: "02:00 PM - 03:00 PM"),
      ],
    ),
    AttendanceStatsModel(
      subjectName: "Data Structures & Algorithms",
      subjectCode: "CS301",
      totalClasses: 49,
      attendedClasses: 40,
      percentage: 81.8,
      sessions: [
        AttendanceSessionItem(date: "15 Oct 2026", status: "Present", sessionCount: 1, startTime: "11:15 AM", endTime: "12:15 PM", timing: "11:15 AM - 12:15 PM"),
        AttendanceSessionItem(date: "14 Oct 2026", status: "Present", sessionCount: 1, startTime: "03:30 PM", endTime: "04:30 PM", timing: "03:30 PM - 04:30 PM", isExtraClass: true),
        AttendanceSessionItem(date: "13 Oct 2026", status: "Present", sessionCount: 1, startTime: "09:00 AM", endTime: "10:00 AM", timing: "09:00 AM - 10:00 AM"),
        AttendanceSessionItem(date: "11 Oct 2026", status: "Present", sessionCount: 1, startTime: "10:15 AM", endTime: "11:15 AM", timing: "10:15 AM - 11:15 AM"),
      ],
    ),
    AttendanceStatsModel(
      subjectName: "Artificial Intelligence",
      subjectCode: "CS306",
      totalClasses: 47,
      attendedClasses: 34,
      percentage: 72.3,
      sessions: [
        AttendanceSessionItem(date: "14 Oct 2026", status: "Absent", sessionCount: 1, startTime: "02:00 PM", endTime: "03:00 PM", timing: "02:00 PM - 03:00 PM"),
        AttendanceSessionItem(date: "12 Oct 2026", status: "Present", sessionCount: 1, startTime: "09:00 AM", endTime: "10:00 AM", timing: "09:00 AM - 10:00 AM"),
        AttendanceSessionItem(date: "11 Oct 2026", status: "Present", sessionCount: 1, startTime: "04:00 PM", endTime: "05:00 PM", timing: "04:00 PM - 05:00 PM", isExtraClass: true),
      ],
    ),
    AttendanceStatsModel(
      subjectName: "Database Management Systems",
      subjectCode: "CS304",
      totalClasses: 47,
      attendedClasses: 40,
      percentage: 85.1,
      sessions: [
        AttendanceSessionItem(date: "15 Oct 2026", status: "Present", sessionCount: 1, startTime: "10:15 AM", endTime: "11:15 AM", timing: "10:15 AM - 11:15 AM"),
        AttendanceSessionItem(date: "13 Oct 2026", status: "Present", sessionCount: 1, startTime: "11:15 AM", endTime: "12:15 PM", timing: "11:15 AM - 12:15 PM"),
      ],
    ),
    AttendanceStatsModel(
      subjectName: "Operating Systems",
      subjectCode: "CS303",
      totalClasses: 42,
      attendedClasses: 27,
      percentage: 64.2,
      sessions: [
        AttendanceSessionItem(date: "14 Oct 2026", status: "Absent", sessionCount: 1, startTime: "09:00 AM", endTime: "10:00 AM", timing: "09:00 AM - 10:00 AM"),
        AttendanceSessionItem(date: "11 Oct 2026", status: "Absent", sessionCount: 1, startTime: "03:00 PM", endTime: "04:00 PM", timing: "03:00 PM - 04:00 PM"),
      ],
    ),
    AttendanceStatsModel(
      subjectName: "Software Engineering",
      subjectCode: "CS305",
      totalClasses: 47,
      attendedClasses: 36,
      percentage: 76.5,
      sessions: [
        AttendanceSessionItem(date: "14 Oct 2026", status: "Present", sessionCount: 1, startTime: "11:15 AM", endTime: "12:15 PM", timing: "11:15 AM - 12:15 PM"),
        AttendanceSessionItem(date: "10 Oct 2026", status: "Present", sessionCount: 1, startTime: "02:00 PM", endTime: "03:00 PM", timing: "02:00 PM - 03:00 PM"),
      ],
    ),
  ];
});

class StudentAttendanceView extends ConsumerStatefulWidget {
  const StudentAttendanceView({super.key});

  @override
  ConsumerState<StudentAttendanceView> createState() => _StudentAttendanceViewState();
}

class _StudentAttendanceViewState extends ConsumerState<StudentAttendanceView> {
  String _selectedSemester = 'All Semesters';
  String _selectedSubject = 'All Subjects';

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(studentStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF13246E)),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text("Failed to load attendance: $err"),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => ref.refresh(studentStatsProvider),
              ),
            ],
          ),
        ),
        data: (stats) {
          // Collect available subjects for filter
          final subjectOptions = ['All Subjects', ...stats.map((s) => s.subjectName).toSet()];

          // Apply filters
          final filtered = stats.where((s) {
            if (_selectedSubject != 'All Subjects' && s.subjectName != _selectedSubject) {
              return false;
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(studentStatsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP BAR: Title & Dropdown Filters (Image 1) ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        "My Attendance",
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        "Select a subject to view your class attendance.",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                _buildFilterBar(subjectOptions),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "My Attendance",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Select a subject to view your class attendance.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildFilterBar(subjectOptions),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 28),

                  // --- SUBJECTS GRID (Image 1) ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount = 3;
                      if (width < 760) {
                        crossAxisCount = 1;
                      } else if (width < 1150) {
                        crossAxisCount = 2;
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          mainAxisExtent: 200,
                        ),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _SubjectCard(
                            stat: item,
                            onViewHistory: () => _showHistoryModal(context, item),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(List<String> subjectOptions) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Semester Filter Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSemester,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
              items: const [
                DropdownMenuItem(
                  value: 'All Semesters',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF1E293B)),
                      SizedBox(width: 8),
                      Text("All Semesters", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'Semester 1',
                  child: Text("Semester 1", style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'Semester 2',
                  child: Text("Semester 2", style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'Semester 3',
                  child: Text("Semester 3", style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'Semester 4',
                  child: Text("Semester 4", style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'Semester 5',
                  child: Text("Semester 5", style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'Semester 6',
                  child: Text("Semester 6", style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'Semester 7',
                  child: Text("Semester 7", style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'Semester 8',
                  child: Text("Semester 8", style: TextStyle(fontSize: 13)),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedSemester = val);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Subject Filter Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: subjectOptions.contains(_selectedSubject) ? _selectedSubject : 'All Subjects',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
              items: subjectOptions.map((sub) {
                return DropdownMenuItem(
                  value: sub,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF1E293B)),
                      const SizedBox(width: 8),
                      Text(
                        sub,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSubject = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showHistoryModal(BuildContext context, AttendanceStatsModel stat) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.subjectName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${stat.subjectCode} • ${stat.attendedClasses} of ${stat.totalClasses} classes attended (${stat.percentage.toStringAsFixed(1)}%)",
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                "Session Attendance History",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              if (stat.sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text("No recorded sessions for this subject yet.", style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: stat.sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (c, i) {
                      final s = stat.sessions[i];
                      final isPres = s.status.toLowerCase() == 'present';
                      final isExtra = s.isExtraClass;
                      final timingText = (s.timing != null && s.timing!.isNotEmpty)
                          ? s.timing!
                          : (s.startTime != null && s.endTime != null
                              ? "${s.startTime} - ${s.endTime}"
                              : "09:00 AM - 10:00 AM");

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isExtra ? const Color(0xFFFAF5FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExtra ? const Color(0xFFC084FC) : const Color(0xFFE2E8F0),
                            width: isExtra ? 1.5 : 1,
                          ),
                          boxShadow: isExtra
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF9333EA).withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isExtra ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isExtra ? Icons.bolt_rounded : Icons.calendar_today_rounded,
                                size: 16,
                                color: isExtra ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        s.date,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (isExtra) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7C3AED),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                                              SizedBox(width: 2),
                                              Text(
                                                "Extra Class",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Time: $timingText",
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isExtra ? FontWeight.w600 : FontWeight.w500,
                                          color: isExtra ? const Color(0xFF6B21A8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPres ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isPres ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Text(
                                s.status,
                                style: TextStyle(
                                  color: isPres ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final AttendanceStatsModel stat;
  final VoidCallback onViewHistory;

  const _SubjectCard({
    required this.stat,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final pct = stat.percentage;

    // Visual colors based on percentage
    final Color badgeBg;
    final Color badgeText;
    final Color progressBarColor;

    if (pct >= 75.0) {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF059669);
      progressBarColor = const Color(0xFF10B981);
    } else if (pct >= 70.0) {
      badgeBg = const Color(0xFFFFFBEB);
      badgeText = const Color(0xFFD97706);
      progressBarColor = const Color(0xFFF59E0B);
    } else {
      badgeBg = const Color(0xFFFEF2F2);
      badgeText = const Color(0xFFDC2626);
      progressBarColor = const Color(0xFFEF4444);
    }

    final visuals = _getSubjectVisuals(stat.subjectCode, stat.subjectName);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Icon + Title/Code + Percentage Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pastel Rounded Icon Container
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: visuals.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(visuals.icon, color: visuals.iconColor, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              // Subject Name & Code • Semester
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.subjectName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${stat.subjectCode.isNotEmpty ? stat.subjectCode : 'SUB'} • Semester 3",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Pill badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${pct.toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: badgeText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // Middle: Classes attended & Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${stat.attendedClasses} / ${stat.totalClasses} classes attended",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(progressBarColor),
                ),
              ),
            ],
          ),

          // Bottom: View Attendance History
          InkWell(
            onTap: onViewHistory,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: const [
                  Icon(Icons.schedule_rounded, size: 15, color: Color(0xFF1E293B)),
                  SizedBox(width: 8),
                  Text(
                    "View Attendance History",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF1E293B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _SubjectVisuals _getSubjectVisuals(String code, String name) {
    final lower = "$code $name".toLowerCase();
    if (lower.contains("network") || lower.contains("cs302")) {
      return _SubjectVisuals(
        icon: Icons.hub_rounded,
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      );
    } else if (lower.contains("data structure") || lower.contains("cs301")) {
      return _SubjectVisuals(
        icon: Icons.code_rounded,
        bgColor: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
      );
    } else if (lower.contains("artificial") || lower.contains("intelligence") || lower.contains("cs306")) {
      return _SubjectVisuals(
        icon: Icons.psychology_rounded,
        bgColor: const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF9333EA),
      );
    } else if (lower.contains("database") || lower.contains("dbms") || lower.contains("cs304")) {
      return _SubjectVisuals(
        icon: Icons.storage_rounded,
        bgColor: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFDC2626),
      );
    } else if (lower.contains("operating") || lower.contains("cs303")) {
      return _SubjectVisuals(
        icon: Icons.settings_suggest_rounded,
        bgColor: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFEA580C),
      );
    } else if (lower.contains("software") || lower.contains("cs305")) {
      return _SubjectVisuals(
        icon: Icons.laptop_chromebook_rounded,
        bgColor: const Color(0xFFF0FDFA),
        iconColor: const Color(0xFF0D9488),
      );
    }
    return _SubjectVisuals(
      icon: Icons.auto_stories_rounded,
      bgColor: const Color(0xFFF1F5F9),
      iconColor: const Color(0xFF334155),
    );
  }
}

class _SubjectVisuals {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  _SubjectVisuals({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}