import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/core/network/api_client.dart';
import 'dart:typed_data';

Dio get _publicDio => ApiClient().dio;

// --- DROPDOWN PROVIDERS ---
final departmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final response = await _publicDio.get('/academics/departments/');
      final data = response.data;
      final list = data is List ? data : data['results'] ?? [];
      return List<Map<String, dynamic>>.from(list);
    });

final academicYearsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final response = await _publicDio.get('/academics/academic-years/');
      final data = response.data;
      final list = data is List ? data : data['results'] ?? [];
      return List<Map<String, dynamic>>.from(list);
    });

final semestersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final response = await _publicDio.get('/academics/semesters/');
      final data = response.data;
      final list = data is List ? data : data['results'] ?? [];
      return List<Map<String, dynamic>>.from(list);
    });

// --- STATE ---
class AdmissionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final int? fetchedFeeStructureId;
  final double? fetchedFeeAmount;

  AdmissionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.fetchedFeeStructureId,
    this.fetchedFeeAmount,
  });

  AdmissionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    int? fetchedFeeStructureId,
    double? fetchedFeeAmount,
  }) {
    return AdmissionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      fetchedFeeStructureId:
          fetchedFeeStructureId ?? this.fetchedFeeStructureId,
      fetchedFeeAmount: fetchedFeeAmount ?? this.fetchedFeeAmount,
    );
  }
}

// --- NOTIFIER ---
class AdmissionNotifier extends StateNotifier<AdmissionState> {
  AdmissionNotifier() : super(AdmissionState());

  Future<void> fetchFeeDetails({
    required int deptId,
    required int semId,
    required int yearId,
    required String seatType,
  }) async {
    final dio = _publicDio;
    try {
      String backendSeatType = seatType;
      if (seatType == 'general_merit') backendSeatType = 'gm';
      if (seatType == 'lateral') backendSeatType = 'Lateral';
      if (seatType == 'snq') backendSeatType = 'snq';

      final response = await dio.get(
        '/fees/fee-structures/',
        queryParameters: {
          'department': deptId,
          'semester': semId,
          'academic_year': yearId,
          'seat_type': backendSeatType,
          'is_active': true,
        },
      );

      if (response.statusCode == 200) {
        final List results = response.data is List
            ? response.data
            : response.data['results'];

        final matchingStructure = results.firstWhere((item) {
          final itemDept = item['department'];
          final itemSem = item['semester'];
          final itemYear = item['academic_year'];
          final itemSeat = item['seat_type'];

          final idDept = itemDept is Map ? itemDept['id'] : itemDept;
          final idSem = itemSem is Map ? itemSem['id'] : itemSem;
          final idYear = itemYear is Map ? itemYear['id'] : itemYear;

          return idDept == deptId &&
              idSem == semId &&
              idYear == yearId &&
              itemSeat.toString().toLowerCase() ==
                  backendSeatType.toLowerCase();
        }, orElse: () => null);

        if (matchingStructure != null) {
          if (mounted) {
            state = state.copyWith(
              fetchedFeeStructureId: matchingStructure['id'],
              fetchedFeeAmount:
                  double.tryParse(matchingStructure['total_amount'].toString()) ??
                  0.0,
            );
          }
          return;
        }
      }

      if (mounted) {
        state = state.copyWith(
          fetchedFeeStructureId: null,
          fetchedFeeAmount: null,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          fetchedFeeStructureId: null,
          fetchedFeeAmount: null,
        );
      }
    }
  }

  Future<int?> registerStudentFromMap(
    Map<String, dynamic> formMap, {
    required Map<String, Uint8List?> attachments,
  }) async {
    if (mounted) {
      state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    }
    final dio = _publicDio;

    try {
      if (formMap["address"] == null ||
          formMap["address"].toString().trim().isEmpty) {
        formMap["address"] = formMap["permanent_address"] ?? "";
      }

      final cleanedFormMap = <String, dynamic>{};
      formMap.forEach((key, value) {
        if (value != null) {
          cleanedFormMap[key] = value;
        }
      });

      attachments.forEach((key, bytes) {
        if (bytes != null && bytes.isNotEmpty) {
          cleanedFormMap[key] = MultipartFile.fromBytes(bytes, filename: "$key.png");
        }
      });

      final formData = FormData.fromMap(cleanedFormMap);

      final response = await dio.post(
        '/students/create/',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final studentId = response.data["id"];
        int? feeId = response.data["student_fee_id"];

        if (feeId == null && state.fetchedFeeStructureId != null) {
          try {
            final linkResponse = await dio.post(
              '/fees/student-fees/',
              data: {
                "student": studentId,
                "fee_structure": state.fetchedFeeStructureId,
                "status": "pending",
              },
            );
            if (linkResponse.statusCode == 201 ||
                linkResponse.statusCode == 200) {
              feeId = linkResponse.data['id'];
            }
          } catch (e) {
            // ignore
          }
        }

        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            successMessage: "Registration Successful",
          );
        }
        return studentId;
      }

      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Registration Failed: ${response.statusCode}",
        );
      }
      return null;
    } catch (e) {
      String msg = "Registration failed. Please check the entered details.";
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          final List<String> errorParts = [];
          data.forEach((k, v) {
            if (v is List) {
              errorParts.add("$k: ${v.join(', ')}");
            } else {
              errorParts.add("$k: $v");
            }
          });
          if (errorParts.isNotEmpty) {
            msg = errorParts.join('\n');
          }
        } else if (data is String && data.isNotEmpty) {
          msg = data;
        } else if (e.message != null) {
          msg = e.message!;
        }
      } else {
        msg = e.toString();
      }
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: msg);
      }
      return null;
    }
  }
}

final admissionProvider =
    StateNotifierProvider<AdmissionNotifier, AdmissionState>((ref) {
      return AdmissionNotifier();
    });
