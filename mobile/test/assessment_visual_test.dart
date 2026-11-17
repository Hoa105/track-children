import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/app_colors.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/features/assessment/assessment_screen.dart';
import 'package:track_children/features/assessment/assessment_question_screen.dart';
import 'package:track_children/features/assessment/assessment_result_screen.dart';

import 'assessment_test.dart' show FakeAssessmentRepository;

void main() {
  setUpAll(() async {
    final file=File('.dart_tool/package_config.json').absolute;
    final config=jsonDecode(await file.readAsString()) as Map;
    final flutter=(config['packages'] as List).cast<Map>().firstWhere((x)=>x['name']=='flutter');
    final sdk=file.uri.resolve("${flutter['rootUri']}/");
    final icon=File.fromUri(sdk.resolve('../../bin/cache/artifacts/material_fonts/materialicons-regular.otf'));
    await(FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(await icon.readAsBytes())))).load();

    await (FontLoader('Nunito')
          ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf')))
        .load();
  });
  testWidgets('render assessment overview, question, result and history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login(DemoStore.demoEmail, DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
    final now=DateTime.now();
    await DemoStore.instance.saveChild('child_an',{'date_of_birth':DateTime(now.year-1,now.month,now.day).toIso8601String()});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final repo = FakeAssessmentRepository();
    final key = GlobalKey();
    Widget wrap(Widget page) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Nunito',
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: page,
      ),
    );
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/assessment-preview').create(recursive: true);
        await File('build/assessment-preview/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      wrap(AssessmentScreen(childId: 'child_an', repository: repo)),
    );
    await capture('overview');
    final a = await repo.start('child_an', 'visual');
    await tester.pumpWidget(
      wrap(
        AssessmentQuestionScreen(
          childId: 'child_an',
          attempt: a,
          repository: repo,
        ),
      ),
    );
    await capture('question');
    await tester.pumpWidget(const SizedBox());
    final saved = await repo.save(
      'child_an',
      a,
      {'q0': 'not_yet', 'q1': 'not_observed'},
      'no',
      'no',
    );
    final result = await repo.complete('child_an', saved);
    await tester.pumpWidget(
      wrap(
        AssessmentResultScreen(
          childId: 'child_an',
          attempt: result,
          isDemo: false,
        ),
      ),
    );
    await capture('result');
    await tester.scrollUntilVisible(find.text('Hướng dẫn tiếp theo'), 400);
    await capture('guidance');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      wrap(
        AssessmentScreen(
          childId: 'child_an',
          initialHistory: true,
          repository: repo,
        ),
      ),
    );
    await capture('history');
    await tester.tap(find.text('Tất cả mốc tuổi'));
    await capture('age-filter');
  });
}
