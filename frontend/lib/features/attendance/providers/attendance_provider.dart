import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/attendance_model.dart';
import 'attendance_state.dart';

// 1. The Provider Definition (Family provider to pass timetableSlotId)
final attendanceProvider = StateNotifierProvider.family.autoDispose<AttendanceNotifier, AttendanceState, int>(
  (ref, slotId) => AttendanceNotifier(slotId),
);

// 2. The Notifier Logic
class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final int slotId;
  final Dio _dio = Dio(); // Replace with ref.read(apiClientProvider) if you have one

  AttendanceNotifier(this.slotId) : super(AttendanceState()) {
    fetchStudents();
  }

  // Fetch Students for the specific slot
  Future<void> fetchStudents() async {
    state = state.copyWith(status: AttendanceStatus.loading);
    try {
      // Replace with your actual Backend URL
      final response = await _dio.get(
        'http://your-api-url/api/attendance/fetch_students_for_slot/',
        queryParameters: {'slot_id': slotId},
        // options: Options(headers: {'Authorization': 'Bearer $token'}), // Add Token logic here
      );

      final List data = response.data;
      final students = data.map((e) => StudentAttendanceModel.fromJson(e)).toList();

      state = state.copyWith(status: AttendanceStatus.loaded, students: students);
    } catch (e) {
      state = state.copyWith(status: AttendanceStatus.error, errorMessage: e.toString());
    }
  }

  // Toggle Checkbox logic
  void toggleAttendance(int studentId) {
    if (state.status != AttendanceStatus.loaded) return;

    final updatedList = state.students.map((student) {
      if (student.id == studentId) {
        return student.copyWith(isPresent: !student.isPresent);
      }
      return student;
    }).toList();

    state = state.copyWith(students: updatedList);
  }

  // Submit Attendance
  Future<bool> submitAttendance() async {
    if (state.students.isEmpty) return false;
    
    state = state.copyWith(status: AttendanceStatus.submitting);

    try {
      // Prepare payload matches Backend expected format
      final records = state.students.map((s) => {
        "student_id": s.id,
        "status": s.isPresent ? "Present" : "Absent"
      }).toList();

      final date = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

      await _dio.post(
        'http://your-api-url/api/attendance/',
        data: {
          "timetable_slot": slotId,
          "date": date,
          "records": records,
        },
        // options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      state = state.copyWith(status: AttendanceStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(status: AttendanceStatus.error, errorMessage: "Submission Failed: $e");
      return false;
    }
  }
}