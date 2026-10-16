import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deptFuture = _dio.get('/academics/departments/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final semFuture = _dio.get('/academics/semesters/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final schemaFuture = _dio.get('/academics/schemas/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []));

      final results = await Future.wait([deptFuture, semFuture, schemaFuture]);

      List<dynamic> getList(dynamic data) {
        if (data is Map && data.containsKey('results') && data['results'] is List) return data['results'] as List;
        if (data is List) return data;
        return [];
      }

      var depts = getList(results[0].data).map((e) => SubjectOption.fromMap(e)).toList();
      var sems = getList(results[1].data).map((e) => SubjectOption.fromMap(e)).toList();
      var schemas = getList(results[2].data).map((e) => SubjectOption.fromMap(e)).toList();

      if (depts.isEmpty) {
        depts = [
          SubjectOption(id: 2, name: "Computer Science and Engineering"),
          SubjectOption(id: 3, name: "Electronics and Communication Engineering"),
          SubjectOption(id: 5, name: "Mechanical Engineering"),
          SubjectOption(id: 6, name: "Civil Engineering"),
        ];
      }
      if (sems.isEmpty) {
        sems = List.generate(8, (i) => SubjectOption(id: i + 1, name: "Semester ${i + 1}"));
      }
      if (schemas.isEmpty) {
        schemas = [SubjectOption(id: 1, name: "2022 Scheme - CSE")];
      }

      state = state.copyWith(
        isLoading: false,
        departments: depts,
        semesters: sems,
        schemas: schemas,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Failed to load options: $e",
        departments: [
          SubjectOption(id: 2, name: "Computer Science and Engineering"),
          SubjectOption(id: 3, name: "Electronics and Communication Engineering"),
          SubjectOption(id: 5, name: "Mechanical Engineering"),
          SubjectOption(id: 6, name: "Civil Engineering"),
        ],
        semesters: List.generate(8, (i) => SubjectOption(id: i + 1, name: "Semester ${i + 1}")),
        schemas: [SubjectOption(id: 1, name: "2022 Scheme - CSE")],
      );
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
          errorMsg = e.response?.data.toString() ?? "Unknown Error";
        }
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

  Future<List<Map<String, dynamic>>> fetchOfferingSubjects(int departmentId, {int? semester}) async {
    try {
      final queryParams = <String, dynamic>{
        'department_id': departmentId,
        'cross_department': 'true',
      };
      if (semester != null) {
        queryParams['semester'] = semester;
      }
      final response = await _dio.get('/subjects/getSubjects/', queryParameters: queryParams);
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

// PROVIDER
final dioProvider = Provider<Dio>((ref) => ApiClient().dio);

final subjectProvider = StateNotifierProvider<SubjectController, SubjectState>((ref) {
  return SubjectController(ref.watch(dioProvider));
});