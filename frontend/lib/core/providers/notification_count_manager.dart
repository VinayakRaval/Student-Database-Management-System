import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

class NotificationCountManager extends ChangeNotifier {
  static final NotificationCountManager instance = NotificationCountManager._internal();
  NotificationCountManager._internal() {
    _startPeriodicSync();
  }

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  Timer? _syncTimer;

  void _startPeriodicSync() {
    // Initial fetch
    refresh();
    // Periodic background sync every 25 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      refresh();
    });
  }

  Future<int> refresh() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/announcements/notifications/unread_count/');
      if (res.data is Map && res.data['unread_count'] != null) {
        final count = (res.data['unread_count'] as num).toInt();
        if (_unreadCount != count) {
          _unreadCount = count < 0 ? 0 : count;
          notifyListeners();
        }
        return _unreadCount;
      }
    } catch (_) {}
    return _unreadCount;
  }

  void setCount(int count) {
    _unreadCount = count < 0 ? 0 : count;
    notifyListeners();
  }

  void decrement([int amount = 1]) {
    if (_unreadCount > 0) {
      _unreadCount = (_unreadCount - amount).clamp(0, 9999);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
