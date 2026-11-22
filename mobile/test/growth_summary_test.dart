import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';

class SummaryRepository extends MockGrowthRepository {
  final calls = <String>[];
  Map<String, dynamic> bmi = {
    'current': {'summary': 'Nhận xét cân nặng từ máy chủ'},
  };
  Map<String, dynamic> head = {
    'current': {'summary': 'Nhận xét vòng đầu từ máy chủ'},
  };
  bool failHead = false;
  Completer<Map<String, dynamic>>? pending;

  @override
  Future<Map<String, dynamic>> parentAssessment(
    String kind, {
    String? selectedId,
    bool force = false,
  }) async {
    calls.add(kind);
    if (kind == 'head' && failHead) throw StateError('offline');
    if (kind == 'bmi' && pending != null) return pending!.future;
    return kind == 'bmi' ? bmi : head;
  }
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(800, 1400);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });
  testWidgets('overview displays both server summaries and opens detail', (
    tester,
  ) async {
    final repository = SummaryRepository();
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nhận xét cân nặng từ máy chủ'), findsOneWidget);
    expect(find.text('Nhận xét vòng đầu từ máy chủ'), findsOneWidget);
    expect(find.text('Bé trai'), findsOneWidget);
    expect(repository.calls, ['bmi', 'head']);
    await tester.ensureVisible(find.text('Nhận xét vòng đầu từ máy chủ'));
    await tester.tap(find.text('Nhận xét vòng đầu từ máy chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tình trạng vòng đầu'), findsOneWidget);
    expect(repository.calls.last, 'head');
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing data explains what is needed without a diagnosis', (
    tester,
  ) async {
    final repository = SummaryRepository()
      ..bmi = {'current': null, 'missingMetric': 'height'}
      ..head = {'current': null};
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Cần thêm chiều dài/cao phù hợp để có nhận xét.'),
      findsOneWidget,
    );
    expect(
      find.text('Cần thêm số đo vòng đầu để có nhận xét.'),
      findsOneWidget,
    );
    expect(find.text('Chưa tải được số đo.'), findsNothing);
  });

  testWidgets(
    'assessment failure does not hide measurements or other summary',
    (tester) async {
      final repository = SummaryRepository()..failHead = true;
      await tester.pumpWidget(
        MaterialApp(home: GrowthOverview(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhận xét cân nặng từ máy chủ'), findsOneWidget);
      expect(
        find.text('Chưa tải được nhận xét. Nhấn để thử lại.'),
        findsOneWidget,
      );
      expect(find.text('Chưa tải được số đo.'), findsNothing);
      expect(find.text('Cân nặng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending summary leaves measurements and other summary readable',
    (tester) async {
      final repository = SummaryRepository()
        ..pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(home: GrowthOverview(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đang tải nhận xét…'), findsOneWidget);
      expect(find.text('Nhận xét vòng đầu từ máy chủ'), findsOneWidget);
      repository.pending!.complete({
        'current': {'summary': 'Nhận xét mới'},
      });
      await tester.pumpAndSettle();
      expect(find.text('Nhận xét mới'), findsOneWidget);
      expect(repository.calls, ['bmi', 'head']);
    },
  );
}
