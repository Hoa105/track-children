import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Account-scoped server inbox; failed requests never replace another account's data.
class NotificationInbox extends ChangeNotifier {
  NotificationInbox._();
  static final instance = NotificationInbox._();
  String? _account;
  List<Map<String, dynamic>> _items = [];
  bool hasMore = false;
  int _unread = 0;
  int get unreadCount => _account == account ? _unread : 0;
  String? error;
  bool get available =>
      AuthService.instance.signedIn && !AuthService.instance.demoMode;
  String? get account => AuthService.instance.user?['id']?.toString();
  List<Map<String, dynamic>> get items => _account == account ? _items : [];
  Set<String> get readIds => {
    for (final n in items)
      if (n['read_at'] != null) n['id'].toString(),
  };
  Future<void> refresh({bool more = false}) async {
    if (!available) return;
    final owner = account;
    try {
      final result = await AuthService.instance.authorizedRequest(
        'GET',
        '/notifications?offset=${more && _account == owner ? _items.length : 0}&limit=50',
      );
      if (account != owner) return;
      final rows = (result['items'] as List)
          .map((n) => Map<String, dynamic>.from(n as Map))
          .toList();
      _items = more && _account == owner ? [..._items, ...rows] : rows;
      _account = owner;
      hasMore = result['has_more'] == true;
      _unread = result['unread_count'] as int? ?? 0;
      error = null;
    } catch (_) {
      if (account != owner) return;
      error = 'Chưa tải được thông báo. Vui lòng thử lại.';
    }
    notifyListeners();
  }

  Future<void> markRead(Iterable<String> ids, {bool all = false}) async {
    if (!available) return;
    final owner = account;
    final remote = ids.where((id) => items.any((n) => n['id'] == id)).toList();
    if (remote.isEmpty && !all) return;
    // The API accepts batches of at most 200 IDs.
    for (
      var start = 0;
      start < remote.length || (all && start == 0);
      start += 200
    ) {
      await AuthService.instance.authorizedRequest(
        'POST',
        '/notifications/read',
        body: {'all': all, 'ids': remote.skip(start).take(200).toList()},
      );
      if (all) break;
    }
    if (owner != account) return;
    final changed = _items
        .where((n) => n['read_at'] == null && remote.contains(n['id']))
        .length;
    _unread = all ? 0 : (_unread - changed).clamp(0, _unread);
    for (final n in _items) {
      if (all || remote.contains(n['id'])) {
        n['read_at'] = DateTime.now().toIso8601String();
      }
    }
    notifyListeners();
  }
}
