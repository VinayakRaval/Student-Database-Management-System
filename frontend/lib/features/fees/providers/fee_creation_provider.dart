import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../models/fee_structure_models.dart';

// --- HELPER ---
List<dynamic> _extractList(dynamic data) {
  if (data == null) return [];
  if (data is List) return data;
  if (data is Map<String, dynamic> && data.containsKey('results')) {
    return data['results'] as List;
  }
  return [];
}

// --- STATE ---
class FeeCreationState {
  final bool isLoading;
  final List<FeeComponentInput> components;
  final double totalAmount;
  final bool isEditMode; // <--- NEW

  FeeCreationState({
    this.isLoading = false,
    this.components = const [],
    this.totalAmount = 0.0,
    this.isEditMode = false,
  });

  FeeCreationState copyWith({
    bool? isLoading,
    List<FeeComponentInput>? components,
    double? totalAmount,
    bool? isEditMode,
  }) {
    return FeeCreationState(
      isLoading: isLoading ?? this.isLoading,
      components: components ?? this.components,
      totalAmount: totalAmount ?? this.totalAmount,
      isEditMode: isEditMode ?? this.isEditMode,
    );
  }
}

// --- NOTIFIER ---
class FeeCreationNotifier extends StateNotifier<FeeCreationState> {
  FeeCreationNotifier()
    : super(FeeCreationState(components: [FeeComponentInput()]));

  void resetForm() {
    state = FeeCreationState(components: [FeeComponentInput()]);
  }

  // --- NEW: LOAD EXISTING DATA FOR EDITING ---
  void loadExistingData(FeeStructure fee) {
    state = FeeCreationState(
      isEditMode: true,
      totalAmount: fee.totalAmount,
      components: fee.components
          .map((c) => FeeComponentInput(name: c.name, amount: c.amount))
          .toList(),
    );
  }

  void addComponent() {
    state = state.copyWith(
      components: [...state.components, FeeComponentInput()],
    );
  }

  void removeComponent(int index) {
    if (state.components.length > 1) {
      final newComponents = [...state.components];
      newComponents.removeAt(index);
      state = state.copyWith(components: newComponents);
      _calculateTotal();
    }
  }

  void updateComponent(int index, String? name, String? amountStr) {
    final item = state.components[index];
    if (name != null) item.name = name;
    if (amountStr != null) item.amount = double.tryParse(amountStr) ?? 0.0;
    _calculateTotal();
  }

  void _calculateTotal() {
    double total = state.components.fold(0, (sum, item) => sum + item.amount);
    state = state.copyWith(totalAmount: total);
  }

  Future<bool> submitFeeStructure({
    int? id,
    required int deptId,
    required int yearId,
    required int semId,
    required String seatType,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(
        key: 'access',
      ); // Changed from access_token

      print("TOKEN: ${token?.substring(0, 15)}...");

      if (token == null) {
        print("NO TOKEN FOUND");
        state = state.copyWith(isLoading: false);
        return false;
      }

      final payload = {
        "department": deptId,
        "academic_year": yearId,
        "semester": semId,
        "seat_type": seatType,
        "total_amount": state.totalAmount,
        "components": state.components.map((e) => e.toJson()).toList(),
      };

      print("PAYLOAD: $payload");

      final dio = Dio();
      final url = id == null
          ? 'http://127.0.0.1:8000/fees/fee-structures/'
          : 'http://127.0.0.1:8000/fees/fee-structures/$id/';

      print("URL: $url");

      final response = await (id == null ? dio.post : dio.put)(
        url,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("STATUS: ${response.statusCode}");
      print("RESPONSE: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        print("API Error: ${response.data}");
        state = state.copyWith(isLoading: false);
        return false;
      }
    } catch (e) {
      print("EXCEPTION: $e");
      state = state.copyWith(isLoading: false);
      return false;
    }
  }
}

final feeCreationProvider =
    StateNotifierProvider.autoDispose<FeeCreationNotifier, FeeCreationState>((
      ref,
    ) {
      return FeeCreationNotifier();
    });

// --- DROPDOWN FETCHERS ---

final departmentListProvider = FutureProvider.autoDispose((ref) async {
  final res = await ApiClient().dio.get('/academics/departments/');
  return _extractList(
    res.data,
  ).map((e) => FeeDropdownItem.fromJson(e)).toList();
});
final academicYearListProvider = FutureProvider.autoDispose((ref) async {
  final res = await ApiClient().dio.get('/academics/academic-years/');
  return _extractList(
    res.data,
  ).map((e) => FeeDropdownItem.fromJson(e)).toList();
});
final semesterListProvider = FutureProvider.autoDispose((ref) async {
  final res = await ApiClient().dio.get('/academics/semesters/');
  return _extractList(
    res.data,
  ).map((e) => FeeDropdownItem.fromJson(e)).toList();
});
