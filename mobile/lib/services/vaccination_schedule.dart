import 'dart:convert';

import '../models/vaccination.dart';
import 'vaccine_schedule_snapshot.dart';

/// Catalog + schedule in use: the backend copy (managed in the web admin) once
/// loaded, otherwise the bundled snapshot of the same endpoint.
VaccineCatalog get vaccineCatalog => _catalog ??= bundledVaccineCatalog;
VaccineCatalog? _catalog;

final bundledVaccineCatalog = VaccineCatalog.fromJson(
  jsonDecode(vaccineScheduleSnapshot) as Map<String, dynamic>,
);

/// Replaces the catalog with the backend copy; an empty schedule keeps the current one.
void applyVaccineCatalog(VaccineCatalog catalog) {
  if (catalog.doses.isNotEmpty) _catalog = catalog;
}

/// Repeats stop after this many occurrences even if `repeatUntilMonths` is far away.
const _maxOccurrences = 30;

/// Which vaccines this child follows.
///
/// - An explicit plan wins (`false` = parent chose not to give it), except that a
///   vaccine with recorded doses is always shown.
/// - Within a choice group, the child follows one option: the one chosen
///   explicitly, else the one with recorded doses, else the default option.
/// - Other vaccines are followed by default (TCMR and dịch vụ alike).
Set<String> includedVaccines(
  VaccineCatalog catalog,
  Set<String> recordedVaccines,
  Map<String, bool> plans,
) {
  final chosen = <String, String>{};
  void choose(bool Function(VaccineInfo v) picks) {
    for (final v in catalog.vaccines) {
      if (v.choiceGroup != null &&
          !chosen.containsKey(v.choiceGroup) &&
          picks(v)) {
        chosen[v.choiceGroup!] = v.choiceOption!;
      }
    }
  }

  choose((v) => plans[v.code] == true);
  choose((v) => recordedVaccines.contains(v.code));
  choose((v) => v.choiceDefault);
  return {
    for (final v in catalog.vaccines)
      if (recordedVaccines.contains(v.code) ||
          (plans[v.code] != false &&
              (v.choiceGroup == null ||
                  chosen[v.choiceGroup] == v.choiceOption)))
        v.code,
  };
}

/// Plan changes that make the child follow [option] of [group] (and only it).
Map<String, bool> choosePlanOption(
  VaccineCatalog catalog,
  String group,
  String option,
) => {
  for (final v in catalog.vaccines)
    if (v.choiceGroup == group) v.code: v.choiceOption == option,
};

/// The child's vaccination book: scheduled doses with computed due dates plus
/// doses the parent added. [entries] use the DemoStore.vaccinations map shape.
List<ScheduledVaccine> buildVaccinationSchedule({
  required String childId,
  required DateTime dob,
  required List<Map<String, dynamic>> entries,
  Map<String, bool> plans = const {},
  VaccineCatalog? catalog,
  required DateTime today,
}) {
  final c = catalog ?? vaccineCatalog;
  final birth = DateTime(dob.year, dob.month, dob.day);
  final records = <String, VaccinationRecord>{
    for (final e in entries)
      if (e['given'] == true)
        e['id'] as String: VaccinationRecord(
          childId: childId,
          doseId: e['id'] as String,
          date: DateTime.parse(e['date'] as String),
          place: e['place'] as String? ?? '',
          reaction: e['reaction'] as String? ?? '',
          note: e['note'] as String? ?? '',
          product: e['product'] as String?,
          scheduledDate: DateTime.tryParse(e['scheduledDate'] as String? ?? ''),
          appointmentPlace: e['appointmentPlace'] as String? ?? '',
        ),
  };
  // Lịch hẹn bố mẹ đặt cho mũi trong lịch, chưa tiêm: thay ngày dự kiến
  final appointments = <String, (DateTime, String, String?)>{
    for (final e in entries)
      if (e['given'] != true && e['custom'] != true)
        e['id'] as String: (
          DateTime.parse(e['date'] as String),
          e['place'] as String? ?? '',
          e['product'] as String?,
        ),
  };
  final dosesById = {for (final d in c.doses) d.id: d};
  final recorded = <String>{};
  final doseLimit = <String, int>{};
  for (final e in entries.where((e) => e['custom'] != true)) {
    final dose = dosesById[(e['id'] as String).split('@').first];
    if (dose?.vaccineCode == null) continue;
    recorded.add(dose!.vaccineCode!);
    final count = c
        .vaccine(dose.vaccineCode)
        ?.product(e['product'] as String?)
        ?.doseCount;
    if (count != null) doseLimit[dose.vaccineCode!] = count;
  }
  final included = includedVaccines(c, recorded, plans);

  // Ngày dự kiến theo lịch (bỏ qua lịch hẹn của chính mũi này); mũi trước thì
  // lấy ngày tiêm thực tế, rồi đến ngày hẹn, rồi ngày dự kiến của nó.
  final due = <String, DateTime>{};
  DateTime resolve(VaccineDose dose, [Set<String> visiting = const {}]) {
    final known = due[dose.id];
    if (known != null) return known;
    var date = dose.dueDate(birth);
    final previous = dosesById[dose.afterDoseId];
    if (previous != null && !visiting.contains(dose.id)) {
      final from =
          records[previous.id]?.date ??
          appointments[previous.id]?.$1 ??
          resolve(previous, {...visiting, dose.id});
      final earliest = DateTime(
        from.year,
        from.month,
        from.day + (dose.minIntervalDays ?? 0),
      );
      if (earliest.isAfter(date)) date = earliest;
    }
    return due[dose.id] = date;
  }

  ScheduledVaccine scheduled(
    VaccineDose dose,
    DateTime date, {
    DateTime? appointment,
    String appointmentPlace = '',
  }) {
    final record = records[dose.id];
    final booked = appointments[dose.id];
    final due = booked?.$1 ?? date;
    return ScheduledVaccine(
      dose: dose,
      dueDate: due,
      record: record,
      status: ScheduledVaccine.statusFor(due, record, today),
      appointmentDate: record?.scheduledDate ?? booked?.$1 ?? appointment,
      appointmentPlace: record != null
          ? record.appointmentPlace
          : booked?.$2 ?? appointmentPlace,
      expectedDate: date,
      plannedProduct: record == null ? booked?.$3 : null,
    );
  }

  final result = <ScheduledVaccine>[];
  for (final dose in c.doses) {
    final code = dose.vaccineCode;
    final hasRecord = records.containsKey(dose.id);
    if (!hasRecord && !included.contains(code)) continue;
    if (!hasRecord && dose.doseNumber > (doseLimit[code] ?? 1 << 30)) continue;
    var date = resolve(dose);
    result.add(scheduled(dose, date));
    final every = dose.repeatEveryMonths;
    if (every == null) continue;
    final until = dose.repeatUntilMonths ?? 72;
    for (var n = 1; n <= _maxOccurrences; n++) {
      final previousId = n == 1 ? dose.id : '${dose.id}@${n - 1}';
      final from =
          records[previousId]?.date ?? appointments[previousId]?.$1 ?? date;
      date = DateTime(from.year, from.month + every, from.day);
      if (VaccineDose.monthsBetween(birth, date) > until) break;
      result.add(
        scheduled(
          dose.copyWith(
            id: '${dose.id}@$n',
            doseLabel: '${dose.doseLabel} · lần ${n + 1}',
            ageMonths: VaccineDose.monthsBetween(birth, date),
            occurrence: n,
          ),
          date,
        ),
      );
    }
  }

  for (final e in entries.where((e) => e['custom'] == true)) {
    final date = DateTime.parse(e['date'] as String);
    final dose = VaccineDose(
      id: e['id'] as String,
      name: e['name'] as String,
      prevents: e['prevents'] as String? ?? '',
      doseLabel: e['doseLabel'] as String? ?? 'Mũi tiêm',
      ageMonths: VaccineDose.monthsBetween(birth, date),
      isTcmr: false,
      scheduledDate: date,
      note: e['note'] as String?,
      appointmentPlace: e['place'] as String? ?? '',
      groupId: e['groupId'] as String?,
    );
    // Mũi tự thêm chưa tiêm: ngày của mũi chính là ngày hẹn
    result.add(
      scheduled(
        dose,
        date,
        appointment: e['given'] == true ? null : date,
        appointmentPlace: e['given'] == true ? '' : dose.appointmentPlace,
      ),
    );
  }
  return result..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}
