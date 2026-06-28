import 'package:dio/dio.dart';
import 'package:frontend/config.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class ApiInterceptor extends Interceptor {
  final _storage = SecureStorage();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read('access');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refresh = await _storage.read('refresh');
      if (refresh != null) {
        try {
          final response = await Dio().post(
            '${AppConfig.baseUrl}userlogin/token/refresh/',
            data: {'refresh': refresh},
          );
          final newAccess = response.data['access'];
          await _storage.write('access', newAccess);
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await Dio().fetch(opts);
          return handler.resolve(retryResponse);
        } catch (e) {
          await _storage.delete('access');
          await _storage.delete('refresh');
        }
      }
    }
    super.onError(err, handler);
  }
}
