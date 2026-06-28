import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// 1. Add this import
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        // Note: Use 'http://10.0.2.2:8000' if testing on Android Emulator
        baseUrl: 'http://127.0.0.1:8000',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          print("🔵 SENDING REQUEST: ${options.uri}");

          final token = await _storage.read(key: 'access');
          if (token != null && token.isNotEmpty) {
            print("✅ TOKEN FOUND: ${token.substring(0, 15)}...");
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            print("🚨 NO TOKEN FOUND in Storage!");
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          print("❌ REQUEST FAILED: ${e.response?.statusCode}");
          print("❌ DATA: ${e.response?.data}");
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}

final apiClientProvider = Provider<Dio>((ref) {
  return ApiClient().dio;
});
