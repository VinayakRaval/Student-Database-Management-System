import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/timetable_model.dart';

class TimetableState {
  final bool isLoading;
  final List<TimeTable> timetables;
  final List<AssignmentOption> availableAssignments;
  final String? errorMessage;
  final bool isSuccess;

  TimetableState({
    this.isLoading = false,
    this.timetables = const [],
    this.availableAssignments = const [],
    this.errorMessage,
    this.isSuccess = false,
  });

  TimetableState copyWith({
    bool? isLoading,
    List<TimeTable>? timetables,
    List<AssignmentOption>? availableAssignments,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return TimetableState(
      isLoading: isLoading ?? this.isLoading,
      timetables: timetables ?? this.timetables,
      availableAssignments: availableAssignments ?? this.availableAssignments,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? false,
    );
  }
}

class TimetableController extends StateNotifier<TimetableState> {
  final Dio _dio;

  TimetableController(this._dio) : super(TimetableState());

  Future<void> fetchTimetables({String filter = 'all'}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // FIX: Use double path based on backend router
      String endpoint = '/timetable/timetables/';

      if (filter == 'pending')
        endpoint = '/timetable/timetables/pending/';
      else if (filter == 'faculty')
        endpoint = '/timetable/timetables/faculty/';
      else if (filter == 'student')
        endpoint = '/timetable/timetables/student/';
      else if (filter == 'hod')
        endpoint = '/timetable/timetables/hod/';

      final response = await _dio.get(endpoint);

      List<dynamic> data;
      if (response.data is Map && response.data.containsKey('results')) {
        data = response.data['results'];
      } else if (response.data is List) {
        data = response.data;
      } else {
        data = [];
      }

      final list = data.map((e) => TimeTable.fromMap(e)).toList();
      state = state.copyWith(isLoading: false, timetables: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Load Error: $e");
    }
  }

  Future<void> fetchAssignments(int deptId, int semId, int ayId) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get(
        '/timetable/timetables/assignments/',
        queryParameters: {
          'department_id': deptId,
          'semester': semId,
          'academic_year': ayId,
        },
      );

      final list = (response.data as List)
          .map((e) => AssignmentOption.fromMap(e))
          .toList();
      state = state.copyWith(isLoading: false, availableAssignments: list);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Assignments Error: $e",
      );
    }
  }

  Future<void> createTimetable(Map<String, dynamic> payload) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      await _dio.post('/timetable/timetables/', data: payload);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.response?.data.toString() ?? "Create Failed",
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> updateTimetable(int id, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    try {
      await _dio.put('/timetable/timetables/$id/', data: payload);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.response?.data.toString() ?? "Update Failed",
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> approveTimetable(
    int id,
    String action, {
    String? remarks,
    bool override = false,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _dio.post(
        '/timetable/timetables/$id/approve/',
        data: {'action': action, 'remarks': remarks, 'override': override},
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } on DioException catch (e) {
      String msg = e.response?.data['error'] ?? "Action Failed";
      if (e.response?.statusCode == 409) {
        msg = "Conflict Detected: ${e.response?.data['conflicts']}";
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  
  Future<List<Map<String, dynamic>>> fetchMySchedule() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get('/timetable/timetables/my_schedule/');
      state = state.copyWith(isLoading: false);
      
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Schedule Load Error: $e");
      return [];
    }
  }
}

final dioProvider = Provider<Dio>((ref) => ApiClient().dio);

final timetableProvider =
    StateNotifierProvider<TimetableController, TimetableState>((ref) {
      return TimetableController(ref.watch(dioProvider));
    });

final timetableListProvider = FutureProvider.family<List<TimeTable>, String>((
  ref,
  filter,
) async {
  final dio = ref.watch(dioProvider);
  try {
    String endpoint = '/timetable/timetables/';
    if (filter == 'pending')
      endpoint = '/timetable/timetables/pending/';
    else if (filter == 'faculty')
      endpoint = '/timetable/timetables/faculty/';
    else if (filter == 'student')
      endpoint = '/timetable/timetables/student/';
    else if (filter == 'hod')
      endpoint = '/timetable/timetables/hod/';

    final response = await dio.get(endpoint);
    List<dynamic> data;
    if (response.data is Map && response.data.containsKey('results')) {
      data = response.data['results'];
    } else if (response.data is List) {
      data = response.data;
    } else {
      data = [];
    }
    return data.map((e) => TimeTable.fromMap(e)).toList();
  } catch (e) {
    return [];
  }
});

final timetableDetailProvider = FutureProvider.family<TimeTable, int>((
  ref,
  id,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/timetable/timetables/$id/');
  return TimeTable.fromMap(response.data);
});
