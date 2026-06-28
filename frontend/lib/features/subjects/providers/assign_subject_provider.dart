import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/assign_subject_model.dart';

class AssignSubjectState {
  final bool isLoading;
  // Dropdown Lists
  final List<AssignOption> departments;
  final List<AssignOption> semesters;
  final List<AssignOption> academicYears;
  final List<AssignOption> faculties;
  final List<AssignOption> availableSubjects; // Fetched dynamically
  
  final String? errorMessage;
  final bool isSuccess;

  AssignSubjectState({
    this.isLoading = false,
    this.departments = const [],
    this.semesters = const [],
    this.academicYears = const [],
    this.faculties = const [],
    this.availableSubjects = const [],
    this.errorMessage,
    this.isSuccess = false,
  });

  AssignSubjectState copyWith({
    bool? isLoading,
    List<AssignOption>? departments,
    List<AssignOption>? semesters,
    List<AssignOption>? academicYears,
    List<AssignOption>? faculties,
    List<AssignOption>? availableSubjects,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AssignSubjectState(
      isLoading: isLoading ?? this.isLoading,
      departments: departments ?? this.departments,
      semesters: semesters ?? this.semesters,
      academicYears: academicYears ?? this.academicYears,
      faculties: faculties ?? this.faculties,
      availableSubjects: availableSubjects ?? this.availableSubjects,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? false,
    );
  }
}

class AssignSubjectController extends StateNotifier<AssignSubjectState> {
  final Dio _dio;

  AssignSubjectController(this._dio) : super(AssignSubjectState()) {
    loadInitialData();
  }

  // 1. Load Static Dropdowns
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _dio.get('/academics/departments/'),
        _dio.get('/academics/semesters/'),
        _dio.get('/academics/academic-years/'),
        _dio.get('/faculty/faculties/'), 
      ]);

      List<dynamic> getList(dynamic data) {
        if (data is Map && data.containsKey('results')) return data['results'];
        if (data is List) return data;
        return [];
      }

      state = state.copyWith(
        isLoading: false,
        departments: getList(results[0].data).map((e) => AssignOption.fromMap(e)).toList(),
        semesters: getList(results[1].data).map((e) => AssignOption.fromMap(e)).toList(),
        academicYears: getList(results[2].data).map((e) => AssignOption.fromMap(e)).toList(),
        faculties: getList(results[3].data).map((e) => AssignOption.fromMap(e)).toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Init Error: $e");
    }
  }

  // 2. Fetch Subjects based on Department & Semester
  Future<void> fetchSubjects(int deptId, int semId) async {
    state = state.copyWith(isLoading: true); // Show loading while fetching subjects
    try {
      // Endpoint from your views.py: GetSubjectsView with filtering
      final response = await _dio.get(
        '/subjects/getSubjects/', 
        queryParameters: {'department_id': deptId, 'semester': semId}
      );
      
      List<dynamic> data;
      if (response.data is List) {
        data = response.data;
      } else {
        // Handle "No subjects found" 404 or empty object
        data = [];
      }

      final subjects = data.map((e) => AssignOption.fromMap(e)).toList();
      
      state = state.copyWith(isLoading: false, availableSubjects: subjects);
    } catch (e) {
      // If 404 (No subjects), just clear the list
      state = state.copyWith(isLoading: false, availableSubjects: []); 
    }
  }

  // 3. Submit Assignments
  Future<void> submitAssignment(SubjectAssignmentRequest request) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);
    try {
      await _dio.post('/subjects/assign_subjects/', data: request.toMap());
      state = state.copyWith(isLoading: false, isSuccess: true);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, 
        errorMessage: e.response?.data.toString() ?? "Assignment Failed"
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

// PROVIDERS
final dioProvider = Provider<Dio>((ref) => ApiClient().dio);

final assignSubjectProvider = StateNotifierProvider<AssignSubjectController, AssignSubjectState>((ref) {
  return AssignSubjectController(ref.watch(dioProvider));
});