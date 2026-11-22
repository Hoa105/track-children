import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/growth_tracking_flow.dart';

class _BirthGrowthRepository extends MockGrowthRepository {
  _BirthGrowthRepository(this._birth);
  final DateTime _birth;

  @override
  DateTime get dateOfBirth => _birth;
}

void main() {
  test('all 5 canonical guides match measurement_guides.vi.json and have no URLs in UI fields', () async {
    final raw = await File('assets/growth/measurement_guides.vi.json')
        .readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final guidesJson = (json['guides'] as List).cast<Map<String, dynamic>>();

    expect(GrowthMeasurementGuides.all, hasLength(5));
    expect(GrowthMeasurementGuides.globalNote, json['global_note']);

    for (final expected in guidesJson) {
      final id = expected['id'] as String;
      final guide = GrowthMeasurementGuides.byId(id);
      expect(guide.id, id);
      expect(guide.indicator, expected['indicator']);
      expect(guide.title, expected['title']);
      expect(guide.ageHint, expected['age_hint']);
      expect(guide.imageAsset, expected['image_asset']);
      expect(guide.shortHint, expected['short_hint']);
      expect(guide.preparation, expected['preparation']);
      expect(guide.steps, expected['steps']);
      expect(guide.steps, hasLength(4));
      expect(guide.tip, expected['tip']);
      expect(guide.fallback, expected['fallback']);
      expect(guide.imageCaption, isNotEmpty);
      expect(guide.imageAnnotations.length, lessThanOrEqualTo(3));

      final combinedUiText = [
        guide.title,
        guide.ageHint,
        guide.imageCaption,
        ...guide.imageAnnotations,
        guide.shortHint,
        guide.preparation,
        ...guide.steps,
        guide.tip,
        if (guide.fallback != null) guide.fallback!,
      ].join(' ');
      expect(combinedUiText.contains('http://'), isFalse);
      expect(combinedUiText.contains('https://'), isFalse);
    }
  });

  testWidgets(
    'weight guide defaults by age, switches infant/standing, and preserves typed value on dismiss',
    (tester) async {
      final infantRepo = _BirthGrowthRepository(DateTime(2026, 2, 1));
      await tester.pumpWidget(
        MaterialApp(
          home: TrackingMeasurementEditor(
            repository: infantRepo,
            metric: GrowthMetric.weight,
            initialDate: DateTime(2026, 10, 1),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '8,45');
      expect(find.text('Cách đo'), findsOneWidget);

      await tester.tap(find.text('Cách đo'));
      await tester.pumpAndSettle();

      expect(find.text('Cân bé khi chưa đứng vững'), findsOneWidget);
      expect(
        find.text('Đặt bé nằm giữa cân em bé và chờ số ổn định.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('guide-switch-weight_standing')));
      await tester.pumpAndSettle();

      expect(find.text('Cân bé khi đã đứng vững'), findsOneWidget);
      expect(
        find.text('Bé đứng yên giữa cân, không mang giày dép.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        '8,45',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'length/height guide selects lying under 24m and standing from 24m, and allows switching posture without altering typed value',
    (tester) async {
      final olderRepo = _BirthGrowthRepository(DateTime(2023, 5, 1));
      await tester.pumpWidget(
        MaterialApp(
          home: TrackingMeasurementEditor(
            repository: olderRepo,
            metric: GrowthMetric.lengthHeight,
            initialDate: DateTime(2026, 10, 1),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '92,5');
      await tester.tap(find.text('Cách đo'));
      await tester.pumpAndSettle();

      expect(find.text('Đo chiều cao khi bé đứng'), findsOneWidget);
      expect(
        find.text('Bé đứng thẳng sát tường, mắt nhìn về phía trước.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('guide-switch-length_lying')));
      await tester.pumpAndSettle();

      expect(find.text('Đo chiều dài khi bé nằm'), findsOneWidget);
      expect(
        find.text('Một người giữ đầu, một người nhẹ nhàng giữ chân bé.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        '92,5',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'head circumference guide displays 4 steps and fits narrow 360x800 screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.6),
            ),
            child: TrackingHeadQuickEditor(
              repository: MockGrowthRepository(),
              initialDate: DateTime(2025, 4, 15),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '45,2');
      await tester.tap(find.text('Cách đo'));
      await tester.pumpAndSettle();

      expect(find.text('Đo vòng đầu cho bé'), findsOneWidget);
      expect(
        find.text(
          'Đặt thước ngang trên lông mày và vòng qua phần sau đầu lớn nhất.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        '45,2',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guide illustrations have enlarged, method-tailored heights (> 190) and head guide does not overflow with 2.0x text',
    (tester) async {
      for (final guide in GrowthMeasurementGuides.all) {
        final height = GrowthMeasurementGuides.imageHeight(guide.id);
        expect(height, greaterThan(190));
        expect(height, lessThanOrEqualTo(270));
      }
      expect(
        GrowthMeasurementGuides.imageHeight('height_standing'),
        greaterThan(GrowthMeasurementGuides.imageHeight('length_lying')),
      );

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final guide in GrowthMeasurementGuides.all) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: MeasurementGuideSheet(
                  key: ValueKey(guide.id),
                  metric: switch (guide.indicator) {
                    'weight_kg' => GrowthMetric.weight,
                    'head_circum_cm' => GrowthMetric.headCircumference,
                    _ => GrowthMetric.lengthHeight,
                  },
                  initialGuideId: guide.id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            ValueKey('guide-illustration-${guide.id}'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
