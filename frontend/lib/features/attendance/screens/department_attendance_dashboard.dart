import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../timetable/providers/timetable_provider.dart';

class DepartmentAttendanceDashboard extends ConsumerStatefulWidget {
  const DepartmentAttendanceDashboard({super.key});

  @override
  ConsumerState<DepartmentAttendanceDashboard> createState() =>
      _DepartmentAttendanceDashboardState();
}

class _DepartmentAttendanceDashboardState
    extends ConsumerState<DepartmentAttendanceDashboard> {
  List<Map<String, dynamic>> _allSlots = [];
  List<Map<String, dynamic>> _assignedSubjects = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  String? _selectedFaculty;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchedule();
    });
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
      // For department attendance, fetch all department slots (personal: false)
      var details = await ref
          .read(timetableProvider.notifier)
          .fetchScheduleDetails(personal: false);
      var slots = (details['slots'] as List<Map<String, dynamic>>?) ?? [];
      var assigned =
          (details['assigned_subjects'] as List<Map<String, dynamic>>?) ?? [];

      // Auto-retry once after a brief delay if empty (resolves web token/storage read timing)
      if (slots.isEmpty && assigned.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          details = await ref
              .read(timetableProvider.notifier)
              .fetchScheduleDetails(personal: false);
          slots = (details['slots'] as List<Map<String, dynamic>>?) ?? [];
          assigned =
              (details['assigned_subjects'] as List<Map<String, dynamic>>?) ?? [];
        }
      }

      if (mounted) {
        setState(() {
          _allSlots = slots;
          _assignedSubjects = assigned;

          final todayDay = _todayDay;
          final todaySlots =
              slots.where((s) => s['day'] == todayDay).toList();

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
      debugPrint("Error loading department schedule: $e");
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

    // Apply faculty filter
    if (_selectedFaculty != null && _selectedFaculty!.isNotEmpty) {
      filtered = filtered
          .where((s) => (s['faculty_name'] ?? '').toString() == _selectedFaculty)
          .toList();
    }

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((slot) {
        final name = (slot['subject_name'] ?? '').toString().toLowerCase();
        final code = (slot['subject_code'] ?? '').toString().toLowerCase();
        final branch = (slot['branch_name'] ?? '').toString().toLowerCase();
        final day = (slot['day'] ?? '').toString().toLowerCase();
        final fac = (slot['faculty_name'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            code.contains(query) ||
            branch.contains(query) ||
            day.contains(query) ||
            fac.contains(query);
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
    return _allSlots.where((s) => s['day'] == day).length;
  }

  List<String> get _facultyList {
    final list = _allSlots
        .map((s) => (s['faculty_name'] ?? '').toString().trim())
        .where((f) => f.isNotEmpty && f != 'Not Assigned')
        .toSet()
        .toList();
    list.sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filteredSlots = _getFilteredSlots();
    final todayDay = _todayDay;
    final todayCount = _countForDay(todayDay);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Department Attendance",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Schedule",
            onPressed: _loadSchedule,
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
                    "Loading department classes...",
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSchedule,
              color: const Color(0xFF13246E),
              child: _allSlots.isEmpty
                  ? _buildZeroSlotsView()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- FILTER & SEARCH BAR (EXACT IMAGE 3) ---
                        _buildFilterSection(todayDay, todayCount),

                        // --- NOTICE BANNER IF TODAY HAS NO CLASSES BUT SHOWING ALL ---
                        if (_selectedFilter == 'ALL' &&
                            todayCount == 0 &&
                            _searchQuery.isEmpty)
                          _buildNoClassTodayNotice(todayDay),

                        // --- LIST OF DEPARTMENT CLASSES ---
                        Expanded(
                          child: filteredSlots.isEmpty
                              ? _buildEmptyFilteredState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: filteredSlots.length,
                                  itemBuilder: (context, index) {
                                    return _buildClassCard(filteredSlots[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }

  // --- FILTER SECTION (EXACT IMAGE 3: SEARCH, DAY PILLS, FACULTY CHIPS) ---
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
                hintText: "Search by subject name, code, or faculty...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
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

          // Faculty Filter Chips (Exact Image 3)
          if (_facultyList.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 6.0),
                    child: Icon(Icons.people_outline, size: 16, color: Colors.grey),
                  ),
                  _buildFacultyChip(
                    label: "All Faculty",
                    isSelected: _selectedFaculty == null,
                    onTap: () => setState(() => _selectedFaculty = null),
                  ),
                  ..._facultyList.map((fac) => Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: _buildFacultyChip(
                      label: fac,
                      isSelected: _selectedFaculty == fac,
                      onTap: () => setState(() =>
                          _selectedFaculty = _selectedFaculty == fac ? null : fac),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    bool highlight = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF13246E)
              : highlight
                  ? Colors.blue.shade50
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF13246E)
                : highlight
                    ? Colors.blue.shade300
                    : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : highlight
                        ? const Color(0xFF13246E)
                        : Colors.black87,
                fontWeight: isSelected || highlight
                    ? FontWeight.bold
                    : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF13246E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF13246E) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildNoClassTodayNotice(String todayDay) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "No classes scheduled specifically for today ($todayDay). Showing all department classes below:",
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> slot) {
    final slotId = slot['id'] ?? 0;
    final day = (slot['day'] ?? '').toString();
    final startTime = (slot['start_time'] ?? '').toString();
    final endTime = (slot['end_time'] ?? '').toString();
    final subjectName = (slot['subject_name'] ?? 'Class Session').toString();
    final subjectCode = (slot['subject_code'] ?? '').toString();
    final branchName = (slot['branch_name'] ?? '').toString();
    final facultyName = (slot['faculty_name'] ?? 'Not Assigned').toString();
    final sem = (slot['semester'] ?? '').toString();
    final room = (slot['room'] ?? '').toString();

    String timeLabel = '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      timeLabel = "$startTime - $endTime";
    } else if (startTime.isNotEmpty) {
      timeLabel = startTime;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Day and time pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel.isNotEmpty ? "$day • $timeLabel" : day,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (room.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Room: $room",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Subject Name
            Text(
              subjectName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // Tags row: Code, Sem, Branch
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (subjectCode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      subjectCode,
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (sem.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Text(
                      "Sem $sem",
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (branchName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      branchName,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Faculty Name
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  "Faculty: $facultyName",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Actions: View Subject, Mark/View Attendance
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text("View Subject"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF13246E),
                    side: const BorderSide(color: Color(0xFF13246E)),
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
                  icon: const Icon(Icons.how_to_reg, size: 16),
                  label: const Text("Mark Attendance"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? "No classes found matching '$_searchQuery'"
                : "No classes scheduled for the selected filter.",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'ALL';
                _selectedFaculty = null;
              });
            },
            child: const Text("Reset Filters", style: TextStyle(color: Color(0xFF13246E))),
          ),
        ],
      ),
    );
  }

  Widget _buildZeroSlotsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "No Department Timetable Published Yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Create and publish a timetable for your department to monitor attendance here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text("Create Timetable"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.push('/timetable/create'),
            ),
          ],
        ),
      ),
    );
  }
}
