import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/notification_inbox.dart';

class InboxAuth extends AuthService {
  InboxAuth() : super(demoMode: false) {
    user = {'id': 'parent-a'};
  }
  Map<String, dynamic> response = {
    'items': [],
    'has_more': false,
    'unread_count': 0,
  };
  Completer<Map<String, dynamic>>? pending;
  bool fail = false;
  final List<Map<String, dynamic>> writes = [];
  @override
  Future<Map<String, dynamic>> authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (fail) throw StateError('offline');
    if (method == 'POST') {
      writes.add(body!);
      return {'ok': true};
    }
    if (pending != null) return pending!.future;
    return response;
  }
}

void main() {
  late AuthService original;
  late InboxAuth auth;
  final inbox = NotificationInbox.instance;
  setUp(() {
    original = AuthService.instance;
    auth = InboxAuth();
    AuthService.instance = auth;
  });
  tearDown(() {
    AuthService.instance = original;
  });

  test('read all includes unloaded pages and remote read state', () async {
    auth.response = {
      'items': [
        {'id': 'one', 'read_at': null},
      ],
      'has_more': true,
      'unread_count': 80,
    };
    await inbox.refresh();
    expect(inbox.unreadCount, 80);
    await inbox.markRead(['one'], all: true);
    expect(auth.writes.single['all'], true);
    expect(inbox.unreadCount, 0);
    expect(inbox.readIds, contains('one'));
  });

  test(
    'account switch hides cached notices and discards in-flight result',
    () async {
      auth.response = {
        'items': [
          {'id': 'private-a'},
        ],
        'has_more': false,
        'unread_count': 1,
      };
      await inbox.refresh();
      auth.pending = Completer();
      final request = inbox.refresh();
      auth.user = {'id': 'parent-b'};
      expect(inbox.items, isEmpty);
      expect(inbox.unreadCount, 0);
      auth.pending!.complete(auth.response);
      await request;
      expect(inbox.items, isEmpty);
    },
  );

  test(
    'failed mark-read does not optimistically discard unread state',
    () async {
      auth.response = {
        'items': [
          {'id': 'one', 'read_at': null},
        ],
        'has_more': false,
        'unread_count': 1,
      };
      await inbox.refresh();
      auth.fail = true;
      await expectLater(inbox.markRead(['one']), throwsStateError);
      expect(inbox.unreadCount, 1);
      expect(inbox.readIds, isEmpty);
    },
  );
}
