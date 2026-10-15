import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/network/api_client.dart';
import '../models/faculty_model.dart';

// -----------------------------------------------------------------------------
// 1. REGISTRATION LOGIC
// -----------------------------------------------------------------------------

class FacultyState {
  final bool isLoading;
  final List<DepartmentOption> departments;
  final String? errorMessage;
  final bool isSuccess;

  FacultyState({
    this.isLoading = false,
    this.departments = const [],
    this.errorMessage,
    this.isSuccess = false,
  });

  FacultyState copyWith({
    bool? isLoading,
    List<DepartmentOption>? departments,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return FacultyState(
      isLoading: isLoading ?? this.isLoading,
      departments: departments ?? this.departments,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? false,
    );
  }
}

class FacultyController extends StateNotifier<FacultyState> {
  final Dio _dio;

  FacultyController(this._dio) : super(FacultyState()) {
    fetchDepartments();
  }

  // Fetch Departments for Dropdown
  // HANDLES: Simple List [] AND Paginated Response { "results": [] }
  Future<void> fetchDepartments() async {
    try {
      final response = await _dio.get('/academics/departments/');
      
      List<dynamic> data;
      // Check for Map (Pagination) or List (Direct)
      if (response.data is Map && (response.data as Map).containsKey('results')) {
         data = response.data['results'];
      } else if (response.data is List) {
         data = response.data;
      } else {
         data = [];
      }

      final departments = data.map((e) => DepartmentOption.fromMap(e)).toList();
      state = state.copyWith(departments: departments);
    } catch (e) {
      print("Department Fetch Error: $e");
      state = state.copyWith(errorMessage: "Failed to load departments: $e");
    }
  }

  // Register Faculty
  // HANDLES: File Upload on Web & Mobile using Bytes
  Future<void> registerFaculty(FacultyRegistrationModel faculty) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    try {
      FormData formData = FormData.fromMap({
        'faculty_id': faculty.facultyId,
        'name': faculty.name,
        'gender': faculty.gender,
        'dob': faculty.dob,
        'address': faculty.address,
        'phone': faculty.phone,
        'email': faculty.email,
        'department': faculty.departmentId,
        'qualification': faculty.qualification,
        'role': faculty.role,
      });

      // FIX: Read bytes instead of using file path (Works on Windows/Web)
      if (faculty.photoFile != null) {
        final bytes = await faculty.photoFile!.readAsBytes();
        formData.files.add(MapEntry(
          'photo',
          MultipartFile.fromBytes(bytes, filename: faculty.photoFile!.name),
        ));
      }

      await _dio.post('/faculty/faculties/', data: formData);

      state = state.copyWith(isLoading: false, isSuccess: true);
    } on DioException catch (e) {
      String errorMsg = "Registration Failed";
      if (e.response?.data != null) {
        errorMsg = e.response?.data.toString() ?? "Unknown Error";
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMsg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

// -----------------------------------------------------------------------------
// 2. APPROVAL & ACTION LOGIC (Approve / Reject)
// -----------------------------------------------------------------------------

class FacultyActionState {
  final bool isLoading;
  const FacultyActionState({this.isLoading = false});
}

class FacultyActionController extends StateNotifier<FacultyActionState> {
  final Dio _dio;
  FacultyActionController(this._dio) : super(const FacultyActionState());

  Future<bool> updateStatus(int id, String status) async {
    state = const FacultyActionState(isLoading: true);
    try {
      await _dio.patch('/faculty/faculties/$id/', data: {'status': status});
      state = const FacultyActionState(isLoading: false);
      return true;
    } catch (e) {
      state = const FacultyActionState(isLoading: false);
      return false; 
    }
  }

  Future<bool> updateFaculty(int id, Map<String, dynamic> data) async {
    state = const FacultyActionState(isLoading: true);
    try {
      await _dio.patch('/faculty/faculties/$id/', data: data);
      state = const FacultyActionState(isLoading: false);
      return true;
    } catch (e) {
      state = const FacultyActionState(isLoading: false);
      return false;
    }
  }
}

// -----------------------------------------------------------------------------
// 3. PROVIDERS
// -----------------------------------------------------------------------------

final dioProvider = Provider<Dio>((ref) => ApiClient().dio);

// Provider for Registration Logic
final facultyProvider = StateNotifierProvider<FacultyController, FacultyState>((ref) {
  return FacultyController(ref.watch(dioProvider));
});

// Provider for Action Logic
final facultyActionProvider = StateNotifierProvider<FacultyActionController, FacultyActionState>((ref) {
  return FacultyActionController(ref.watch(dioProvider));
});

// Provider for Fetching List (Handles Filtering & Pagination)
final facultyListProvider = FutureProvider.family<List<Faculty>, String>((ref, filter) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/faculty/faculties/');
    
    List<dynamic> data;
    // Check for Map (Pagination) or List (Direct)
    if (response.data is Map && (response.data as Map).containsKey('results')) {
       data = response.data['results'];
    } else if (response.data is List) {
       data = response.data;
    } else {
       data = [];
    }
    
    final allFaculty = data.map((e) => Faculty.fromMap(e)).toList();

    if (filter == 'pending') {
      return allFaculty.where((f) => f.status.contains('pending')).toList();
    }
    
    return allFaculty;
  } catch (e) {
    throw Exception("Failed to load faculty list: $e");
  }
});

// Provider for Fetching Single Detail
final facultyDetailProvider = FutureProvider.family<Faculty, int>((ref, id) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/faculty/faculties/$id/');
    return Faculty.fromMap(response.data);
  } catch (e) {
    throw Exception("Failed to load faculty details: $e");
  }
});