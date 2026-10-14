import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/sharing/child_sharing_screen.dart';

void main() {
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
          'Mời người cùng chăm bé',
          'Người đang cùng chăm bé',
          'Chuyển quyền sở hữu hồ sơ',
        ]) {
          await tester.scrollUntilVisible(
            find.text(label),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
