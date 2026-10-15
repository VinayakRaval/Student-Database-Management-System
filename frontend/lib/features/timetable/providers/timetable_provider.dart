
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/network/api_client.dart';
import '../models/timetable_model.dart';

class TimetableState {
  final bool isLoading;
  final List<TimeTable> timetables;
  final List<AssignmentOption> availableAssignments;
  final String? errorMessage;
  final bool isSuccess;

  const TimetableState({
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
    bool clearError = false,
    bool? isSuccess,
  }) {
    return TimetableState(
      isLoading: isLoading ?? this.isLoading,
      timetables: timetables ?? this.timetables,
      availableAssignments:
          availableAssignments ?? this.availableAssignments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? false,
    );
  }
}

class TimetableController extends StateNotifier<TimetableState> {
  final Dio _dio;

  TimetableController(this._dio) : super(const TimetableState());

  String _endpointFor(String filter) {
    switch (filter) {
      case 'pending':
        return '/timetable/timetables/pending/';
      case 'faculty':
        return '/timetable/timetables/faculty/';
      case 'student':
        return '/timetable/timetables/student/';
      case 'hod':
        return '/timetable/timetables/hod/';
      default:
        return '/timetable/timetables/';
    }
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is List) {
      return responseData;
    }

    if (responseData is Map) {
      final results = responseData['results'];
      if (results is List) return results;

      // Support APIs that wrap their list in "data".
      final data = responseData['data'];
      if (data is List) return data;
    }

    throw const FormatException(
      'Unexpected API response: expected a list of timetable records.',
    );
  }

  String _errorText(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final body = error.response?.data;

      if (status == 401) {
        return 'Session expired. Please log in again.';
      }
      if (status == 403) {
        return 'You do not have permission to view this timetable.';
      }
      if (status == 404) {
        return 'Timetable API endpoint not found. Check the Django URL configuration.';
      }
      if (status != null) {
        return 'Server error ($status): ${body ?? error.message ?? "Request failed"}';
      }
      return 'Cannot connect to the server. Check that Django is running and the API URL is correct.';
    }

    return error.toString();
  }

  Future<void> fetchTimetables({String filter = 'all'}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isSuccess: false,
    );

    try {
      final response = await _dio.get(_endpointFor(filter));
      final records = _extractList(response.data);
      final list = records
          .map((item) => TimeTable.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();

      state = state.copyWith(
        isLoading: false,
        timetables: list,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorText(error),
      );
    }
  }

  Future<void> fetchAssignments(
    int deptId,
    int semId,
    int ayId,
  ) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final response = await _dio.get(
        '/timetable/timetables/assignments/',
        queryParameters: {
          'department_id': deptId,
          'semester': semId,
          'academic_year': ayId,
        },
      );

      final records = _extractList(response.data);
      final list = records
          .map((item) => AssignmentOption.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();

      state = state.copyWith(
        isLoading: false,
        availableAssignments: list,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Assignments error: ${_errorText(error)}',
      );
    }
  }

  Future<void> createTimetable(
    Map<String, dynamic> payload,
  ) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isSuccess: false,
    );

    try {
      await _dio.post(
        '/timetable/timetables/',
        data: payload,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        clearError: true,
      );

      await fetchTimetables();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: 'Create failed: ${_errorText(error)}',
      );
    }
  }

  Future<bool> updateTimetable(
    int id,
    Map<String, dynamic> payload,
  ) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isSuccess: false,
    );

    try {
      await _dio.put(
        '/timetable/timetables/$id/',
        data: payload,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        clearError: true,
      );

      await fetchTimetables();
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: 'Update failed: ${_errorText(error)}',
      );
      return false;
    }
  }

  Future<bool> approveTimetable(
    int id,
    String action, {
    String? remarks,
    bool override = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isSuccess: false,
    );

    try {
      await _dio.post(
        '/timetable/timetables/$id/approve/',
        data: {
          'action': action,
          'remarks': remarks,
          'override': override,
        },
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        clearError: true,
      );

      await fetchTimetables();
      return true;
    } catch (error) {
      var message = _errorText(error);

      if (error is DioException &&
          error.response?.statusCode == 409) {
        final body = error.response?.data;
        final conflicts = body is Map ? body['conflicts'] : null;
        message = 'Timetable conflict detected: $conflicts';
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: message,
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchScheduleDetails({int? semester, String? search}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final queryParams = <String, dynamic>{};
      if (semester != null) queryParams['semester'] = semester;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final response = await _dio.get(
        '/timetable/timetables/my_schedule/',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      List<Map<String, dynamic>> slots = [];
      List<Map<String, dynamic>> assignedSubjects = [];
      String facultyName = '';

      if (data is Map) {
        final rawSlots = data['slots'] ?? data['results'] ?? [];
        if (rawSlots is List) {
          slots = rawSlots.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
        final rawAssigned = data['assigned_subjects'];
        if (rawAssigned is List) {
          assignedSubjects = rawAssigned.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
        facultyName = data['faculty_name']?.toString() ?? '';
      } else if (data is List) {
        slots = data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }

      state = state.copyWith(
        isLoading: false,
        clearError: true,
      );

      return {
        'slots': slots,
        'assigned_subjects': assignedSubjects,
        'faculty_name': facultyName,
      };
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Schedule load error: ${_errorText(error)}',
      );
      return {
        'slots': <Map<String, dynamic>>[],
        'assigned_subjects': <Map<String, dynamic>>[],
        'faculty_name': '',
      };
    }
  }

  Future<List<Map<String, dynamic>>> fetchMySchedule({int? semester, String? search}) async {
    final result = await fetchScheduleDetails(semester: semester, search: search);
    return (result['slots'] as List<Map<String, dynamic>>?) ?? [];
  }
}

final dioProvider = Provider<Dio>(
  (ref) => ApiClient().dio,
);

final timetableProvider =
    StateNotifierProvider<TimetableController, TimetableState>(
  (ref) => TimetableController(ref.watch(dioProvider)),
);

final timetableListProvider =
    FutureProvider.family<List<TimeTable>, String>(
  (ref, filter) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get(
      switch (filter) {
        'pending' => '/timetable/timetables/pending/',
        'faculty' => '/timetable/timetables/faculty/',
        'student' => '/timetable/timetables/student/',
        'hod' => '/timetable/timetables/hod/',
        _ => '/timetable/timetables/',
      },
    );

    final data = response.data;
    List<dynamic> records;

    if (data is List) {
      records = data;
    } else if (data is Map && data['results'] is List) {
      records = data['results'] as List;
    } else if (data is Map && data['data'] is List) {
      records = data['data'] as List;
    } else {
      throw const FormatException(
        'Unexpected timetable API response format.',
      );
    }

    return records
        .map((item) => TimeTable.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  },
);

final timetableDetailProvider =
    FutureProvider.family<TimeTable, int>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/timetable/timetables/$id/');
  final data = response.data;

  if (data is! Map) {
    throw const FormatException(
      'Unexpected timetable detail response format.',
    );
  }

  return TimeTable.fromMap(
    Map<String, dynamic>.from(data),
  );
});
