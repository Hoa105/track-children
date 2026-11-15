import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/journal/journal_screen.dart';
import 'package:track_children/features/sharing/child_sharing_screen.dart';
import 'package:track_children/features/sharing/access_gate.dart';
import 'package:track_children/features/sharing/shared_with_me_screen.dart';
import 'package:track_children/models/activity.dart';
import 'package:track_children/services/app_notifications.dart';
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
Future<String> _sharedChild(
  Map<String, String> access, {
  String dateOfBirth = '2025-01-01',
}) async {
  final store = DemoStore.instance;
  final id = await store.saveChild(null, {
    'full_name': 'Bé được chia sẻ',
    'date_of_birth': dateOfBirth,
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

  test('child shared from another account on the same phone is listed', () async {
    final store = DemoStore.instance;
    DemoStore.vaccinationRemote = _Linker();
    addTearDown(() => DemoStore.vaccinationRemote = null);
    const ownerA = '11111111-1111-4111-8111-111111111111';
    const ownerB = '22222222-2222-4222-8222-222222222222';

    // Tài khoản A tạo bé trên máy và đăng ký lên máy chủ
    await store.bindAuthenticatedUser({'id': ownerA, 'email': 'a@example.test'});
    final local = await store.saveChild(null, {
      'full_name': 'Bé của A',
      'date_of_birth': '2025-02-24',
      'gender': 'male',
    });
    final serverId = (await store.linkedAccount(local))!.childId;

    // A tải lại: bé đã có trên máy, không thêm bản trùng
    await store.cacheAuthenticatedChildren(ownerA, [
      {'id': serverId, 'fullName': 'Bé của A', 'dateOfBirth': '2025-02-24',
       'gender': 'male', 'role': 'owner', 'access': {}},
    ]);
    expect(store.children.map((c) => c['full_name']), ['Bé của A']);

    // Tài khoản B (cùng máy) được chia sẻ bé đó: phải thấy bé
    await store.bindAuthenticatedUser({'id': ownerB, 'email': 'b@example.test'});
    await store.cacheAuthenticatedChildren(ownerB, [
      {'id': serverId, 'fullName': 'Bé của A', 'dateOfBirth': '2025-02-24',
       'gender': 'male', 'role': 'member', 'relationship': 'father',
       'access': {'diary': 'view', 'vaccination': 'edit'}},
    ]);
    expect(store.children.map((c) => c['id']), [serverId]);
    expect(store.isChildOwner(serverId), isFalse);
    expect(store.childAccess(serverId, 'vaccination'), 'edit');
    expect(store.childAccess(serverId, 'diary'), 'view');

    // Đồng bộ nhật ký / tiêm chủng của bé được chia sẻ: dùng id máy chủ, không
    // đăng ký lại bé dưới tài khoản B (máy chủ sẽ từ chối 403)
    final linker = DemoStore.vaccinationRemote! as _Linker;
    linker.linked.clear();
    final account = await store.linkedAccount(serverId);
    expect(account!.childId, serverId);
    expect(account.userId, ownerB);
    expect(linker.linked, isEmpty);
  });

  test('member saves vaccinations with vaccination edit, not teething', () async {
    final store = DemoStore.instance;
    final linker = _Linker();
    DemoStore.vaccinationRemote = linker;
    addTearDown(() => DemoStore.vaccinationRemote = null);
    final record = {
      'id': 'bcg-1',
      'date': '2025-03-01',
      'given': true,
      'name': 'BCG',
    };

    final editor = await _sharedChild({'vaccination': 'edit'});
    await store.saveVaccination(editor, record);
    expect(store.vaccinations(editor).map((r) => r['id']), contains('bcg-1'));
    expect(linker.saved.values.single.single['id'], 'bcg-1');
    expect(linker.linked, isEmpty); // không đăng ký lại bé của người khác

    final viewer = await _sharedChild({'vaccination': 'view', 'teething': 'edit'});
    expect(
      () => store.saveVaccination(viewer, record),
      throwsA(isA<StateError>()),
    );
    expect(
      () => store.removeVaccination(viewer, 'bcg-1'),
      throwsA(isA<StateError>()),
    );
  });

  test('view-only sections reject every write in the app', () async {
    final store = DemoStore.instance;
    final id = await _sharedChild({
      for (final scope in sharingScopes) scope: 'view',
    });
    final viewOnly = throwsA(
      isA<StateError>().having(
        (e) => e.message,
        'message',
        'Bạn chỉ có quyền xem mục này',
      ),
    );
    await expectLater(
      store.saveJournalEntry(id, {
        'id': 'e1',
        'date': DateTime(2025, 3, 1).toIso8601String(),
        'note': 'x',
      }),
      viewOnly,
    );
    await expectLater(store.deleteJournalEntry(id, 'e1'), viewOnly);
    await expectLater(store.createProgressReview(id, ['a', 'b']), viewOnly);
    await expectLater(
      store.setActivityDone(id, activityCatalog.first.id, true),
      viewOnly,
    );
    await expectLater(
      store.addRecord(id, {'date': '2025-03-01', 'weight': 6.0}),
      viewOnly,
    );
    await expectLater(store.deleteMeasurement(id, 'm1'), viewOnly);
    expect(
      () => store.saveVaccination(id, {
        'id': 'd',
        'date': '2025-03-01',
        'given': true,
      }),
      viewOnly,
    );
    await expectLater(
      store.saveTooth(id, 'upper-right-central', DateTime(2025, 9, 1)),
      throwsA(isA<StateError>()),
    );
    expect(store.journalEntries(id), isEmpty);
    expect(store.completedActivities(id), isEmpty);
  });

  test('reminders skip sections the member cannot view', () async {
    final store = DemoStore.instance;
    // Bé vừa tròn 2 tháng: có mũi tiêm đến hạn để nhắc
    final now = DateTime.now();
    final dob = DateTime(now.year, now.month - 2, now.day)
        .toIso8601String()
        .substring(0, 10);
    final hidden = await _sharedChild({'diary': 'view'}, dateOfBirth: dob);
    final visible = await _sharedChild({
      'vaccination': 'view',
    }, dateOfBirth: dob);
    final ids = careNotifications(store).map((n) => n.childId).toSet();
    expect(ids.contains(hidden), isFalse);
    expect(ids.contains(visible), isTrue);
  });
}

/// Chỉ đăng ký hồ sơ (PUT /dev/profiles); các lệnh tiêm chủng không dùng ở đây.
class _Linker implements VaccinationRemote {
  final linked = <String>[];

  final saved = <String, List<Map<String, dynamic>>>{};

  @override
  Future<void> link(VaccinationAccount account) async =>
      linked.add(account.childId);

  @override
  Future<void> save(
    VaccinationAccount account,
    List<Map<String, dynamic>> records,
  ) async => saved.putIfAbsent(account.childId, () => []).addAll(records);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
