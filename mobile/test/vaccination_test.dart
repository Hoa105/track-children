import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/features/vaccination/vaccination_screen.dart';
import 'package:track_children/features/vaccination/vaccination_details.dart';
import 'package:track_children/features/vaccination/supplement_vaccine_editor.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
  });

  test(
    'records persist, remain isolated and reject future administration',
    () async {
      final store = DemoStore.instance;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final record = <String, dynamic>{
        'id': 'bcg',
        'custom': false,
        'given': true,
        'date': today.toIso8601String(),
        'place': 'Điểm tiêm thử nghiệm',
      };
      await store.saveVaccination('child_an', record);
      expect(
        vaccinationSchedule('child_an').where((v) => v.record != null),
        hasLength(1),
      );
      expect(store.vaccinations('child_linh'), isEmpty);
      final reloaded = DemoStore();
      await reloaded.initialize();
      expect(
        reloaded.vaccinations('child_an').single['place'],
        'Điểm tiêm thử nghiệm',
      );
      expect(
        () => store.saveVaccination('child_an', {
          ...record,
          'date': today.add(const Duration(days: 1)).toIso8601String(),
        }),
        throwsArgumentError,
      );
      await store.removeVaccination('child_an', 'bcg');
      expect(store.vaccinations('child_an'), isEmpty);
      await store.logout();
      await store.login('bo@trackchildren.vn', DemoStore.password);
      expect(() => store.saveVaccination('child_an', record), throwsStateError);
    },
  );

  test('batch validation rejects all records if one date is invalid', () async {
    final store = DemoStore.instance;
    final today = DateUtils.dateOnly(DateTime.now());
    final base = <String, dynamic>{
      'custom': true,
      'given': true,
      'name': 'Bổ sung',
      'prevents': '',
      'doseLabel': 'Mũi 1',
      'groupId': 'test-group',
    };
    expect(
      () => store.saveVaccinations('child_an', [
        {...base, 'id': 'custom-batch-1', 'date': today.toIso8601String()},
        {
          ...base,
          'id': 'custom-batch-2',
          'date': today.add(const Duration(days: 1)).toIso8601String(),
        },
      ]),
      throwsArgumentError,
    );
    expect(store.vaccinations('child_an'), isEmpty);
  });

  testWidgets(
    'supplement saves multiple doses with independent dates and statuses',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vaccination-add')));
      await tester.pumpAndSettle();
      expect(find.text('Thêm vắc-xin bổ sung'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Vắc-xin thử nhiều mũi',
      );
      tester.testTextInput.hide();
      await tester.tap(find.text('Ngày tiêm'));
      await tester.pumpAndSettle();
      final first = DateUtils.dateOnly(DateTime.now())
          .subtract(const Duration(days: 10));
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('supplement-add-dose')),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('supplement-add-dose')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dự kiến').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dự kiến').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ngày dự kiến'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ngày dự kiến'));
      await tester.pumpAndSettle();
      final second = DateUtils.dateOnly(DateTime.now())
          .add(const Duration(days: 7));
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(second);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu 2 mũi tiêm'));
      await tester.pumpAndSettle();
      final entries = DemoStore.instance.vaccinations('child_an');
      expect(entries, hasLength(2));
      expect(entries.map((e) => e['groupId']).toSet(), hasLength(1));
      expect(entries.map((e) => e['id']).toSet(), hasLength(2));
      expect(entries.first['date'], first.toIso8601String());
      expect(entries.last['date'], second.toIso8601String());
      expect(entries.first['given'], true);
      expect(entries.last['given'], false);
      expect(DemoStore.instance.vaccinations('child_linh'), isEmpty);
      final reload = DemoStore();
      await reload.initialize();
      expect(reload.vaccinations('child_an'), hasLength(2));
      await tester.tap(find.text('Vắc-xin'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Vắc-xin thử nhiều mũi'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Vắc-xin thử nhiều mũi')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vắc-xin thử nhiều mũi'));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsWidgets);
      expect(find.text('Mũi 1'), findsOneWidget);
      expect(find.text('Mũi 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'supplement shares vaccine info and renumbers doses after removal',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vaccination-add')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Mũi'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên vaccine'),
        'Vắc-xin bổ sung thử',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phòng bệnh'),
        'Bệnh thử nghiệm',
      );
      tester.testTextInput.hide();
      for (var i = 0; i < 2; i++) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('supplement-add-dose')),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('supplement-add-dose')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byTooltip('Bỏ mũi 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bỏ mũi 2'));
      await tester.pumpAndSettle();
      expect(find.text('Mũi 2'), findsOneWidget);
      expect(find.text('Mũi 3'), findsNothing);
      await tester.tap(find.text('Lưu 2 mũi tiêm'));
      await tester.pumpAndSettle();
      final records = DemoStore.instance.vaccinations('child_an');
      expect(records.map((r) => r['doseLabel']).toList(), ['Mũi 1', 'Mũi 2']);
      expect(
        records.every(
          (r) =>
              r['name'] == 'Vắc-xin bổ sung thử' &&
              r['prevents'] == 'Bệnh thử nghiệm',
        ),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('supplement fills screen and swipe confirms unsaved changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    final height = tester.getSize(find.byType(VaccinationScreen)).height;
    await tester.tap(find.byKey(const ValueKey('vaccination-add')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SupplementVaccineEditor)).height, height);
    final header = find.byKey(const ValueKey('supplement-drag-header'));
    await tester.drag(header, const Offset(0, 140));
    await tester.pumpAndSettle();
    expect(find.byType(SupplementVaccineEditor), findsNothing);
    await tester.tap(find.byKey(const ValueKey('vaccination-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên vaccine'),
      'Chưa lưu',
    );
    tester.testTextInput.hide();
    await tester.drag(header, const Offset(0, 140));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu'), findsOneWidget);
    await tester.drag(header, const Offset(0, 140));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.byType(SupplementVaccineEditor), findsNothing);
    expect(DemoStore.instance.vaccinations('child_an'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 768.0]) {
    testWidgets('vaccination layout and add form at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const VaccinationScreen(childId: 'child_an'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sổ tiêm chủng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Thêm'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tên vaccine'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Tên vaccine'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Vaccine thử nghiệm',
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Lưu mũi tiêm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu mũi tiêm'));
      await tester.pumpAndSettle();
      expect(
        DemoStore.instance.vaccinations('child_an').single['name'],
        'Vaccine thử nghiệm',
      );
      expect(
        DemoStore.instance.vaccinations('child_an').single['custom'],
        true,
      );
      expect(DemoStore.instance.vaccinations('child_an').single['given'], true);
      expect(find.text('Sổ tiêm chủng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('visits group and edit only the current child without a picker', (
    tester,
  ) async {
    final store = DemoStore.instance;
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day).toIso8601String();
    for (final id in ['bcg', 'hepb-0']) {
      await store.saveVaccination('child_an', {
        'id': id,
        'custom': false,
        'given': true,
        'date': date,
        'place': 'Trạm y tế',
        'reaction': 'Không ghi nhận phản ứng',
        'note': '',
      });
    }
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã tiêm').last);
    await tester.pumpAndSettle();
    expect(find.text('2 mũi · 1 buổi tiêm'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('BCG'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('BCG')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCG'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Phản ứng: Không ghi nhận phản ứng').last,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Phản ứng: Không ghi nhận phản ứng'), findsWidgets);
    await tester.ensureVisible(find.text('Sửa thông tin'));
    await tester.tap(find.text('Sửa thông tin'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thêm thông tin'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Thêm thông tin'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nơi tiêm'),
      'Cơ sở mới',
    );
    await tester.tap(find.text('Lưu mũi tiêm'));
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('2 mũi · 2 buổi tiêm'), findsOneWidget);
    expect(find.text('Bảo An'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Sổ tiêm của bé nào?'), findsNothing);
    expect(find.text('Gia Linh'), findsNothing);
    expect(find.byIcon(Icons.unfold_more_rounded), findsNothing);
    expect(store.child!['id'], 'child_an');
    expect(store.vaccinations('child_an'), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('add action remains available while scrolling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Thêm'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('vaccination-add')));
    await tester.pumpAndSettle();
    expect(find.text('Thêm vắc-xin bổ sung'), findsOneWidget);
    expect(find.text('Thêm lịch hẹn'), findsNothing);
    await tester.tap(find.byTooltip('Đóng biểu mẫu'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Thêm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing appointment can still be marked given', (tester) async {
    await DemoStore.instance.saveVaccination('child_an', {
      'id': 'custom-appointment',
      'custom': true,
      'given': false,
      'name': 'Lịch hẹn thử nghiệm',
      'prevents': '',
      'doseLabel': 'Mũi 1',
      'date': DateUtils.dateOnly(DateTime.now()).toIso8601String(),
    });
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Theo tuổi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Theo tuổi'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Lịch hẹn thử nghiệm'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.textContaining('Lịch hẹn thử nghiệm').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Lịch hẹn thử nghiệm').last);
    await tester.pumpAndSettle();
    expect(find.text('Sửa lịch hẹn'), findsWidgets);
    final appointmentId = DemoStore.instance
        .vaccinations('child_an')
        .single['id'];
    await Scrollable.ensureVisible(
      tester.element(find.text('Ghi nhận đã tiêm')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi nhận đã tiêm'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu mũi tiêm'), findsOneWidget);
    await tester.tap(find.text('Lưu mũi tiêm'));
    await tester.pumpAndSettle();
    final given = DemoStore.instance.vaccinations('child_an').single;
    expect(given['id'], appointmentId);
    expect(given['given'], true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save stays above keyboard in a narrow sheet', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tên vaccine'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Mũi thử bàn phím',
    );
    expect(tester.getBottomLeft(find.text('Lưu mũi tiêm')).dy, lessThan(500));
    await tester.tap(find.text('Lưu mũi tiêm'));
    await tester.pumpAndSettle();
    expect(
      DemoStore.instance.vaccinations('child_an').single['name'],
      'Mũi thử bàn phím',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recording from a milestone updates the scheduled dose without duplicates',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('all-age-milestones')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sơ sinh'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('BCG'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghi nhận đã tiêm'));
      await tester.pumpAndSettle();
      expect(find.text('Lưu mũi tiêm'), findsOneWidget);
      await tester.tap(find.text('Lưu mũi tiêm'));
      await tester.pumpAndSettle();
      final entry = DemoStore.instance.vaccinations('child_an').single;
      expect(entry['id'], 'bcg');
      expect(entry['custom'], false);
      expect(
        vaccinationSchedule('child_an').where((v) => v.dose.id == 'bcg'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing a changed form confirms and can resume or discard', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Chưa lưu');
    await tester.tap(find.byTooltip('Đóng biểu mẫu'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.byType(VaccineEditorScreen), findsNothing);
    expect(DemoStore.instance.vaccinations('child_an'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vaccine editor uses compact height for a scheduled dose', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaccineEditorScreen(
            childId: 'child_an',
            vaccine: vaccinationSchedule('child_an').first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(VaccineEditorScreen)).height,
      lessThan(630),
    );
    expect(find.text('Phòng bệnh: Lao'), findsNothing);
    expect(find.text('Lưu mũi tiêm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short dose detail sizes to content', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaccineDetailSheet(
            vaccine: vaccinationSchedule('child_an').first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(VaccineDetailSheet)).height,
      lessThan(630),
    );
    expect(find.text('Phòng bệnh: Lao'), findsNothing);
    await tester.tap(find.text('Phòng bệnh & ghi chú'));
    await tester.pumpAndSettle();
    expect(find.text('Phòng bệnh: Lao'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dose detail supports large text and a fixed action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);
    final vaccine = vaccinationSchedule('child_an').first;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: VaccineDetailSheet(vaccine: vaccine)),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.text('Ghi nhận đã tiêm');
    expect(action, findsOneWidget);
    final before = tester.getCenter(action);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(action), before);
    expect(tester.getBottomRight(action).dy, lessThan(900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('age progress excludes custom doses and future milestones', (
    tester,
  ) async {
    final store = DemoStore.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final total = vaccinationSchedule('child_an')
        .where((v) => !v.dueDate.isAfter(today))
        .length;
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('age-progress'))).data,
      '0/$total',
    );
    await store.saveVaccination('child_an', {
      'id': 'custom-progress',
      'custom': true,
      'given': true,
      'name': 'Ngoài lịch',
      'prevents': '',
      'doseLabel': 'Mũi 1',
      'date': today.toIso8601String(),
    });
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('age-progress'))).data,
      '0/$total',
    );
    await store.saveVaccination('child_an', {
      'id': 'bcg',
      'custom': false,
      'given': true,
      'date': today.toIso8601String(),
    });
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('age-progress'))).data,
      '1/$total',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('vaccine progress opens all doses and prevention details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vắc-xin'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Vaccine 5 trong 1'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Vaccine 5 trong 1')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaccine 5 trong 1'));
    await tester.pumpAndSettle();
    expect(find.text('Mũi 1'), findsOneWidget);
    expect(find.text('Mũi 2'), findsOneWidget);
    expect(find.textContaining('Phòng bệnh: Bạch hầu'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mũi 3'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Mũi 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all age milestones can be selected with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const VaccinationScreen(childId: 'child_an'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('all-age-milestones')),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('all-age-milestones')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('24 tháng'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 tháng'));
    await tester.pumpAndSettle();
    expect(find.text('Mốc 24 tháng'), findsOneWidget);
  });

  testWidgets('completed vaccine remains in vaccine progress', (tester) async {
    await DemoStore.instance.saveVaccination('child_an', {
      'id': 'bcg',
      'custom': false,
      'given': true,
      'date': DateUtils.dateOnly(DateTime.now()).toIso8601String(),
    });
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vắc-xin'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('BCG'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);
    expect(find.textContaining('Đã hoàn thành'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending doses appear once and completed doses move to history', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VaccinationScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('all-age-milestones')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sơ sinh'));
    await tester.pumpAndSettle();
    expect(find.text('BCG'), findsOneWidget);
    expect(find.text('Hẹn tiếp theo'), findsNothing);
    await tester.tap(find.text('Đã tiêm').last);
    await tester.pumpAndSettle();
    expect(find.text('BCG'), findsNothing);
    expect(find.text('Chưa ghi nhận mũi tiêm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
