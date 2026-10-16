import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/attendance_stats_model.dart';

// Simple FutureProvider for fetching stats
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

    return rawList
        .map((e) => AttendanceStatsModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (e) {
    debugPrint("Error fetching attendance stats: $e");
    return [];
  }
});

class StudentAttendanceView extends ConsumerWidget {
  const StudentAttendanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studentStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text("My Attendance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Attendance",
            onPressed: () => ref.refresh(studentStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text("Error: $err"),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                onPressed: () => ref.refresh(studentStatsProvider),
              ),
            ],
          ),
        ),
        data: (stats) {
          if (stats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      "No attendance records found yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => ref.refresh(studentStatsProvider),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(studentStatsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stats.length,
              itemBuilder: (context, index) {
                return _AttendanceStatCard(stat: stats[index]);
              },
            ),
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
                    color: color.withValues(alpha: 0.1),
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