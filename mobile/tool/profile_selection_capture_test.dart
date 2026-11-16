import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/child/child_profile_selection_screen.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  testWidgets('capture profile selection layouts and exercise callbacks', (
    tester,
  ) async {
    // This manually run flutter_test harness lives in tool/ to avoid exporting
    // screenshots during the regular test suite.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    // ignore: invalid_use_of_visible_for_testing_member
    DemoStore.resetInstanceForTesting();
    final store = DemoStore.instance;
    final loader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    var addCalls = 0;
    for (final state in ['family', 'small-large-text', 'empty']) {
      if (state == 'empty') {
        await store.bindAuthenticatedUser({
          'id': 'capture-empty',
          'displayName': 'Test',
        });
      } else {
        await store.resetFixtures();
        await store.login('demo@trackchildren.vn', DemoStore.password);
        if (state == 'small-large-text') {
          await store.saveChild('child_an', {
            'full_name': 'Nguyễn Hoàng Bảo An',
          });
        }
      }
      final small = state == 'small-large-text';
      tester.view.physicalSize = small
          ? const Size(320, 568)
          : const Size(360, 800);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'Nunito',
            textTheme: const TextTheme(
              headlineMedium: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              bodyLarge: TextStyle(fontSize: 16),
            ),
          ),
          home: MediaQuery(
            data: MediaQueryData(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: TextScaler.linear(small ? 2 : 1.15),
            ),
            child: RepaintBoundary(
              key: key,
              child: ChildProfileSelectionScreen(
                onSelectChild: (name) => selected = name,
                onAddChild: () => addCalls++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 2),
      ))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(() async {
        final directory = Directory('build/profile-selection-ui');
        await directory.create(recursive: true);
        await File('${directory.path}/$state.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
      await tester.ensureVisible(find.text('Thêm hồ sơ bé'));
      await tester.tap(find.text('Thêm hồ sơ bé'));
      expect(addCalls, greaterThan(0));
      if (state == 'family') {
        await tester.tap(find.text('Bảo An'));
        await tester.pumpAndSettle();
        expect(selected, 'Bảo An');
        expect(store.child?['id'], 'child_an');
      }
      if (state == 'empty') {
        expect(find.byIcon(Icons.child_care_rounded), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
