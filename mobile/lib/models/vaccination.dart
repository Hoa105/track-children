enum VaccineStatus { done, due, overdue, upcoming }

extension VaccineStatusX on VaccineStatus {
  String get label => switch (this) {
    VaccineStatus.done => 'Đã tiêm',
    VaccineStatus.due => 'Đến lịch',
    VaccineStatus.overdue => 'Quá hạn',
    VaccineStatus.upcoming => 'Sắp tới',
  };
}

/// A brand of a vaccine (Rotarix, Prevenar 13...). [doseCount] overrides the
/// number of doses in the shared schedule, e.g. RotaTeq 3 liều vs Rotarix 2.
class VaccineProduct {
  const VaccineProduct({
    required this.code,
    required this.name,
    this.origin,
    this.doseCount,
  });
  final String code, name;
  final String? origin;
  final int? doseCount;

  factory VaccineProduct.fromJson(Map<String, dynamic> json) => VaccineProduct(
    code: json['code'] as String,
    name: json['name'] as String,
    origin: json['origin'] as String?,
    doseCount: json['doseCount'] as int?,
  );
}

/// A vaccine in the catalog (health.vaccines).
///
/// Vaccines sharing a [choiceGroup] are alternatives: a child follows one
/// [choiceOption] of the group, e.g. group `dtp`: `tcmr` (5 trong 1 + bại liệt
/// + DPT nhắc lại) or `6in1`.
class VaccineInfo {
  const VaccineInfo({
    required this.code,
    required this.name,
    required this.prevents,
    required this.isTcmr,
    this.description,
    this.choiceGroup,
    this.choiceOption,
    this.choiceLabel,
    this.choiceDefault = false,
    this.products = const [],
  });
  final String code, name, prevents;
  final bool isTcmr;
  final String? description, choiceGroup, choiceOption, choiceLabel;
  final bool choiceDefault;
  final List<VaccineProduct> products;

  VaccineProduct? product(String? code) =>
      products.where((p) => p.code == code).firstOrNull;

  factory VaccineInfo.fromJson(Map<String, dynamic> json) => VaccineInfo(
    code: json['code'] as String,
    name: json['name'] as String,
    prevents: json['prevents'] as String? ?? '',
    isTcmr: json['isTcmr'] as bool,
    description: json['description'] as String?,
    choiceGroup: json['choiceGroup'] as String?,
    choiceOption: json['choiceOption'] as String?,
    choiceLabel: json['choiceLabel'] as String?,
    choiceDefault: json['choiceDefault'] as bool? ?? false,
    products: [
      for (final p in (json['products'] as List? ?? const []))
        VaccineProduct.fromJson(p as Map<String, dynamic>),
    ],
  );
}

/// One dose in the vaccination schedule (a template row of GET /vaccines/schedule),
/// or a dose the parent added themselves ([isCustom]).
class VaccineDose {
  /// Schedule code (e.g. `5in1-1`); a repeat occurrence adds `@n` (`flu-yearly@2`).
  final String id;
  final String name;
  final String prevents;
  final String doseLabel;

  /// Recommended age in months (0 = sơ sinh, within 24h of birth).
  final int ageMonths;

  /// Extra days after [ageMonths] — e.g. VNNB mũi 2 is 1–2 weeks after mũi 1.
  final int offsetDays;

  /// Age in weeks (e.g. 6 tuần); replaces [ageMonths] + [offsetDays] when set.
  final int? ageWeeks;

  /// Dose this one is counted from: due no earlier than that dose + [minIntervalDays].
  final String? afterDoseId;
  final int? minIntervalDays;

  /// Booster repeated every N months (cúm hằng năm) until [repeatUntilMonths] of age.
  final int? repeatEveryMonths;
  final int? repeatUntilMonths;

  /// 0 for the first dose; n for the n-th repeat of a repeating booster.
  final int occurrence;

  /// vaccines.code — null for custom doses.
  final String? vaccineCode;
  final int doseNumber;

  /// Free (Tiêm chủng mở rộng) vs paid (dịch vụ).
  final bool isTcmr;

  /// Scheduling note shown in the detail screen (e.g. "Theo lịch địa phương").
  /// For a custom dose this is the parent's own note.
  final String? note;

  /// Set only for doses the parent added themselves (vaccine dịch vụ, tiêm bù...):
  /// the given/appointment date, used instead of the age rules.
  final DateTime? scheduledDate;

  /// Custom doses only: where the appointment is (before it's given).
  final String appointmentPlace;
  final String? groupId;

  const VaccineDose({
    required this.id,
    required this.name,
    required this.prevents,
    required this.doseLabel,
    required this.ageMonths,
    this.offsetDays = 0,
    this.ageWeeks,
    this.afterDoseId,
    this.minIntervalDays,
    this.repeatEveryMonths,
    this.repeatUntilMonths,
    this.occurrence = 0,
    this.vaccineCode,
    this.doseNumber = 1,
    this.isTcmr = true,
    this.note,
    this.scheduledDate,
    this.appointmentPlace = '',
    this.groupId,
  });

  factory VaccineDose.fromJson(
    Map<String, dynamic> json,
    VaccineInfo vaccine,
  ) => VaccineDose(
    id: json['id'] as String,
    name: vaccine.name,
    prevents: vaccine.prevents,
    doseLabel: json['doseLabel'] as String,
    ageMonths: json['ageMonths'] as int,
    offsetDays: json['offsetDays'] as int? ?? 0,
    ageWeeks: json['ageWeeks'] as int?,
    afterDoseId: json['afterDose'] as String?,
    minIntervalDays: json['minIntervalDays'] as int?,
    repeatEveryMonths: json['repeatEveryMonths'] as int?,
    repeatUntilMonths: json['repeatUntilMonths'] as int?,
    vaccineCode: vaccine.code,
    doseNumber: json['doseNumber'] as int? ?? 1,
    isTcmr: json['isTcmr'] as bool? ?? vaccine.isTcmr,
    note: json['note'] as String?,
  );

  bool get isCustom => scheduledDate != null;

  /// Schedule code without the repeat suffix.
  String get baseId => id.split('@').first;

  /// Whole months from [dob] to [date], never negative — the [ageMonths] of a custom dose.
  static int monthsBetween(DateTime dob, DateTime date) {
    final m =
        (date.year - dob.year) * 12 +
        date.month -
        dob.month -
        (date.day < dob.day ? 1 : 0);
    return m < 0 ? 0 : m;
  }

  VaccineDose copyWith({
    String? id,
    String? name,
    String? prevents,
    String? doseLabel,
    int? ageMonths,
    String? note,
    DateTime? scheduledDate,
    String? appointmentPlace,
    int? occurrence,
  }) => VaccineDose(
    id: id ?? this.id,
    name: name ?? this.name,
    prevents: prevents ?? this.prevents,
    doseLabel: doseLabel ?? this.doseLabel,
    ageMonths: ageMonths ?? this.ageMonths,
    offsetDays: offsetDays,
    ageWeeks: ageWeeks,
    afterDoseId: afterDoseId,
    minIntervalDays: minIntervalDays,
    repeatEveryMonths: repeatEveryMonths,
    repeatUntilMonths: repeatUntilMonths,
    occurrence: occurrence ?? this.occurrence,
    vaccineCode: vaccineCode,
    doseNumber: doseNumber,
    isTcmr: isTcmr,
    note: note ?? this.note,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    appointmentPlace: appointmentPlace ?? this.appointmentPlace,
    groupId: groupId,
  );

  /// Sort / group key for the "Theo tuổi" milestones, in days.
  int get ageKey => ageWeeks != null ? ageWeeks! * 7 : ageMonths * 30;

  String get ageLabel => ageLabelFor(ageKey);

  static String ageLabelFor(int ageKey) => ageKey == 0
      ? 'Sơ sinh'
      : ageKey % 30 != 0
      ? '${ageKey ~/ 7} tuần'
      : '${ageKey ~/ 30} tháng';

  /// Age-based date only; [afterDoseId] and repeats are resolved by the schedule builder.
  DateTime dueDate(DateTime dob) =>
      scheduledDate ??
      (ageWeeks != null
          ? DateTime(dob.year, dob.month, dob.day + ageWeeks! * 7)
          : DateTime(
              dob.year,
              dob.month + ageMonths,
              dob.day,
            ).add(Duration(days: offsetDays)));
}

/// Catalog + schedule in use (GET /vaccines/schedule or the bundled snapshot).
class VaccineCatalog {
  VaccineCatalog({required this.vaccines, required this.doses});
  final List<VaccineInfo> vaccines;
  final List<VaccineDose> doses;

  late final Map<String, VaccineInfo> _byCode = {
    for (final v in vaccines) v.code: v,
  };
  VaccineInfo? vaccine(String? code) => code == null ? null : _byCode[code];

  factory VaccineCatalog.fromJson(Map<String, dynamic> json) {
    final vaccines = [
      for (final v in json['vaccines'] as List)
        VaccineInfo.fromJson(v as Map<String, dynamic>),
    ];
    final byCode = {for (final v in vaccines) v.code: v};
    return VaccineCatalog(
      vaccines: vaccines,
      doses: [
        for (final d in (json['doses'] as List).cast<Map<String, dynamic>>())
          if (byCode[d['vaccine']] != null)
            VaccineDose.fromJson(d, byCode[d['vaccine']]!),
      ],
    );
  }
}

/// A dose the parent has marked as given.
class VaccinationRecord {
  final String childId;
  final String doseId;
  final DateTime date;
  final String place;
  final String reaction;

  /// Parent's note on a scheduled dose (custom doses keep theirs in [VaccineDose.note]).
  final String note;

  /// [VaccineProduct.code] actually given, if the parent picked one.
  final String? product;

  /// Ngày hẹn của mũi này: ngày bố mẹ đã hẹn, hoặc ngày dự kiến lúc ghi nhận
  /// nếu chưa từng đặt hẹn (health.child_vaccinations.scheduled_date).
  final DateTime? scheduledDate;
  final String appointmentPlace;

  const VaccinationRecord({
    required this.childId,
    required this.doseId,
    required this.date,
    this.place = '',
    this.reaction = '',
    this.note = '',
    this.product,
    this.scheduledDate,
    this.appointmentPlace = '',
  });

  /// Days given after (> 0) / before (< 0) [scheduledDate]; null without one.
  int? get daysFromSchedule => scheduledDate == null
      ? null
      : DateTime(date.year, date.month, date.day)
            .difference(
              DateTime(
                scheduledDate!.year,
                scheduledDate!.month,
                scheduledDate!.day,
              ),
            )
            .inDays;
}

/// A [VaccineDose] resolved against a specific child's dob and records.
class ScheduledVaccine {
  final VaccineDose dose;
  final DateTime dueDate;
  final VaccinationRecord? record;
  final VaccineStatus status;

  /// Appointment the parent set for a dose not given yet ([dueDate] is then
  /// this date); for a given dose, [VaccinationRecord.scheduledDate].
  final DateTime? appointmentDate;
  final String appointmentPlace;

  /// Ngày dự kiến app tính theo lịch, bỏ qua lịch hẹn (null = [dueDate]).
  final DateTime? expectedDate;

  /// Loại vắc-xin bố mẹ chọn trước cho mũi chưa tiêm ([VaccineProduct.code]).
  final String? plannedProduct;

  const ScheduledVaccine({
    required this.dose,
    required this.dueDate,
    required this.record,
    required this.status,
    this.appointmentDate,
    this.appointmentPlace = '',
    this.expectedDate,
    this.plannedProduct,
  });

  /// Ngày lưu vào scheduled_date khi ghi nhận đã tiêm: ngày hẹn đã đặt,
  /// nếu chưa từng hẹn thì ngày dự kiến của mũi theo lịch.
  DateTime? get plannedDate =>
      record?.scheduledDate ??
      appointmentDate ??
      (dose.isCustom ? null : expectedDate ?? dueDate);

  bool get hasAppointment => record == null && appointmentDate != null;

  /// "Đến lịch" from 14 days before the due date, "Quá hạn" after 30 days.
  static VaccineStatus statusFor(
    DateTime dueDate,
    VaccinationRecord? record,
    DateTime now,
  ) {
    if (record != null) return VaccineStatus.done;
    final today = DateTime(now.year, now.month, now.day);
    if (today.isAfter(dueDate.add(const Duration(days: 30)))) {
      return VaccineStatus.overdue;
    }
    if (!today.isBefore(dueDate.subtract(const Duration(days: 14)))) {
      return VaccineStatus.due;
    }
    return VaccineStatus.upcoming;
  }
}
