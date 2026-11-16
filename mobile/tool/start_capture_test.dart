import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/splash/start_screen.dart';

void main() {
  testWidgets('capture rendered Start states', (tester) async {
    final loader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf'));
    await loader.load();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: StartScreen(onLoginRequired: () {}),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final pose in ['idle', 'jump', 'welcome', 'happy']) {
        await precacheImage(
          AssetImage(
            'assets/images/scenery/backgrounds/start-assets/mascot/$pose.png',
          ),
          tester.element(find.byType(StartScreen)),
        );
      }
    });
    await tester.pump();
    var previous = 0;
    for (final entry in {
      'idle': 100,
      'jump': 350,
      'welcome': 800,
      'happy': 1200,
    }.entries) {
      await tester.pump(Duration(milliseconds: entry.value - previous));
      await tester.pump();
      previous = entry.value;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 2),
      ))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(() async {
        final directory = Directory('build/start-ui');
        await directory.create(recursive: true);
        await File('${directory.path}/${entry.key}-360x800.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
