import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/attendance_provider.dart';
import '../providers/attendance_state.dart';
import '../widgets/student_attendance_card.dart';

class MarkAttendanceScreen extends ConsumerWidget {
  final int timetableSlotId;
  final String? subjectName; // Passed via route extra for better UX

  const MarkAttendanceScreen({
    super.key,
    required this.timetableSlotId,
    this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the specific provider family instance
    final state = ref.watch(attendanceProvider(timetableSlotId));
    final notifier = ref.read(attendanceProvider(timetableSlotId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Mark Attendance", style: TextStyle(fontSize: 16)),
            Text(subjectName ?? "Class", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          // Summary Chip in AppBar
          if (state.status == AttendanceStatus.loaded)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  "${state.presentCount}/${state.total}", 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            )
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.status == AttendanceStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state.status == AttendanceStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 10),
                  Text("Error: ${state.errorMessage}"),
                  ElevatedButton(
                    onPressed: () => notifier.fetchStudents(),
                    child: const Text("Retry"),
                  )
                ],
              ),
            );
          }

          if (state.students.isEmpty) {
            return const Center(child: Text("No students found for this class."));
          }

          return Column(
            children: [
              // Stats Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("Total", "${state.total}", Colors.black),
                    _buildStatItem("Present", "${state.presentCount}", Colors.green),
                    _buildStatItem("Absent", "${state.absentCount}", Colors.red),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Student List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Space for FAB/Button
                  itemCount: state.students.length,
                  itemBuilder: (context, index) {
                    final student = state.students[index];
                    return StudentAttendanceCard(
                      student: student,
                      onToggle: () => notifier.toggleAttendance(student.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: (state.status == AttendanceStatus.submitting || state.status == AttendanceStatus.loading)
              ? null
              : () async {
                  final success = await notifier.submitAttendance();
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Attendance Submitted Successfully!")),
                      );
                      context.pop(); // Go back
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(state.errorMessage ?? "Submission failed")),
                      );
                    }
                  }
                },
          child: state.status == AttendanceStatus.submitting
              ? const SizedBox(
                  height: 20, 
                  width: 20, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              : const Text("SUBMIT ATTENDANCE", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}