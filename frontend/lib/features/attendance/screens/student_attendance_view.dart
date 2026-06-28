import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/attendance_stats_model.dart';

// Simple FutureProvider for fetching stats
final studentStatsProvider = FutureProvider.autoDispose<List<AttendanceStatsModel>>((ref) async {
  final dio = Dio(); // Replace with your global API client
  // Adjust URL to your backend
  final response = await dio.get('http://your-api-url/api/attendance/my_stats/'); 
  
  return (response.data as List)
      .map((e) => AttendanceStatsModel.fromJson(e))
      .toList();
});

class StudentAttendanceView extends ConsumerWidget {
  const StudentAttendanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studentStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Attendance"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (stats) {
          if (stats.isEmpty) {
            return const Center(child: Text("No attendance records found."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              return _AttendanceStatCard(stat: stats[index]);
            },
          );
        },
      ),
    );
  }
}

class _AttendanceStatCard extends StatelessWidget {
  final AttendanceStatsModel stat;

  const _AttendanceStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    // Determine color based on percentage (Red < 75%, Green > 75%)
    final isLowAttendance = stat.percentage < 75.0;
    final color = isLowAttendance ? Colors.red : Colors.green;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        stat.subjectCode,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${stat.percentage}%",
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.percentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            
            // Text Summary
            Text(
              "Attended ${stat.attendedClasses} out of ${stat.totalClasses} classes",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}