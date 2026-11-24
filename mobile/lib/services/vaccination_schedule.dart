import 'dart:convert';

import '../models/vaccination.dart';
import 'vaccine_schedule_snapshot.dart';

/// Catalog + schedule in use: the backend copy (managed in the web admin) once
/// loaded, otherwise the bundled snapshot of the same endpoint.
VaccineCatalog get vaccineCatalog => _catalog ??= bundledVaccineCatalog;
VaccineCatalog? _catalog;

/// Optional callback invoked whenever [applyVaccineCatalog] updates [vaccineCatalog].
void Function()? onVaccineCatalogChanged;

final bundledVaccineCatalog = VaccineCatalog.fromJson(
  jsonDecode(vaccineScheduleSnapshot) as Map<String, dynamic>,
);

final RegExp _corruptedDiacriticsPattern = RegExp(
  r'[A-Za-zÀ-ỹ]\?[A-Za-zÀ-ỹ]|\?[A-Za-zÀ-ỹ]|[A-Za-zÀ-ỹ]\?(?=\s|$|[.,;)\]])|\?\?',
);

final RegExp _nonAsciiPattern = RegExp(r'[^\x00-\x7F]');

String _toAsciiQMarkMask(String text) =>
    text.replaceAll(_nonAsciiPattern, '?');

final Map<String, String> _knownCorruptedStrings = () {
  final map = <String, String>{};
  void register(String? clean) {
    if (clean == null || clean.isEmpty) return;
    final masked = _toAsciiQMarkMask(clean);
    if (masked != clean) {
      map[masked] = clean;
      // Also register without parenthetical suffix, e.g. "Bại liệt tiêm" from "Bại liệt tiêm (IPV)"
      final parenIdx = clean.indexOf(' (');
      if (parenIdx > 0) {
        final prefix = clean.substring(0, parenIdx);
        final maskedPrefix = _toAsciiQMarkMask(prefix);
        if (maskedPrefix != prefix) map[maskedPrefix] = prefix;
      }
    }
  }

  for (final v in bundledVaccineCatalog.vaccines) {
    register(v.name);
    register(v.prevents);
    register(v.description);
    register(v.choiceLabel);
    for (final p in v.products) {
      register(p.name);
      register(p.origin);
    }
  }
  for (final d in bundledVaccineCatalog.doses) {
    register(d.name);
    register(d.prevents);
    register(d.doseLabel);
    register(d.note);
  }
  for (var i = 1; i <= 10; i++) {
    register('Mũi $i');
    register('Liều $i');
    register('Nhắc hằng năm · lần $i');
  }
  register('Mũi tiêm');
  register('Mũi duy nhất');
  register('Liều duy nhất');
  register('Liều sơ sinh');
  register('Nhắc lại');
  return map;
}();

/// Returns true if [value] contains ASCII `?` replacement corruption where
/// Vietnamese diacritics should be (e.g. `"B?i li?t ti?m"`).
bool hasCorruptedVietnameseText(String? value) =>
    value != null &&
    value.contains('?') &&
    (_corruptedDiacriticsPattern.hasMatch(value) ||
        _knownCorruptedStrings.containsKey(value));

String _cleanText(String? candidate, [String? fallback]) {
  if (candidate == null) return fallback ?? '';
  if (!hasCorruptedVietnameseText(candidate)) return candidate;
  final exact = _knownCorruptedStrings[candidate];
  if (exact != null) return exact;
  if (fallback != null && !hasCorruptedVietnameseText(fallback)) {
    return fallback;
  }
  return candidate;
}

String? _cleanNullableText(String? candidate, [String? fallback]) {
  if (candidate == null) return null;
  if (!hasCorruptedVietnameseText(candidate)) return candidate;
  return _knownCorruptedStrings[candidate] ?? fallback;
}

/// Repairs any fields in [catalog] that suffered ASCII `?` diacritic corruption
/// by falling back to the clean UTF-8 strings in [bundledVaccineCatalog].
VaccineCatalog sanitizeVaccineCatalog(VaccineCatalog catalog) {
  final bundledVaccinesByCode = {
    for (final v in bundledVaccineCatalog.vaccines) v.code: v,
  };
  final bundledDosesById = {
    for (final d in bundledVaccineCatalog.doses) d.id: d,
  };

  final cleanVaccines = <VaccineInfo>[
    for (final v in catalog.vaccines)
      () {
        final fb = bundledVaccinesByCode[v.code];
        if (fb == null) return v;
        final fbProducts = {for (final p in fb.products) p.code: p};
        return VaccineInfo(
          code: v.code,
          name: _cleanText(v.name, fb.name),
          prevents: _cleanText(v.prevents, fb.prevents),
          isTcmr: v.isTcmr,
          description: _cleanNullableText(v.description, fb.description),
          choiceGroup: v.choiceGroup,
          choiceOption: v.choiceOption,
          choiceLabel: _cleanNullableText(v.choiceLabel, fb.choiceLabel),
          choiceDefault: v.choiceDefault,
          products: [
            for (final p in v.products)
              VaccineProduct(
                code: p.code,
                name: _cleanText(p.name, fbProducts[p.code]?.name),
                origin: _cleanNullableText(
                  p.origin,
                  fbProducts[p.code]?.origin,
                ),
                doseCount: p.doseCount,
              ),
          ],
        );
      }(),
  ];

  final cleanVaccinesByCode = {for (final v in cleanVaccines) v.code: v};

  final cleanDoses = <VaccineDose>[
    for (final d in catalog.doses)
      () {
        final fbDose = bundledDosesById[d.id];
        final cleanVaccine = cleanVaccinesByCode[d.vaccineCode];
        return VaccineDose(
          id: d.id,
          name: _cleanText(d.name, cleanVaccine?.name ?? fbDose?.name),
          prevents: _cleanText(
            d.prevents,
            cleanVaccine?.prevents ?? fbDose?.prevents,
          ),
          doseLabel: _cleanText(d.doseLabel, fbDose?.doseLabel),
          ageMonths: d.ageMonths,
          offsetDays: d.offsetDays,
          ageWeeks: d.ageWeeks,
          afterDoseId: d.afterDoseId,
          minIntervalDays: d.minIntervalDays,
          repeatEveryMonths: d.repeatEveryMonths,
          repeatUntilMonths: d.repeatUntilMonths,
          occurrence: d.occurrence,
          vaccineCode: d.vaccineCode,
          doseNumber: d.doseNumber,
          isTcmr: d.isTcmr,
          note: _cleanNullableText(d.note, fbDose?.note),
          scheduledDate: d.scheduledDate,
          appointmentPlace: d.appointmentPlace,
          groupId: d.groupId,
        );
      }(),
  ];

  return VaccineCatalog(vaccines: cleanVaccines, doses: cleanDoses);
}

/// Sanitizes a raw vaccination record map (from local storage or remote API)
/// against [vaccineCatalog] / [bundledVaccineCatalog].
Map<String, dynamic> sanitizeVaccinationEntry(Map<String, dynamic> entry) {
  final id = entry['id'] as String?;
  if (id == null) return entry;
  final baseId = id.split('@').first;
  VaccineDose? refDose;
  for (final d in vaccineCatalog.doses) {
    if (d.id == baseId) {
      refDose = d;
      break;
    }
  }
  if (refDose == null) {
    for (final d in bundledVaccineCatalog.doses) {
      if (d.id == baseId) {
        refDose = d;
        break;
      }
    }
  }
  final name = entry['name'] as String?;
  final prevents = entry['prevents'] as String?;
  final doseLabel = entry['doseLabel'] as String?;
  final note = entry['note'] as String?;
  if (!hasCorruptedVietnameseText(name) &&
      !hasCorruptedVietnameseText(prevents) &&
      !hasCorruptedVietnameseText(doseLabel) &&
      !hasCorruptedVietnameseText(note)) {
    return entry;
  }
  return <String, dynamic>{
    ...entry,
    if (name != null) 'name': _cleanText(name, refDose?.name),
    if (prevents != null) 'prevents': _cleanText(prevents, refDose?.prevents),
    if (doseLabel != null)
      'doseLabel': _cleanText(doseLabel, refDose?.doseLabel ?? 'Mũi tiêm'),
    if (note != null) 'note': _cleanText(note, refDose?.note ?? ''),
  };
}

/// Replaces the catalog with the backend copy; an empty schedule keeps the current one.
void applyVaccineCatalog(VaccineCatalog catalog) {
  if (catalog.doses.isNotEmpty) {
    _catalog = sanitizeVaccineCatalog(catalog);
    onVaccineCatalogChanged?.call();
  }
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
  final dosesById = {for (final d in c.doses) d.id: d};
  final records = <String, VaccinationRecord>{
    for (final raw in entries)
      if (raw['given'] == true)
        raw['id'] as String: () {
          final e = sanitizeVaccinationEntry(raw);
          final baseId = (e['id'] as String).split('@').first;
          final refDose = dosesById[baseId];
          return VaccinationRecord(
            childId: childId,
            doseId: e['id'] as String,
            date: DateTime.parse(e['date'] as String),
            place: e['place'] as String? ?? '',
            reaction: e['reaction'] as String? ?? '',
            note: _cleanText(e['note'] as String?, refDose?.note ?? ''),
            product: e['product'] as String?,
            scheduledDate: DateTime.tryParse(
              e['scheduledDate'] as String? ?? '',
            ),
            appointmentPlace: e['appointmentPlace'] as String? ?? '',
          );
        }(),
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

  for (final raw in entries.where((e) => e['custom'] == true)) {
    final e = sanitizeVaccinationEntry(raw);
    final date = DateTime.parse(e['date'] as String);
    final dose = VaccineDose(
      id: e['id'] as String,
      name: _cleanText(e['name'] as String?),
      prevents: _cleanText(e['prevents'] as String? ?? ''),
      doseLabel: _cleanText(e['doseLabel'] as String? ?? 'Mũi tiêm', 'Mũi tiêm'),
      ageMonths: VaccineDose.monthsBetween(birth, date),
      isTcmr: false,
      scheduledDate: date,
      note: _cleanNullableText(e['note'] as String?),
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
