import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api/api_service.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  String? _role;
  Map<String, dynamic>? _userData;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get role => _role;
  Map<String, dynamic>? get userData => _userData;

  final _storage = SecureStorage();
  final _api = ApiService();

  Future<void> checkAuth() async {
    final token = await _storage.read('access');
    if (token != null) {
      _isLoggedIn = true;
      _role = await _storage.read('role');
      final userStr = await _storage.read('user_data');
      if (userStr != null) {
        _userData = jsonDecode(userStr);
      }
    }
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        'userlogin/login/',
        data: {'identifier': identifier, 'password': password},
      );

      final data = response.data;
      await _storage.write('access', data['access']);
      await _storage.write('refresh', data['refresh']);
      await _storage.write('role', data['role']);

      if (data['user'] != null) {
        await _storage.write('user_data', jsonEncode(data['user']));
        _userData = data['user'];
      }

      _role = data['role'];
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Login error: $e');
      _error = 'Login failed. Check your credentials.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> setAuthData(Map<String, dynamic> data) async {
    if (data['access'] != null) {
      await _storage.write('access', data['access']);
    }
    if (data['refresh'] != null) {
      await _storage.write('refresh', data['refresh']);
    }
    if (data['role'] != null) {
      await _storage.write('role', data['role']);
      _role = data['role'];
    }
    if (data['user'] != null) {
      await _storage.write('user_data', jsonEncode(data['user']));
      _userData = data['user'];
    }
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete('access');
    await _storage.delete('refresh');
    await _storage.delete('role');
    await _storage.delete('user_data');
    _isLoggedIn = false;
    _role = null;
    _userData = null;
    notifyListeners();
  }

  // Forgot Password - Send OTP
  Future<Map<String, dynamic>> sendResetOtp(String email) async {
    try {
      final response = await _api.dio.post(
        'userlogin/password/forgot/',
        data: {'email': email},
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'OTP Sent',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to send OTP. Check email.'};
    }
  }

  // Forgot Password - Verify OTP & Reset
  Future<Map<String, dynamic>> verifyAndReset(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await _api.dio.post(
        'userlogin/password/verify/',
        data: {'email': email, 'otp': otp, 'new_password': newPassword},
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Success',
      };
    } catch (e) {
      return {'success': false, 'message': 'Invalid OTP or Expired.'};
    }
  }

  // Change Password for authenticated user
  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final response = await _api.dio.post(
        'userlogin/password/change/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Password changed successfully',
      };
    } catch (e) {
      String msg = 'Failed to change password.';
      try {
        final dynamic errData = (e as dynamic).response?.data;
        if (errData is Map && errData['error'] != null) {
          msg = errData['error'].toString();
        } else if (errData is Map && errData['detail'] != null) {
          msg = errData['detail'].toString();
        }
      } catch (_) {}
      return {'success': false, 'message': msg};
    }
  }
}
