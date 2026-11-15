import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/journal/journal_screen.dart';
import 'package:track_children/features/sharing/child_sharing_screen.dart';
import 'package:track_children/features/sharing/access_gate.dart';
import 'package:track_children/features/sharing/shared_with_me_screen.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/sharing_api.dart';

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi(this.invitations);
  List<IncomingInvitation> invitations;
  final accepted = <String>[];
  final declined = <String>[];
  final left = <String>[];

  @override
  Future<List<IncomingInvitation>> incoming() async => List.of(invitations);

  @override
  Future<void> accept(String invitationId) async {
    accepted.add(invitationId);
    invitations = invitations.where((i) => i.id != invitationId).toList();
  }

  @override
  Future<void> decline(String invitationId) async {
    declined.add(invitationId);
    invitations = invitations.where((i) => i.id != invitationId).toList();
  }

  @override
  Future<void> leave(String childId) async => left.add(childId);
}

IncomingInvitation _invitation(String id) => IncomingInvitation(
  id: id,
  childId: 'child-x',
  childName: 'Bé Na',
  inviterName: 'Mẹ Lan',
  permissions: const {'diary': 'edit', 'growth': 'view'},
  expiresAt: DateTime.now().add(const Duration(days: 6, hours: 1)),
);

/// Bé của người khác được chia sẻ với tài khoản đang đăng nhập.
Future<String> _sharedChild(Map<String, String> access) async {
  final store = DemoStore.instance;
  final id = await store.saveChild(null, {
    'full_name': 'Bé được chia sẻ',
    'date_of_birth': '2025-01-01',
    'gender': 'female',
  });
  await store.saveChild(id, {
    'server': true,
    'role': 'member',
    'access': access,
    'growthAccess': access['growth'] ?? 'none',
    'teethingAccess': access['teething'] ?? 'none',
  });
  return id;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });

  test('owner has full access; member follows the granted levels', () async {
    final store = DemoStore.instance;
    final own = store.children.first['id'] as String;
    expect(store.isChildOwner(own), isTrue);
    expect(store.childAccess(own, 'diary'), 'edit');

    final shared = await _sharedChild({'diary': 'view', 'growth': 'edit'});
    expect(store.isChildOwner(shared), isFalse);
    expect(store.childAccess(shared, 'diary'), 'view');
    expect(store.canViewChild(shared, 'diary'), isTrue);
    expect(store.canEditChild(shared, 'diary'), isFalse);
    expect(store.canEditChild(shared, 'growth'), isTrue);
    expect(store.childAccess(shared, 'vaccination'), 'none');
  });

  testWidgets('view-only diary hides writing actions', (tester) async {
    final id = await _sharedChild({'diary': 'view'});
    await tester.pumpWidget(MaterialApp(home: JournalScreen(childId: id)));
    await tester.pumpAndSettle();

    expect(find.byType(ReadOnlyNotice), findsOneWidget);
    expect(find.text('Viết nhật ký'), findsNothing);
  });

  testWidgets('no diary access shows the locked view', (tester) async {
    final id = await _sharedChild({'growth': 'view'});
    await tester.pumpWidget(MaterialApp(home: JournalScreen(childId: id)));
    await tester.pumpAndSettle();

    expect(find.byType(NoAccessView), findsOneWidget);
    expect(find.text('Viết nhật ký'), findsNothing);
  });

  testWidgets('invitee accepts and declines invitations', (tester) async {
    final api = _FakeSharingApi([_invitation('inv-1'), _invitation('inv-2')]);
    await tester.pumpWidget(MaterialApp(home: SharedWithMeScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Mẹ Lan mời bạn cùng chăm sóc Bé Na'), findsNWidgets(2));
    expect(find.text('Xem & sửa: Nhật ký · Chỉ xem: Tăng trưởng'), findsNWidgets(2));
    expect(find.text('Hết hạn sau 6 ngày'), findsNWidgets(2));

    await tester.tap(find.text('Chấp nhận').first);
    await tester.pumpAndSettle();
    expect(api.accepted, ['inv-1']);
    expect(find.text('Đã tham gia hồ sơ của Bé Na.'), findsOneWidget);

    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(api.declined, ['inv-2']);
    expect(find.text('Chưa có lời mời nào.'), findsOneWidget);
  });

  testWidgets('member sees own permissions and can leave', (tester) async {
    final id = await _sharedChild({'diary': 'edit', 'vaccination': 'view'});
    final api = _FakeSharingApi([]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SharedChildAccessScreen(childId: id, api: api),
              ),
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(find.text('Xem & sửa'), findsOneWidget);
    expect(find.text('Chỉ xem'), findsOneWidget);
    expect(find.text('Không xem'), findsNWidgets(4));

    await tester.tap(find.byKey(const ValueKey('leave-shared-child')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rời hồ sơ'));
    await tester.pumpAndSettle();
    expect(api.left, [id]);
    expect(find.text('Mở'), findsOneWidget);
  });

  Future<List<SharingInvite>> pumpInvite(
    WidgetTester tester, {
    double width = 400,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    final sent = <SharingInvite>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: InviteMemberScreen(
          onSendInvite: (invite) async {
            sent.add(invite);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return sent;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    // ListView chỉ dựng phần đang hiện: cuộn xuống tìm widget chưa được dựng
    if (finder.evaluate().isEmpty) {
      // Về đầu trang rồi cuộn xuống: widget cần tìm có thể nằm phía trên
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('invite needs a relationship and sends chosen permissions', (
    tester,
  ) async {
    final sent = await pumpInvite(tester);
    await tester.enterText(find.byType(TextField), 'ba@example.com');

    await tapVisible(tester, find.byKey(const ValueKey('invite-send')));
    expect(sent, isEmpty);
    expect(find.text('Chọn mối quan hệ của người này với bé nhé.'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('invite-relationship')));
    for (final label in ['Bố', 'Mẹ', 'Ông nội', 'Bà nội', 'Ông ngoại', 'Bảo mẫu']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Bà ngoại').last);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('invite-diary-edit')));
    await tapVisible(tester, find.byKey(const ValueKey('invite-vaccination-none')));
    await tapVisible(tester, find.byKey(const ValueKey('invite-send')));

    expect(sent, hasLength(1));
    expect(sent.single.contact, 'ba@example.com');
    expect(sent.single.relationship, 'maternal_grandmother');
    expect(sent.single.permissions, {
      'growth': 'view',
      'assessment': 'view',
      'vaccination': 'none',
      'teething': 'view',
      'diary': 'edit',
      'activities': 'view',
    });
    expect(find.text('Gửi lời mời khác'), findsOneWidget);
  });

  testWidgets('invite blocks sending when every section is hidden', (
    tester,
  ) async {
    final sent = await pumpInvite(tester);
    await tester.enterText(find.byType(TextField), 'ba@example.com');
    await tapVisible(tester, find.byKey(const ValueKey('invite-relationship')));
    await tester.tap(find.text('Bố').last);
    await tester.pumpAndSettle();
    for (final scope in sharingScopes) {
      await tapVisible(tester, find.byKey(ValueKey('invite-$scope-none')));
    }
    await tapVisible(tester, find.byKey(const ValueKey('invite-send')));
    expect(sent, isEmpty);
    expect(find.text('Cho phép người này xem ít nhất một mục nhé.'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('invite screen fits 320 px at text scale $scale', (
      tester,
    ) async {
      await pumpInvite(tester, width: 320, scale: scale);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('invite-send')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('relationship labels cover new and legacy codes', () {
    expect(relationshipLabel('paternal_grandfather'), 'Ông nội');
    expect(relationshipLabel('grandmother'), 'Bà');
    expect(relationshipLabel(null), 'Người chăm sóc');
  });
}
