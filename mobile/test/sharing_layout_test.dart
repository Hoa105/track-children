import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/sharing/child_sharing_screen.dart';

void main() {
  testWidgets('drag permissions between zones and save', (tester) async {
    final member = SharingMember(
      name: 'Bà Mai',
      role: 'Bà ngoại',
      contact: 'mai@example.com',
      avatar: 'M',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SharingPermissionsScreen(member: member),
              ),
            ),
            child: const Text('Mở quyền'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở quyền'));
    await tester.pumpAndSettle();
    Future<void> moveTo(AccessLevel level) async {
      final item = find.byKey(const ValueKey('permission-item-Lượng sữa'));
      final target = find.byKey(ValueKey('permission-zone-${level.name}'));
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(item));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: target,
          matching: find.byKey(const ValueKey('permission-item-Lượng sữa')),
        ),
        findsOneWidget,
      );
    }

    await moveTo(AccessLevel.view);
    await moveTo(AccessLevel.none);
    await moveTo(AccessLevel.edit);
    await tester.pumpAndSettle();
    expect(member.permissions['Lượng sữa'], AccessLevel.none);
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(member.permissions['Lượng sữa'], AccessLevel.edit);
    expect(find.text('Mở quyền'), findsOneWidget);
  });
  for (final width in [320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Sharing width $width text scale $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ChildSharingScreen(pending: ['Lời mời · parent@example.com']),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in [
          'Mời cùng chăm bé',
          'Người đang cùng chăm bé',
          'Lời mời đang chờ',
        ]) {
          await tester.scrollUntilVisible(
            find.text(label),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byTooltip('Quản lý chia sẻ'));
        await tester.pumpAndSettle();
        expect(find.text('Chuyển quyền sở hữu hồ sơ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
