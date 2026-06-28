import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/subject_model.dart';

class SubjectState {
  final bool isLoading;
  final List<SubjectOption> departments;
  final List<SubjectOption> semesters;
  final List<SubjectOption> schemas;
  final String? errorMessage;
  final bool isSuccess;

  SubjectState({
    this.isLoading = false,
    this.departments = const [],
    this.semesters = const [],
    this.schemas = const [],
    this.errorMessage,
    this.isSuccess = false,
  });

  SubjectState copyWith({
    bool? isLoading,
    List<SubjectOption>? departments,
    List<SubjectOption>? semesters,
    List<SubjectOption>? schemas,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return SubjectState(
      isLoading: isLoading ?? this.isLoading,
      departments: departments ?? this.departments,
      semesters: semesters ?? this.semesters,
      schemas: schemas ?? this.schemas,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? false,
    );
  }
}

class SubjectController extends StateNotifier<SubjectState> {
  final Dio _dio;

  SubjectController(this._dio) : super(SubjectState()) {
    loadDropdowns();
  }

  Future<void> loadDropdowns() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _dio.get('/academics/departments/'),
        _dio.get('/academics/semesters/'),
        _dio.get('/academics/schemas/'), 
      ]);

      List<dynamic> getList(dynamic data) {
        if (data is Map && data.containsKey('results')) return data['results'];
        if (data is List) return data;
        return [];
      }

      state = state.copyWith(
        isLoading: false,
        departments: getList(results[0].data).map((e) => SubjectOption.fromMap(e)).toList(),
        semesters: getList(results[1].data).map((e) => SubjectOption.fromMap(e)).toList(),
        schemas: getList(results[2].data).map((e) => SubjectOption.fromMap(e)).toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Failed to load options: $e");
    }
  }

  Future<void> addSubject(SubjectAddModel subject) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    try {
      await _dio.post('/subjects/addSubject/', data: subject.toMap());
      state = state.copyWith(isLoading: false, isSuccess: true);
    } on DioException catch (e) {
      String errorMsg = "Failed to add subject";
      if (e.response?.data != null) {
        errorMsg = e.response?.data.toString() ?? "Unknown Error";
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMsg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // --- NEW: Add Schema Functionality ---
  Future<bool> addSchema(String name, int departmentId) async {
    // We don't set global loading here to avoid redrawing the whole screen logic unnecessarily
    // The dialog will handle its own loading feedback if needed, 
    // but we will refresh the list after success.
    try {
      // API Doc Page 6: POST /api/academics/schemas/
      await _dio.post('/academics/schemas/', data: {
        'name': name,
        'department': departmentId,
      });
      
      // Reload dropdowns to show the new schema
      await loadDropdowns(); 
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: "Failed to add schema: $e");
      return false;
    }
  }
}

// PROVIDER
final dioProvider = Provider<Dio>((ref) => ApiClient().dio);

final subjectProvider = StateNotifierProvider<SubjectController, SubjectState>((ref) {
  return SubjectController(ref.watch(dioProvider));
});