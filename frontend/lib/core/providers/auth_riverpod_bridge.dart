import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authRoleProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'role');
});

final authUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  const storage = FlutterSecureStorage();
  final role = await storage.read(key: 'role');
  return {'role': role};
});
