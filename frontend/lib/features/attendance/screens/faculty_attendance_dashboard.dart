import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../timetable/providers/timetable_provider.dart';

class FacultyAttendanceDashboard extends ConsumerStatefulWidget {
  const FacultyAttendanceDashboard({super.key});

  @override
  ConsumerState<FacultyAttendanceDashboard> createState() =>
      _FacultyAttendanceDashboardState();
}

class _FacultyAttendanceDashboardState
    extends ConsumerState<FacultyAttendanceDashboard> {
  List<Map<String, dynamic>> _allSlots = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _weekDays = const [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _todayDay =>
      DateFormat('EEE').format(DateTime.now()).toUpperCase();

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    try {
      final slots =
          await ref.read(timetableProvider.notifier).fetchMySchedule();
      if (mounted) {
        setState(() {
          _allSlots = slots;

          final todayDay = _todayDay;
          final todaySlots =
              slots.where((s) => s['day'] == todayDay).toList();

          // Auto-select TODAY if classes exist today; otherwise default to ALL
          if (_selectedFilter == 'ALL' || _selectedFilter == 'TODAY') {
            if (todaySlots.isNotEmpty) {
              _selectedFilter = 'TODAY';
            } else {
              _selectedFilter = 'ALL';
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading faculty schedule: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredSlots() {
    List<Map<String, dynamic>> filtered;

    if (_selectedFilter == 'TODAY') {
      final today = _todayDay;
      filtered = _allSlots.where((s) => s['day'] == today).toList();
    } else if (_selectedFilter == 'ALL') {
      filtered = List.from(_allSlots);
    } else {
      filtered = _allSlots.where((s) => s['day'] == _selectedFilter).toList();
    }

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((slot) {
        final name = (slot['subject_name'] ?? '').toString().toLowerCase();
        final code = (slot['subject_code'] ?? '').toString().toLowerCase();
        final branch = (slot['branch_name'] ?? '').toString().toLowerCase();
        final day = (slot['day'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            code.contains(query) ||
            branch.contains(query) ||
            day.contains(query);
      }).toList();
    }

    // Sort by day order then start_time
    filtered.sort((a, b) {
      final dayA = _weekDays.indexOf((a['day'] ?? '').toString().toUpperCase());
      final dayB = _weekDays.indexOf((b['day'] ?? '').toString().toUpperCase());
      if (dayA != dayB) {
        return (dayA == -1 ? 99 : dayA).compareTo(dayB == -1 ? 99 : dayB);
      }
      final timeA = (a['start_time'] ?? '').toString();
      final timeB = (b['start_time'] ?? '').toString();
      return timeA.compareTo(timeB);
    });

    return filtered;
  }

  int _countForDay(String day) {
    return _allSlots
        .where((s) => (s['day'] ?? '').toString().toUpperCase() == day)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final todayDay = _todayDay;
    final todayCount = _countForDay(todayDay);
    final filteredSlots = _getFilteredSlots();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Mark Attendance",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: "Refresh Schedule",
            onPressed: _isLoading ? null : _loadSchedule,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF13246E)),
                  SizedBox(height: 16),
                  Text(
                    "Loading your scheduled classes...",
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSchedule,
              color: const Color(0xFF13246E),
              child: _allSlots.isEmpty
                  ? _buildZeroSlotsAssignedView()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- FILTER & SEARCH BAR ---
                        _buildFilterSection(todayDay, todayCount),

                        // --- NOTICE BANNER IF TODAY HAS NO CLASSES BUT SHOWING ALL ---
                        if (_selectedFilter == 'ALL' &&
                            todayCount == 0 &&
                            _searchQuery.isEmpty)
                          _buildNoClassTodayNotice(todayDay),

                        // --- LIST OF CLASSES ---
                        Expanded(
                          child: filteredSlots.isEmpty
                              ? _buildEmptyFilteredState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 24),
                                  itemCount: filteredSlots.length,
                                  itemBuilder: (context, index) {
                                    return _buildClassCard(
                                      filteredSlots[index],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }

  // --- FILTER SECTION (DAY PILLS + SEARCH) ---
  Widget _buildFilterSection(String todayDay, int todayCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Search box
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by subject name or code...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF13246E)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 10),

          // Day Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: "ALL",
                  count: _allSlots.length,
                  isSelected: _selectedFilter == 'ALL',
                  onTap: () => setState(() => _selectedFilter = 'ALL'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "TODAY ($todayDay)",
                  count: todayCount,
                  isSelected: _selectedFilter == 'TODAY',
                  highlight: todayCount > 0,
                  onTap: () => setState(() => _selectedFilter = 'TODAY'),
                ),
                const SizedBox(width: 8),
                ..._weekDays.map((day) {
                  final count = _countForDay(day);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildFilterChip(
                      label: day,
                      count: count,
                      isSelected: _selectedFilter == day,
                      onTap: () => setState(() => _selectedFilter = day),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final bg = isSelected
        ? const Color(0xFF13246E)
        : (highlight ? Colors.amber.shade50 : Colors.white);
    final textColor = isSelected
        ? Colors.white
        : (highlight ? const Color(0xFF13246E) : Colors.grey[800]!);
    final borderColor = isSelected
        ? const Color(0xFF13246E)
        : (highlight ? Colors.amber.shade400 : Colors.grey.shade300);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF13246E).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (highlight
                        ? Colors.amber.shade200
                        : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NOTICE BANNER ---
  Widget _buildNoClassTodayNotice(String todayDay) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC5CAE9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFF13246E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "No classes scheduled specifically for today ($todayDay). Showing all your classes below so you can mark attendance for any session:",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF13246E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CLASS CARD ---
  Widget _buildClassCard(Map<String, dynamic> slot) {
    final day = (slot['day'] ?? '').toString().toUpperCase();
    final isToday = day == _todayDay;
    final slotId = slot['id'];
    final subjectName = slot['subject_name'] ?? 'Class';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday ? const Color(0xFF13246E).withValues(alpha: 0.4) : Colors.grey.shade200,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          context.push(
            '/attendance/mark/$slotId',
            extra: subjectName,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Day & Time + Status Tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time & Day Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF13246E)
                          : const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isToday ? Colors.white : const Color(0xFF13246E),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$day • ${_formatTime(slot['start_time'])} - ${_formatTime(slot['end_time'])}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isToday
                                ? Colors.white
                                : const Color(0xFF13246E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Today",
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Subject Title
              Text(
                subjectName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),

              // Tags: Subject Code, Semester, Branch
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (slot['subject_code'] != null &&
                      slot['subject_code'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        slot['subject_code'].toString(),
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (slot['semester'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        "Sem ${slot['semester']}",
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (slot['branch_name'] != null &&
                      slot['branch_name'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        slot['branch_name'].toString(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),

              if (slot['faculty_name'] != null &&
                  slot['faculty_name'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "Faculty: ${slot['faculty_name']}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text("View Subject"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF13246E),
                      side: const BorderSide(color: Color(0xFF13246E)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      context.push('/subjects');
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                    label: const Text("Mark Attendance"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      context.push(
                        '/attendance/mark/$slotId',
                        extra: subjectName,
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

  // --- EMPTY STATE WHEN FILTER RETURNS NOTHING ---
  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? "No classes found matching '$_searchQuery'"
                  : (_selectedFilter == 'TODAY'
                      ? "No classes scheduled for today ($_todayDay)"
                      : "No classes scheduled for $_selectedFilter"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try clearing your search query or switching day filters."
                  : "You have ${_allSlots.length} scheduled class${_allSlots.length == 1 ? '' : 'es'} across other days.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.view_week_rounded, size: 16),
              label: const Text("View All Classes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedFilter = 'ALL';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- ZERO SLOTS VIEW (TRUE EMPTY TIMETABLE) ---
  Widget _buildZeroSlotsAssignedView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32.0),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "No Assigned Timetable Slots",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "There are no active timetable classes assigned to your faculty profile.\nAssigned classes will appear here once approved by the HOD or Coordinator.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Check Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _loadSchedule,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return "--:--";
    final str = time.toString();
    if (str.length >= 5) {
      final parts = str.substring(0, 5).split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = parts[1];
        if (hour != null) {
          final period = hour >= 12 ? 'PM' : 'AM';
          final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          return '$h12:$minute $period';
        }
      }
      return str.substring(0, 5);
    }
    return str;
  }
}