import 'package:flutter_riverpod/legacy.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/attendance_model.dart';
import 'attendance_state.dart';

// 1. The Provider Definition (Family provider to pass timetableSlotId)
final attendanceProvider = StateNotifierProvider.family.autoDispose<AttendanceNotifier, AttendanceState, int>(
  (ref, slotId) => AttendanceNotifier(slotId),
);

// 2. The Notifier Logic
class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final int slotId;
  final Dio _dio = ApiClient().dio;

  AttendanceNotifier(this.slotId) : super(AttendanceState()) {
    fetchStudents();
  }

  // Fetch Students for the specific slot
  Future<void> fetchStudents() async {
    state = state.copyWith(status: AttendanceStatus.loading);
    try {
      final response = await _dio.get(
        '/attendance/fetch_students_for_slot/',
        queryParameters: {'slot_id': slotId},
      );

      List rawList = [];
      if (response.data is List) {
        rawList = response.data;
      } else if (response.data is Map && response.data['results'] is List) {
        rawList = response.data['results'];
      }
      final students = rawList.map((e) => StudentAttendanceModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();

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
        '/attendance/',
        data: {
          "timetable_slot": slotId,
          "date": date,
          "records": records,
        },
      );

      state = state.copyWith(status: AttendanceStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(status: AttendanceStatus.error, errorMessage: "Submission Failed: $e");
      return false;
    }
  }
}