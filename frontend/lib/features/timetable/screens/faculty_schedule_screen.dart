import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timetable_provider.dart';

class FacultyScheduleScreen extends ConsumerStatefulWidget {
  const FacultyScheduleScreen({super.key});

  @override
  ConsumerState<FacultyScheduleScreen> createState() => _FacultyScheduleScreenState();
}

class _FacultyScheduleScreenState extends ConsumerState<FacultyScheduleScreen> {
  List<Map<String, dynamic>> _slots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await ref.read(timetableProvider.notifier).fetchMySchedule();
    if (mounted) {
      setState(() {
        _slots = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group slots by Day
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var slot in _slots) {
      final day = slot['day'] ?? 'Unknown';
      if (!grouped.containsKey(day)) grouped[day] = [];
      grouped[day]!.add(slot);
    }

    // Days Order
    final daysOrder = ["MON", "TUE", "WED", "THU", "FRI", "SAT"];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Teaching Schedule"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _slots.isEmpty 
          ? const Center(child: Text("No classes assigned in active timetables."))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: daysOrder.map((day) {
                if (!grouped.containsKey(day)) return const SizedBox.shrink();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                        ],
                      ),
                    ),
                    // Class Cards
                    ...grouped[day]!.map((slot) => _buildClassCard(slot)),
                  ],
                );
              }).toList(),
            ),
    );
  }

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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E)),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                  Text(
                    _formatTime(slot['end_time']),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E)),
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
                  // Subject Name & Code
                  Text(
                    slot['subject_name'] ?? "Unknown",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withOpacity(0.5))
                    ),
                    child: Text(
                      slot['subject_code'] ?? "NO CODE",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Branch & Semester
                  Row(
                    children: [
                      const Icon(Icons.school, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "${slot['branch_name'] ?? 'General'} • Sem ${slot['semester']}",
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
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