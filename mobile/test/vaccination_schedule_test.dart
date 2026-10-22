import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/models/vaccination.dart';
import 'package:track_children/services/vaccination_schedule.dart';

void main() {
  final dob = DateTime(2025, 1, 10);
  final today = DateTime(2026, 10, 19);

  List<ScheduledVaccine> build({
    List<Map<String, dynamic>> entries = const [],
    Map<String, bool> plans = const {},
  }) => buildVaccinationSchedule(
    childId: 'c',
    dob: dob,
    entries: entries,
    plans: plans,
    catalog: bundledVaccineCatalog,
    today: today,
  );

  Map<String, dynamic> given(String id, DateTime date, [String? product]) => {
    'id': id,
    'given': true,
    'date': date.toIso8601String(),
    'product': ?product,
  };

  Set<String> ids(List<ScheduledVaccine> s) => {for (final v in s) v.dose.id};

  test('default plan: TCMR options plus service vaccines', () {
    final s = ids(build());
    expect(
      s,
      containsAll(['bcg', '5in1-1', 'polio-1', 'ipv-1', 'dpt-booster']),
    );
    expect(
      s,
      containsAll(['je-1', 'je-4', 'pcv-1', 'rsv-1', 'acyw-1', 'menb-1']),
    );
    expect(s, isNot(contains('6in1-1')));
    expect(s, isNot(contains('imojev-1')));
    expect(s, isNot(contains('menactra-1')));
    expect(s, contains('rota-3'));
  });

  test('choosing 6 trong 1 replaces the TCMR DTP option', () {
    final plans = choosePlanOption(bundledVaccineCatalog, 'dtp', '6in1');
    final s = ids(build(plans: plans));
    expect(s, containsAll(['6in1-1', '6in1-4']));
    expect(
      s.intersection({'5in1-1', 'polio-1', 'ipv-1', 'dpt-booster'}),
      isEmpty,
    );
  });

  test('a recorded dose selects its option and is never hidden', () {
    final s = ids(
      build(
        entries: [given('imojev-1', DateTime(2025, 10, 10))],
        plans: {'imojev': false},
      ),
    );
    expect(s, contains('imojev-1'));
    expect(s, isNot(contains('je-1')));
  });

  test('parent can stop following a service vaccine', () {
    expect(ids(build(plans: {'dengue': false})), isNot(contains('dengue-1')));
  });

  test('product dose count drops extra doses (Rotarix = 2 liều)', () {
    final s = ids(
      build(entries: [given('rota-1', DateTime(2025, 2, 21), 'rotarix')]),
    );
    expect(s, containsAll(['rota-1', 'rota-2']));
    expect(s, isNot(contains('rota-3')));
  });

  test('weeks and intervals from the previous dose', () {
    final s = build(entries: [given('pcv-1', DateTime(2025, 3, 20))]);
    final pcv1 = s.firstWhere((v) => v.dose.id == 'pcv-1');
    expect(pcv1.dose.ageLabel, '6 tuần');
    final acyw1 = s.firstWhere((v) => v.dose.id == 'acyw-1');
    expect(acyw1.dueDate, DateTime(2025, 2, 21)); // ngày sinh + 42 ngày
    // pcv-2: 3 tháng tuổi (10/4) nhưng phải >= 28 ngày sau mũi 1 (20/3 + 28 = 17/4)
    expect(
      s.firstWhere((v) => v.dose.id == 'pcv-2').dueDate,
      DateTime(2025, 4, 17),
    );
  });

  test('yearly flu booster repeats until 6 years old', () {
    final s = build(entries: [given('flu-yearly', DateTime(2026, 9, 1))]);
    final flu = s.where((v) => v.dose.baseId == 'flu-yearly').toList();
    expect(flu.first.record, isNotNull);
    expect(flu[1].dose.id, 'flu-yearly@1');
    expect(flu[1].dueDate, DateTime(2027, 9, 1));
    expect(flu[1].dose.doseLabel, 'Nhắc hằng năm · lần 2');
    expect(
      flu.every((v) => VaccineDose.monthsBetween(dob, v.dueDate) <= 72),
      isTrue,
    );
    expect(flu.length, 5); // 2026, 2027 … 2030 (bé tròn 6 tuổi 10/1/2031)
  });

  test('an appointment replaces the expected date and moves later doses', () {
    final s = build(
      entries: [
        {
          'id': 'pcv-1',
          'given': false,
          'date': DateTime(2025, 3, 25).toIso8601String(),
          'place': 'VNVC',
        },
      ],
    );
    final pcv1 = s.firstWhere((v) => v.dose.id == 'pcv-1');
    expect(pcv1.hasAppointment, isTrue);
    expect(pcv1.dueDate, DateTime(2025, 3, 25));
    expect(pcv1.expectedDate, DateTime(2025, 2, 21));
    expect(pcv1.appointmentPlace, 'VNVC');
    expect(pcv1.plannedDate, DateTime(2025, 3, 25));
    // pcv-2 >= 28 ngày sau lịch hẹn của mũi 1
    expect(
      s.firstWhere((v) => v.dose.id == 'pcv-2').dueDate,
      DateTime(2025, 4, 22),
    );
  });

  test(
    'a given dose keeps its scheduled date, else uses the expected date',
    () {
      final s = build(
        entries: [
          {
            'id': 'pcv-1',
            'given': true,
            'date': DateTime(2025, 3, 27).toIso8601String(),
            'scheduledDate': DateTime(2025, 3, 25).toIso8601String(),
          },
        ],
      );
      final pcv1 = s.firstWhere((v) => v.dose.id == 'pcv-1');
      expect(pcv1.record!.daysFromSchedule, 2); // trễ 2 ngày
      expect(pcv1.plannedDate, DateTime(2025, 3, 25));
      // Chưa từng hẹn: ghi nhận sẽ lưu ngày dự kiến làm ngày hẹn
      final bcg = s.firstWhere((v) => v.dose.id == 'bcg');
      expect(bcg.plannedDate, dob);
    },
  );

  test('custom doses stay in the book', () {
    final s = build(
      entries: [
        {
          'id': 'custom-1-0',
          'custom': true,
          'name': 'Dại',
          'given': false,
          'date': DateTime(2026, 11, 1).toIso8601String(),
        },
      ],
    );
    final custom = s.firstWhere((v) => v.dose.id == 'custom-1-0');
    expect(custom.dose.isCustom, isTrue);
    expect(custom.dueDate, DateTime(2026, 11, 1));
  });
}
