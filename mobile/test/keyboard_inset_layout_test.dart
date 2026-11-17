import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/platform/keyboard_inset_layout.dart';

void main() {
  testWidgets(
    'keyboard close and oversized/invalid viewport never create negative insets',
    (tester) async {
      for (final height in [430.0, 844.0, 900.0, -1.0, double.nan]) {
        late MediaQueryData measured;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: KeyboardInsetLayout(
              visibleHeight: height,
              child: Builder(
                builder: (context) {
                  measured = MediaQuery.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        expect(measured.viewInsets.bottom, height == 430 ? 414 : 0);
        expect(measured.viewInsets.isNonNegative, isTrue);
      }
    },
  );
  testWidgets(
    'scaffold action stays above keyboard and returns after dismiss',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final visible = ValueNotifier(430.0);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: ValueListenableBuilder<double>(
            valueListenable: visible,
            builder: (_, height, _) => KeyboardInsetLayout(
              visibleHeight: height,
              child: MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      const TextField(),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Tiếp tục'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byType(FilledButton)).dy,
        lessThanOrEqualTo(430),
      );
      visible.value = 844;
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byType(FilledButton)).dy,
        greaterThan(800),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      visible.dispose();
    },
  );
}
