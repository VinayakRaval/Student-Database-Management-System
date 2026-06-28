import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // --- APPROVE (Hardened with Logs & Manual Token) ---
  Future<bool> approveStructure(int id) async {
    state = const AsyncValue.loading();
    try {
      // 1. Get Token
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access');

      if (token == null) {
        print("❌ Error: No Token found for approval");
        return false;
      }

      print("🚀 APPROVING ID: $id");

      // 2. Manual Request
      final dio = Dio();
      final response = await dio.post(
        'http://127.0.0.1:8000/fees/fee-structures/$id/approve/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500, // Handle 400/403 manually
        ),
      );

      // 3. Handle Response
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ SUCCESS: Approved");
        state = const AsyncValue.data(null);
        return true;
      } else {
        print("❌ SERVER ERROR: ${response.statusCode}");
        print("❌ RESPONSE: ${response.data}");
        state = AsyncValue.error(
          "Failed: ${response.statusCode}",
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      print("❌ EXCEPTION: $e");
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // --- REJECT (Hardened with JSON Encode) ---
  Future<bool> rejectStructure(int id, String remarkText) async {
    state = const AsyncValue.loading();
    try {
      if (remarkText.trim().isEmpty) return false;

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');

      if (token == null) {
        print("❌ Error: No Token found for rejection");
        return false;
      }

      final String url =
          'http://127.0.0.1:8000/fees/fee-structures/$id/reject/';
      final String body = jsonEncode({"remark": remarkText.trim()});

      print("🚀 REJECTING: $url");
      print("📦 BODY: $body");

      final dio = Dio();
      final response = await dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ SUCCESS: Rejected");
        state = const AsyncValue.data(null);
        return true;
      } else {
        print("❌ SERVER ERROR: ${response.statusCode}");
        print("❌ RESPONSE: ${response.data}");
        state = AsyncValue.error(
          "Failed: ${response.statusCode}",
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      print("❌ EXCEPTION: $e");
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final feeActionProvider =
    StateNotifierProvider<FeeActionNotifier, AsyncValue<void>>((ref) {
      return FeeActionNotifier();
    });
