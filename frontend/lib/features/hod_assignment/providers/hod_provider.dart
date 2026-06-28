import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/hod_model.dart';
import '../../faculty/models/faculty_model.dart';

class HODState {
  final bool isLoading;
  final List<HODAssignment> currentHODs;
  final List<HODAssignment> previousHODs;
  final List<DepartmentOption> departments;
  final List<Faculty> faculties;
  final String? errorMessage;

  HODState({
    this.isLoading = false,
    this.currentHODs = const [],
    this.previousHODs = const [],
    this.departments = const [],
    this.faculties = const [],
    this.errorMessage,
  });

  HODState copyWith({
    bool? isLoading,
    List<HODAssignment>? currentHODs,
    List<HODAssignment>? previousHODs,
    List<DepartmentOption>? departments,
    List<Faculty>? faculties,
    String? errorMessage,
  }) {
    return HODState(
      isLoading: isLoading ?? this.isLoading,
      currentHODs: currentHODs ?? this.currentHODs,
      previousHODs: previousHODs ?? this.previousHODs,
      departments: departments ?? this.departments,
      faculties: faculties ?? this.faculties,
      errorMessage: errorMessage,
    );
  }
}

class HODController extends StateNotifier<HODState> {
  final Dio _dio;

  HODController(this._dio) : super(HODState()) {
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([
        _dio.get('/hod_assignment/current/'),
        _dio.get('/hod_assignment/previous/'),
        _dio.get('/academics/departments/'),
        _dio.get('/faculty/faculties/'),
      ]);

      // FIX: Handle Pagination
      List<dynamic> getList(dynamic data) {
        if (data is Map && data.containsKey('results')) {
          return data['results'];
        } else if (data is List) {
          return data;
        }
        return [];
      }

      final currentList = getList(
        results[0].data,
      ).map((e) => HODAssignment.fromMap(e)).toList();
      final prevList = getList(
        results[1].data,
      ).map((e) => HODAssignment.fromMap(e)).toList();
      final depts = getList(
        results[2].data,
      ).map((e) => DepartmentOption.fromMap(e)).toList();
      final faculties = getList(
        results[3].data,
      ).map((e) => Faculty.fromMap(e)).toList();

      state = state.copyWith(
        isLoading: false,
        currentHODs: currentList,
        previousHODs: prevList,
        departments: depts,
        faculties: faculties,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "HOD Data Error: $e",
      );
    }
  }

  Future<bool> assignHOD(int departmentId, int facultyId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _dio.post(
        '/hod_assignment/assign/',
        data: {'department': departmentId, 'faculty': facultyId},
      );
      await fetchAllData();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Failed to assign HOD: $e",
      );
      return false;
    }
  }
}

final dioProvider = Provider<Dio>((ref) => ApiClient().dio);
final hodProvider = StateNotifierProvider<HODController, HODState>(
  (ref) => HODController(ref.watch(dioProvider)),
);
