enum VaccineStatus { done, due, overdue, upcoming }

extension VaccineStatusX on VaccineStatus {
  String get label => switch (this) {
        VaccineStatus.done => 'Đã tiêm',
        VaccineStatus.due => 'Đến lịch',
        VaccineStatus.overdue => 'Quá hạn',
        VaccineStatus.upcoming => 'Sắp tới',
      };
}

/// One dose in the vaccination schedule (a template row from the national
/// TCMR table in docs/tieu_chuan_tham_khao.md § 3.1).
class VaccineDose {
  final String id;
  final String name;
  final String prevents;
  final String doseLabel;

  /// Recommended age in months (0 = sơ sinh, within 24h of birth).
  final int ageMonths;

  /// Extra days after [ageMonths] — e.g. VNNB mũi 2 is 1–2 weeks after mũi 1.
  final int offsetDays;

  /// Scheduling note shown in the detail screen (e.g. "Theo lịch địa phương").
  /// For a custom dose this is the parent's own note.
  final String? note;

  /// Set only for doses the parent added themselves (vaccine dịch vụ, tiêm bù...):
  /// the given/appointment date, used instead of [ageMonths] + [offsetDays].
  final DateTime? scheduledDate;

  /// Custom doses only: where the appointment is (before it's given).
  final String appointmentPlace;

  const VaccineDose({
    required this.id,
    required this.name,
    required this.prevents,
    required this.doseLabel,
    required this.ageMonths,
    this.offsetDays = 0,
    this.note,
    this.scheduledDate,
    this.appointmentPlace = '',
  });

  bool get isCustom => scheduledDate != null;

  /// Whole months from [dob] to [date], never negative — the [ageMonths] of a custom dose.
  static int monthsBetween(DateTime dob, DateTime date) {
    final m = (date.year - dob.year) * 12 + date.month - dob.month - (date.day < dob.day ? 1 : 0);
    return m < 0 ? 0 : m;
  }

  VaccineDose copyWith({
    String? name,
    String? prevents,
    String? doseLabel,
    int? ageMonths,
    String? note,
    DateTime? scheduledDate,
    String? appointmentPlace,
  }) =>
      VaccineDose(
        id: id,
        name: name ?? this.name,
        prevents: prevents ?? this.prevents,
        doseLabel: doseLabel ?? this.doseLabel,
        ageMonths: ageMonths ?? this.ageMonths,
        offsetDays: offsetDays,
        note: note ?? this.note,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        appointmentPlace: appointmentPlace ?? this.appointmentPlace,
      );

  String get ageLabel => ageMonths == 0 ? 'Sơ sinh' : '$ageMonths tháng';

  DateTime dueDate(DateTime dob) =>
      scheduledDate ?? DateTime(dob.year, dob.month + ageMonths, dob.day).add(Duration(days: offsetDays));
}

/// A dose the parent has marked as given.
class VaccinationRecord {
  final String childId;
  final String doseId;
  final DateTime date;
  final String place;
  final String reaction;

  /// Parent's note on a TCMR dose (custom doses keep theirs in [VaccineDose.note]).
  final String note;

  const VaccinationRecord({
    required this.childId,
    required this.doseId,
    required this.date,
    this.place = '',
    this.reaction = '',
    this.note = '',
  });
}

/// A [VaccineDose] resolved against a specific child's dob and records.
class ScheduledVaccine {
  final VaccineDose dose;
  final DateTime dueDate;
  final VaccinationRecord? record;
  final VaccineStatus status;

  const ScheduledVaccine({
    required this.dose,
    required this.dueDate,
    required this.record,
    required this.status,
  });

  /// "Đến lịch" from 14 days before the due date, "Quá hạn" after 30 days.
  static VaccineStatus statusFor(DateTime dueDate, VaccinationRecord? record, DateTime now) {
    if (record != null) return VaccineStatus.done;
    final today = DateTime(now.year, now.month, now.day);
    if (today.isAfter(dueDate.add(const Duration(days: 30)))) return VaccineStatus.overdue;
    if (!today.isBefore(dueDate.subtract(const Duration(days: 14)))) return VaccineStatus.due;
    return VaccineStatus.upcoming;
  }
}
