import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../timetable/providers/timetable_provider.dart';

class FacultyAttendanceDashboard extends ConsumerStatefulWidget {
  const FacultyAttendanceDashboard({super.key});

  @override
  ConsumerState<FacultyAttendanceDashboard> createState() => _FacultyAttendanceDashboardState();
}

class _FacultyAttendanceDashboardState extends ConsumerState<FacultyAttendanceDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State to hold schedule data
  List<Map<String, dynamic>> _allSlots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final slots = await ref.read(timetableProvider.notifier).fetchMySchedule();
    if (mounted) {
      setState(() {
        _allSlots = slots;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Classes"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "TODAY'S CLASSES"),
            Tab(text: "FULL SCHEDULE"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : TabBarView(
            controller: _tabController,
            children: [
              _buildTodayView(),
              _buildWeeklyView(),
            ],
          ),
    );
  }

  // --- TAB 1: TODAY'S CLASSES ---
  Widget _buildTodayView() {
    // Get current day (MON, TUE...)
    final String todayDay = DateFormat('EEE').format(DateTime.now()).toUpperCase(); 
    
    // Filter slots for today
    final todaySlots = _allSlots.where((s) => s['day'] == todayDay).toList();

    if (todaySlots.isEmpty) {
      return _buildEmptyState("No classes scheduled for today ($todayDay).");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todaySlots.length,
      itemBuilder: (context, index) {
        return _buildClassCard(todaySlots[index], isToday: true);
      },
    );
  }

  // --- TAB 2: WEEKLY SCHEDULE ---
  Widget _buildWeeklyView() {
    if (_allSlots.isEmpty) return _buildEmptyState("No classes assigned yet.");

    final days = ["MON", "TUE", "WED", "THU", "FRI", "SAT"];
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final daySlots = _allSlots.where((s) => s['day'] == day).toList();
        
        // Sort by time
        daySlots.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time']));

        if (daySlots.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF13246E))),
                ],
              ),
            ),
            ...daySlots.map((slot) => _buildClassCard(slot, isToday: false)),
          ],
        );
      },
    );
  }

  // --- COMPONENTS ---

  Widget _buildClassCard(Map<String, dynamic> slot, {required bool isToday}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to Attendance Marking Screen
          // UPDATED: Pass subject_name as extra
          context.push(
            '/attendance/mark/${slot['id']}',
            extra: slot['subject_name'] ?? 'Class'
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Time Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatTime(slot['start_time']),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E)),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.arrow_downward, size: 12, color: Colors.grey),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(slot['end_time']),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot['subject_name'] ?? "Unknown Subject",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${slot['subject_code']} • Sem ${slot['semester']}",
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slot['branch_name'] ?? "",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Action Icon
              if (isToday)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF13246E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    if (time.length >= 5) return time.substring(0, 5);
    return time;
  }
}