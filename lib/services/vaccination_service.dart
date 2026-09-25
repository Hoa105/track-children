import '../models/child.dart';
import '../models/vaccination.dart';

abstract class VaccinationService {
  Future<List<ScheduledVaccine>> getSchedule(Child child);
  Future<void> saveRecord(VaccinationRecord record);
  Future<void> removeRecord(String childId, String doseId);

  /// Adds a dose outside the TCMR schedule. Pass [record] when it was already given.
  Future<void> addCustomDose(String childId, VaccineDose dose, {VaccinationRecord? record});
  Future<void> updateCustomDose(String childId, VaccineDose dose);
  Future<void> removeCustomDose(String childId, String doseId);
}

/// National expanded immunisation (TCMR) schedule — see
/// docs/tieu_chuan_tham_khao.md § 3.1. Must be re-checked against the
/// latest Bộ Y tế guidance before release.
const tcmrSchedule = [
  VaccineDose(id: 'bcg', name: 'BCG', prevents: 'Lao', doseLabel: 'Mũi duy nhất', ageMonths: 0, note: 'Tiêm trong 24 giờ đầu sau sinh (hoặc càng sớm càng tốt trong tháng đầu).'),
  VaccineDose(id: 'hepb-0', name: 'Viêm gan B sơ sinh', prevents: 'Viêm gan B', doseLabel: 'Liều sơ sinh', ageMonths: 0, note: 'Tiêm trong 24 giờ đầu sau sinh.'),
  VaccineDose(id: '5in1-1', name: 'Vaccine 5 trong 1', prevents: 'Bạch hầu, ho gà, uốn ván, viêm gan B, Hib', doseLabel: 'Mũi 1', ageMonths: 2),
  VaccineDose(id: 'polio-1', name: 'Bại liệt (OPV/IPV)', prevents: 'Bại liệt', doseLabel: 'Mũi 1', ageMonths: 2),
  VaccineDose(id: 'rota-1', name: 'Rotavirus', prevents: 'Tiêu chảy do Rotavirus', doseLabel: 'Liều 1', ageMonths: 2, note: 'Vaccine uống.'),
  VaccineDose(id: '5in1-2', name: 'Vaccine 5 trong 1', prevents: 'Bạch hầu, ho gà, uốn ván, viêm gan B, Hib', doseLabel: 'Mũi 2', ageMonths: 3),
  VaccineDose(id: 'polio-2', name: 'Bại liệt (OPV/IPV)', prevents: 'Bại liệt', doseLabel: 'Mũi 2', ageMonths: 3),
  VaccineDose(id: 'rota-2', name: 'Rotavirus', prevents: 'Tiêu chảy do Rotavirus', doseLabel: 'Liều 2', ageMonths: 3, note: 'Vaccine uống.'),
  VaccineDose(id: '5in1-3', name: 'Vaccine 5 trong 1', prevents: 'Bạch hầu, ho gà, uốn ván, viêm gan B, Hib', doseLabel: 'Mũi 3', ageMonths: 4),
  VaccineDose(id: 'polio-3', name: 'Bại liệt (OPV/IPV)', prevents: 'Bại liệt', doseLabel: 'Mũi 3', ageMonths: 4),
  VaccineDose(id: 'rota-3', name: 'Rotavirus', prevents: 'Tiêu chảy do Rotavirus', doseLabel: 'Liều 3', ageMonths: 4, note: 'Chỉ áp dụng với loại vaccine 3 liều.'),
  VaccineDose(id: 'measles-1', name: 'Sởi', prevents: 'Sởi', doseLabel: 'Mũi 1', ageMonths: 9),
  VaccineDose(id: 'je-1', name: 'Viêm não Nhật Bản B', prevents: 'Viêm não Nhật Bản', doseLabel: 'Mũi 1', ageMonths: 12, note: 'Theo lịch địa phương.'),
  VaccineDose(id: 'je-2', name: 'Viêm não Nhật Bản B', prevents: 'Viêm não Nhật Bản', doseLabel: 'Mũi 2', ageMonths: 12, offsetDays: 14, note: 'Theo lịch địa phương, 1–2 tuần sau mũi 1.'),
  VaccineDose(id: 'dpt-booster', name: 'Bạch hầu – ho gà – uốn ván', prevents: 'Bạch hầu, ho gà, uốn ván', doseLabel: 'Nhắc lại', ageMonths: 18),
  VaccineDose(id: 'mr', name: 'Sởi – Rubella (MR)', prevents: 'Sởi, Rubella', doseLabel: 'Nhắc lại', ageMonths: 18),
  VaccineDose(id: 'je-3', name: 'Viêm não Nhật Bản B', prevents: 'Viêm não Nhật Bản', doseLabel: 'Mũi 3', ageMonths: 24, note: 'Theo lịch địa phương, 1 năm sau mũi 2.'),
];

class MockVaccinationService implements VaccinationService {
  final List<VaccinationRecord> _records = [];
  final Map<String, List<VaccineDose>> _customDoses = {};
  final Set<String> _seededChildren = {};

  /// Demo data: c1 (~18 tháng) has everything up to 12 tháng, c2 (~5 tháng)
  /// has missed Rotavirus liều 2 & 3. Seeded lazily because dob is relative to now.
  void _seed(Child child) {
    if (!_seededChildren.add(child.id)) return;
    final maxMonths = switch (child.id) {
      'c1' => 12,
      'c2' => 4,
      _ => -1,
    };
    for (final dose in tcmrSchedule) {
      if (dose.ageMonths > maxMonths || (child.id == 'c2' && dose.id.startsWith('rota-') && dose.id != 'rota-1')) continue;
      _records.add(VaccinationRecord(
        childId: child.id,
        doseId: dose.id,
        date: dose.dueDate(child.dob).add(const Duration(days: 2)),
        place: 'Trạm y tế phường',
      ));
    }
  }

  @override
  Future<List<ScheduledVaccine>> getSchedule(Child child) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seed(child);
    final now = DateTime.now();
    // Custom doses slot in by age; the index tiebreak keeps TCMR order stable.
    final doses = [...tcmrSchedule, ...?_customDoses[child.id]];
    final order = {for (var i = 0; i < doses.length; i++) doses[i]: i};
    doses.sort((a, b) {
      final byAge = a.ageMonths.compareTo(b.ageMonths);
      return byAge != 0 ? byAge : order[a]!.compareTo(order[b]!);
    });
    return doses.map((dose) {
      final due = dose.dueDate(child.dob);
      final record = _records
          .where((r) => r.childId == child.id && r.doseId == dose.id)
          .firstOrNull;
      return ScheduledVaccine(
        dose: dose,
        dueDate: due,
        record: record,
        status: ScheduledVaccine.statusFor(due, record, now),
      );
    }).toList();
  }

  @override
  Future<void> saveRecord(VaccinationRecord record) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _records.removeWhere((r) => r.childId == record.childId && r.doseId == record.doseId);
    _records.add(record);
  }

  @override
  Future<void> removeRecord(String childId, String doseId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _records.removeWhere((r) => r.childId == childId && r.doseId == doseId);
  }

  @override
  Future<void> addCustomDose(String childId, VaccineDose dose, {VaccinationRecord? record}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _customDoses.putIfAbsent(childId, () => []).add(dose);
    if (record != null) _records.add(record);
  }

  @override
  Future<void> updateCustomDose(String childId, VaccineDose dose) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final doses = _customDoses[childId];
    final i = doses?.indexWhere((d) => d.id == dose.id) ?? -1;
    if (i >= 0) doses![i] = dose;
  }

  @override
  Future<void> removeCustomDose(String childId, String doseId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _customDoses[childId]?.removeWhere((d) => d.id == doseId);
    _records.removeWhere((r) => r.childId == childId && r.doseId == doseId);
  }
}
