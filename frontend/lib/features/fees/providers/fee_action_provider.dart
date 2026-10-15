import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/api_client.dart';
import '../models/fee_structure_models.dart';

// --- HELPER ---
List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map<String, dynamic> && data.containsKey('results')) {
    return data['results'] as List;
  }
  return [];
}

// --- PROVIDER: FETCH LIST ---
final feeStructureListProvider = FutureProvider.family
    .autoDispose<List<FeeStructure>, String>((ref, filter) async {
      final dio = ApiClient().dio; // GET requests work fine with global client

      Map<String, dynamic> query = {};
      if (filter == 'pending') {
        query['approval_status'] = 'pending';
      }

      final response = await dio.get(
        '/fees/fee-structures/',
        queryParameters: query,
      );

      final list = _extractList(response.data);
      return list.map((e) => FeeStructure.fromJson(e)).toList();
    });

// --- PROVIDER: FETCH DETAIL ---
final feeStructureDetailProvider = FutureProvider.family
    .autoDispose<FeeStructure, int>((ref, id) async {
      final dio = ApiClient().dio;
      final response = await dio.get('/fees/fee-structures/$id/');
      return FeeStructure.fromJson(response.data);
    });

// --- NOTIFIER: ACTIONS (Approve / Reject) ---
class FeeActionNotifier extends StateNotifier<AsyncValue<void>> {
  FeeActionNotifier() : super(const AsyncValue.data(null));

  // --- APPROVE ---
  Future<bool> approveStructure(int id) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient().dio;
      final response = await dio.post(
        '/fees/fee-structures/$id/approve/',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = const AsyncValue.data(null);
        return true;
      } else {
        final errorMsg = response.data is Map ? (response.data['detail'] ?? "Approval failed") : "Failed: ${response.statusCode}";
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // --- REJECT ---
  Future<bool> rejectStructure(int id, String remarkText) async {
    state = const AsyncValue.loading();
    try {
      if (remarkText.trim().isEmpty) return false;

      final dio = ApiClient().dio;
      final response = await dio.post(
        '/fees/fee-structures/$id/reject/',
        data: {"remark": remarkText.trim()},
        options: Options(validateStatus: (status) => status != null && status < 500),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = const AsyncValue.data(null);
        return true;
      } else {
        final errorMsg = response.data is Map ? (response.data['detail'] ?? "Rejection failed") : "Failed: ${response.statusCode}";
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final feeActionProvider =
    StateNotifierProvider<FeeActionNotifier, AsyncValue<void>>((ref) {
      return FeeActionNotifier();
    });
