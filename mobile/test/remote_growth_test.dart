import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/remote_growth_repository.dart';
import 'package:track_children/features/growth/remote_growth_screen.dart';
import 'package:track_children/services/auth_service.dart';

void main() {
  final spec = jsonDecode(
    File('../docs/api/mobile-growth.openapi.json').readAsStringSync(),
  ) as Map;
  Map<String, dynamic> example(String name) => Map<String, dynamic>.from(
    jsonDecode(jsonEncode(spec['components']['examples'][name]['value']))
        as Map,
  );
  const child = '00000000-0000-4000-8000-000000000101';

  test('late response after child/account switch is rejected', () async {
    var current = true;
    final pending = Completer<Map<String, dynamic>>();
    final repository = RemoteGrowthRepository(
      child,
      contextIsCurrent: () => current,
      transport: (_, _, {body}) => pending.future,
    );
    final response = repository.overview();
    current = false;
    pending.complete(example('OverviewEmpty'));
    await expectLater(response, throwsA(isA<AuthException>()));
  });

  test('snapshot cannot be changed through its original nested data', () {
    final original = example('OverviewEmpty');
    final document = GrowthDocument(original);
    (original['child'] as Map)['fullName'] = 'Changed';
    expect(document.child['fullName'], isNot('Changed'));
  });

  test(
    'repository follows contract queries, PUT and bodyless DELETE',
    () async {
      final calls = <(String, String, Map<String, dynamic>?)>[];
      final repository = RemoteGrowthRepository(
        child,
        transport: (method, path, {body}) async {
          calls.add((method, path, body));
          if (method == 'DELETE') return {};
          if (method == 'PUT') return example('SaveAssessmentUnavailable');
          if (path.contains('/velocity')) {
            return example('VelocityReferenceUnverified');
          }
          return example('DayEmpty');
        },
      );
      await repository.velocity(
        'weight',
        mode: 'who',
        period: 2,
        query: {'startOn': '2026-01-01', 'endBefore': '2026-03-01'},
      );
      expect(Uri.parse(calls.last.$2).queryParameters['intervalMonths'], '2');
      expect(
        Uri.parse(calls.last.$2).queryParameters['endBefore'],
        '2026-03-01',
      );
      final saved = await repository.save('2026-01-01', {'weightKg': 9.5});
      expect(saved.list('assessments').first['reason'], 'R_EXECUTION_FAILED');
      expect(calls.last.$1, 'PUT');
      expect(calls.last.$3, {'weightKg': 9.5});
      await repository.delete('measurement-id');
      expect(calls.last.$1, 'DELETE');
    },
  );

  test(
    'repository rejects mismatched child instead of leaking another snapshot',
    () async {
      final repository = RemoteGrowthRepository(
        'another-child',
        transport: (_, _, {body}) async => example('OverviewEmpty'),
      );
      await expectLater(repository.overview(), throwsFormatException);
    },
  );

  testWidgets(
    'real overview and detail render server measurements with reference failure',
    (tester) async {
      final repository = RemoteGrowthRepository(
        child,
        transport: (method, path, {body}) async => path.contains('/metrics/')
            ? example('DetailReferenceUnavailable')
            : example('OverviewEngineUnavailable'),
      );
      await tester.pumpWidget(
        MaterialApp(home: RemoteGrowthScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('9,50 kg · 2026-01-01'), findsOneWidget);
      await tester.tap(find.text('Cân nặng'));
      await tester.pumpAndSettle();
      expect(find.text('Cân nặng theo tuổi'), findsOneWidget);
      expect(find.textContaining('Chưa có đường chuẩn WHO'), findsWidgets);
      expect(
        find.textContaining('Đã có số đo; hệ thống chưa tính được đánh giá.'),
        findsWidgets,
      );
    },
  );

  testWidgets('BMI has no velocity tab', (tester) async {
    final detail = example('DetailReferenceUnavailable');
    detail['metric'] = 'bmi';
    detail['charts'] = [];
    final repository = RemoteGrowthRepository(
      child,
      transport: (_, _, {body}) async => detail,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteGrowthDetail(repository: repository, metric: 'bmi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tốc độ'), findsNothing);
    expect(find.text('Lịch sử'), findsOneWidget);
  });

  testWidgets('network error shows retry and never falls back to sample data', (
    tester,
  ) async {
    final repository = RemoteGrowthRepository(
      child,
      transport: (_, _, {body}) async => throw Exception('offline'),
    );
    await tester.pumpWidget(
      MaterialApp(home: RemoteGrowthScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('9,50 kg · 2026-01-01'), findsNothing);
  });
}
