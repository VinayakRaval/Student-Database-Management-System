import '../models/attendance_model.dart';

enum AttendanceStatus { initial, loading, loaded, submitting, success, error }

class AttendanceState {
  final AttendanceStatus status;
  final List<StudentAttendanceModel> students;
  final String? errorMessage;

  AttendanceState({
    this.status = AttendanceStatus.initial,
    this.students = const [],
    this.errorMessage,
  });

  AttendanceState copyWith({
    AttendanceStatus? status,
    List<StudentAttendanceModel>? students,
    String? errorMessage,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      students: students ?? this.students,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  // Getters for UI summaries
  int get total => students.length;
  int get presentCount => students.where((s) => s.isPresent).length;
  int get absentCount => students.where((s) => !s.isPresent).length;
}