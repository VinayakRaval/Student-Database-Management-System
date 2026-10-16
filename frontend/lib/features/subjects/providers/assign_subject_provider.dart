import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deptFuture = _dio.get('/academics/departments/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final semFuture = _dio.get('/academics/semesters/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final ayFuture = _dio.get('/academics/academic-years/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final facFuture = _dio.get('/faculty/faculties/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []));

      final results = await Future.wait([deptFuture, semFuture, ayFuture, facFuture]);

      List<dynamic> getList(dynamic data) {
        if (data is Map && data.containsKey('results') && data['results'] is List) return data['results'] as List;
        if (data is List) return data;
        return [];
      }

      final depts = getList(results[0].data).map((e) => AssignOption.fromMap(e)).toList();
      var sems = getList(results[1].data).map((e) => AssignOption.fromMap(e)).toList();
      var ays = getList(results[2].data).map((e) => AssignOption.fromMap(e)).toList();
      final facs = getList(results[3].data).map((e) => AssignOption.fromMap(e)).toList();

      // Ensure semesters and academic years are never empty
      if (sems.isEmpty) {
        sems = List.generate(8, (i) => AssignOption(id: i + 1, name: "Semester ${i + 1}"));
      }
      if (ays.isEmpty) {
        ays = [AssignOption(id: 1, name: "2025-2026")];
      }

      state = state.copyWith(
        isLoading: false,
        departments: depts,
        semesters: sems,
        academicYears: ays,
        faculties: facs,
      );
    } catch (e) {
      // Even on failure, guarantee semesters and academic years are available
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Init Error: $e",
        semesters: List.generate(8, (i) => AssignOption(id: i + 1, name: "Semester ${i + 1}")),
        academicYears: [AssignOption(id: 1, name: "2025-2026")],
      );
    }
  }

  // 2. Fetch Subjects based on Department & Semester (supports cross-department)
  Future<void> fetchSubjects(dynamic deptId, int semId) async {
    state = state.copyWith(isLoading: true); // Show loading while fetching subjects
    try {
      final queryParams = <String, dynamic>{'semester': semId};
      if (deptId != null && deptId.toString().isNotEmpty) {
        queryParams['department_id'] = deptId;
      }
      // Endpoint from views.py: GetSubjectsView with filtering
      final response = await _dio.get(
        '/subjects/getSubjects/', 
        queryParameters: queryParams,
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
      String errorMsg = "Assignment Failed";
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          final map = e.response!.data as Map;
          if (map.containsKey('error')) {
            errorMsg = map['error'].toString();
          } else if (map.containsKey('detail')) {
            errorMsg = map['detail'].toString();
          } else if (map.values.isNotEmpty) {
            errorMsg = map.values.first.toString();
          } else {
            errorMsg = map.toString();
          }
        } else {
          errorMsg = e.response?.data.toString() ?? "Assignment Failed";
        }
      }
      state = state.copyWith(
        isLoading: false, 
        errorMessage: errorMsg
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