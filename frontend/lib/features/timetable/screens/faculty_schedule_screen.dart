import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timetable_provider.dart';

class FacultyScheduleScreen extends ConsumerStatefulWidget {
  const FacultyScheduleScreen({super.key});

  @override
  ConsumerState<FacultyScheduleScreen> createState() =>
      _FacultyScheduleScreenState();
}

class _FacultyScheduleScreenState extends ConsumerState<FacultyScheduleScreen> {
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _assignedSubjects = [];
  String _facultyName = '';
  bool _isLoading = true;

  int? _selectedSemester;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var data = await ref
          .read(timetableProvider.notifier)
          .fetchScheduleDetails(
            semester: _selectedSemester,
            search: _searchQuery,
            personal: true,
          );

      var slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
      var assigned = List<Map<String, dynamic>>.from(data['assigned_subjects'] ?? []);
      var facultyName = data['faculty_name']?.toString() ?? '';

      // Auto retry once if empty (handles async auth token resolution on web/refresh)
      if (slots.isEmpty && assigned.isEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          data = await ref
              .read(timetableProvider.notifier)
              .fetchScheduleDetails(
                semester: _selectedSemester,
                search: _searchQuery,
                personal: true,
              );
          slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
          assigned = List<Map<String, dynamic>>.from(data['assigned_subjects'] ?? []);
          facultyName = data['faculty_name']?.toString() ?? '';
        }
      }

      if (mounted) {
        setState(() {
          _slots = slots;
          _assignedSubjects = assigned;
          _facultyName = facultyName;
        });
      }
    } catch (e) {
      debugPrint("Error loading schedule: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSemester = null;
      _searchController.clear();
      _searchQuery = '';
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // Filter slots locally if needed
    final filteredSlots = _slots.where((slot) {
      if (_selectedSemester != null) {
        final sem = slot['semester'];
        if (sem != null && sem.toString() != _selectedSemester.toString()) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (slot['subject_name'] ?? '').toString().toLowerCase();
        final code = (slot['subject_code'] ?? '').toString().toLowerCase();
        final day = (slot['day'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !code.contains(q) && !day.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Group slots by Day
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var slot in filteredSlots) {
      final day = slot['day'] ?? 'Unknown';
      if (!grouped.containsKey(day)) grouped[day] = [];
      grouped[day]!.add(slot);
    }

    final daysOrder = ["MON", "TUE", "WED", "THU", "FRI", "SAT"];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          _facultyName.isNotEmpty
              ? "Teaching Schedule - $_facultyName"
              : "My Teaching Schedule",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Schedule",
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // --- FILTER BAR ---
            _buildFilterBar(),

            // --- MAIN CONTENT ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 1. ASSIGNED SUBJECTS CARD
                        if (_assignedSubjects.isNotEmpty)
                          _buildAssignedSubjectsCard(),

                        const SizedBox(height: 16),

                        // 2. TIMETABLE SLOTS
                        if (filteredSlots.isEmpty)
                          _buildEmptyState()
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Weekly Schedule",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                "${filteredSlots.length} classes scheduled",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...daysOrder.map((day) {
                            if (!grouped.containsKey(day)) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Day Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Color(0xFF13246E),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        day,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF13246E),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF13246E,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          "${grouped[day]!.length} classes",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF13246E),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Class Cards
                                ...grouped[day]!.map(
                                  (slot) => _buildClassCard(slot),
                                ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FILTER BAR WIDGET ---
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Search Field
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search subject, code, or day...",
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadData();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              onSubmitted: (_) => _loadData(),
            ),
          ),
          const SizedBox(width: 12),

          // Semester Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedSemester,
                  isExpanded: true,
                  hint: const Text(
                    "All Semesters",
                    style: TextStyle(fontSize: 13),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        "All Semesters",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    ...List.generate(8, (i) => i + 1).map((sem) {
                      return DropdownMenuItem<int?>(
                        value: sem,
                        child: Text(
                          "Semester $sem",
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedSemester = val);
                    _loadData();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ASSIGNED SUBJECTS CARD ---
  Widget _buildAssignedSubjectsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in, size: 18, color: Color(0xFF13246E)),
                  SizedBox(width: 8),
                  Text(
                    "My Assigned Subjects",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_assignedSubjects.length} subjects",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _assignedSubjects.map((sub) {
              final slotsCount = sub['slots_count'] ?? 0;
              final isScheduled = slotsCount > 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isScheduled
                      ? const Color(0xFFE8EAF6)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isScheduled
                        ? const Color(0xFFC5CAE9)
                        : Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sub['subject_code'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isScheduled
                                    ? const Color(0xFF13246E)
                                    : Colors.brown.shade800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sub['subject_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Sem ${sub['semester'] ?? 'N/A'}",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isScheduled
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isScheduled
                                    ? "$slotsCount classes scheduled"
                                    : "Not yet in timetable",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isScheduled
                                      ? Colors.green.shade800
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedSemester != null || _searchQuery.isNotEmpty
                  ? "No teaching slots found matching filters."
                  : "No classes currently scheduled in active timetables.",
              style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_selectedSemester != null || _searchQuery.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text("Clear Filters"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                ),
                onPressed: _clearFilters,
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Refresh Schedule"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadData,
              ),
          ],
        ),
      ),
    );
  }

  // --- CLASS CARD WIDGET ---
  Widget _buildClassCard(Map<String, dynamic> slot) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 1. TIME BOX
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    _formatTime(slot['start_time']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF13246E),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                  Text(
                    _formatTime(slot['end_time']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF13246E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // 2. SUBJECT & BRANCH DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject Name
                  Text(
                    slot['subject_name'] ?? "Unknown",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Subject Code Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      slot['subject_code'] ?? "NO CODE",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Branch & Semester
                  Row(
                    children: [
                      const Icon(Icons.school, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "${slot['branch_name'] ?? 'General'} • Sem ${slot['semester'] ?? ''}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (slot['faculty_name'] != null &&
                      slot['faculty_name'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Faculty: ${slot['faculty_name']}",
                        style: const TextStyle(
                          color: Color(0xFF13246E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null) return "--:--";
    if (time.length >= 5) return time.substring(0, 5);
    return time;
  }
}