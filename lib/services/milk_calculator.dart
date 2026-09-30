/// Reference milk intake (sữa mẹ vắt / sữa công thức bú bình) by age and
/// weight. Pure functions — no service state — so the screen and tests share
/// one source of truth.
///
/// Sources, simplified for a reference tool (not a prescription):
/// - First week: newborn stomach capacity per feed (ngày 1: 5–7 ml, ngày 3:
///   22–27 ml, ngày 7: 45–60 ml).
/// - 1 week – 6 months: ~140–170 ml/kg/ngày, capped at ~960 ml/ngày (AAP).
/// - From 6 months: fixed daily ranges alongside ăn bổ sung (Viện Dinh dưỡng
///   Quốc gia / AAP), since solids take over part of the energy need.
library;

/// One age band of the reference table.
class MilkStage {
  const MilkStage({
    required this.label,
    required this.fromDays,
    required this.toDays,
    required this.minFeeds,
    required this.maxFeeds,
    required this.summary,
    required this.tips,
  });

  final String label;

  /// Inclusive lower / exclusive upper bound of the age band, in days.
  final int fromDays;
  final int toDays;
  final int minFeeds;
  final int maxFeeds;

  /// Short amount description for the reference table.
  final String summary;
  final List<String> tips;

  bool get needsWeight => fromDays >= 7 && toDays <= _sixMonths;
}

const _month = 30;
const _sixMonths = 6 * _month;
const maxDailyMl = 960;
const mlPerKgMin = 140;
const mlPerKgMax = 170;

const milkStages = <MilkStage>[
  MilkStage(
    label: 'Tuần đầu (0–6 ngày)',
    fromDays: 0,
    toDays: 7,
    minFeeds: 8,
    maxFeeds: 12,
    summary: '5–60 ml/cữ, tăng dần mỗi ngày',
    tips: [
      'Dạ dày bé còn rất nhỏ: ngày 1 chỉ khoảng 5–7 ml/cữ, đến ngày 7 khoảng 45–60 ml/cữ.',
      'Cho bú 2–3 giờ/lần, kể cả ban đêm; không để bé ngủ quá 3–4 giờ không bú.',
    ],
  ),
  MilkStage(
    label: '1 tuần – 1 tháng',
    fromDays: 7,
    toDays: _month,
    minFeeds: 8,
    maxFeeds: 12,
    summary: '$mlPerKgMin–$mlPerKgMax ml/kg/ngày',
    tips: [
      'Bé thường bú 8–12 cữ/ngày, khoảng 2–3 giờ/cữ.',
      'Bé đủ sữa khi đi tiểu 6 lần/ngày trở lên và tăng cân đều.',
    ],
  ),
  MilkStage(
    label: '1 – 3 tháng',
    fromDays: _month,
    toDays: 3 * _month,
    minFeeds: 6,
    maxFeeds: 8,
    summary: '$mlPerKgMin–$mlPerKgMax ml/kg/ngày',
    tips: [
      'Khoảng cách giữa các cữ dài dần ra, 3–4 giờ/cữ.',
      'Bé có thể có những đợt "tăng tốc" bú nhiều hơn vài ngày, đó là bình thường.',
    ],
  ),
  MilkStage(
    label: '3 – 6 tháng',
    fromDays: 3 * _month,
    toDays: _sixMonths,
    minFeeds: 5,
    maxFeeds: 6,
    summary: '$mlPerKgMin–$mlPerKgMax ml/kg/ngày, tối đa ~$maxDailyMl ml',
    tips: [
      'Không cần cho bé uống quá $maxDailyMl ml/ngày.',
      'Chưa cho ăn dặm trước tròn 6 tháng tuổi.',
    ],
  ),
  MilkStage(
    label: '6 – 9 tháng',
    fromDays: _sixMonths,
    toDays: 9 * _month,
    minFeeds: 4,
    maxFeeds: 5,
    summary: '600–800 ml/ngày + ăn dặm',
    tips: [
      'Sữa vẫn là nguồn dinh dưỡng chính, ăn dặm 1–2 bữa/ngày.',
      'Cho bú trước hoặc tách xa bữa ăn dặm để bé không bỏ sữa.',
    ],
  ),
  MilkStage(
    label: '9 – 12 tháng',
    fromDays: 9 * _month,
    toDays: 12 * _month,
    minFeeds: 3,
    maxFeeds: 4,
    summary: '500–700 ml/ngày + ăn dặm',
    tips: [
      'Tăng lên 2–3 bữa ăn dặm/ngày và 1 bữa phụ.',
      'Tập cho bé uống bằng cốc/ly có vòi.',
    ],
  ),
  MilkStage(
    label: '1 – 2 tuổi',
    fromDays: 12 * _month,
    toDays: 24 * _month,
    minFeeds: 2,
    maxFeeds: 3,
    summary: '300–500 ml/ngày',
    tips: [
      'Bé ăn 3 bữa chính cùng gia đình, sữa là bữa phụ.',
      'Uống quá nhiều sữa có thể làm bé biếng ăn và thiếu sắt.',
    ],
  ),
  MilkStage(
    label: '2 – 5 tuổi',
    fromDays: 24 * _month,
    toDays: 60 * _month,
    minFeeds: 2,
    maxFeeds: 2,
    summary: '300–500 ml/ngày',
    tips: [
      'Có thể dùng sữa và chế phẩm từ sữa (sữa chua, phô mai) thay một phần.',
    ],
  ),
];

/// Daily range for the fixed-amount stages (from 6 months).
const _fixedDaily = <int, (int, int)>{
  _sixMonths: (600, 800),
  9 * _month: (500, 700),
  12 * _month: (300, 500),
  24 * _month: (300, 500),
};

/// Per-feed stomach capacity for day index 1..7 of life.
(int, int) _firstWeekPerFeed(int dayOfLife) => switch (dayOfLife) {
      1 => (5, 7),
      2 => (10, 15),
      3 => (22, 27),
      4 || 5 || 6 => (30, 45),
      _ => (45, 60),
    };

MilkStage? milkStageFor(int ageDays) {
  for (final s in milkStages) {
    if (ageDays >= s.fromDays && ageDays < s.toDays) return s;
  }
  return null;
}

class MilkEstimate {
  const MilkEstimate({
    required this.stage,
    required this.feedsPerDay,
    required this.minPerDay,
    required this.maxPerDay,
    required this.minPerFeed,
    required this.maxPerFeed,
    required this.basis,
    this.capped = false,
  });

  final MilkStage stage;
  final int feedsPerDay;
  final int minPerDay;
  final int maxPerDay;
  final int minPerFeed;
  final int maxPerFeed;

  /// How the numbers were derived, shown under the result.
  final String basis;

  /// True when the weight-based amount hit [maxDailyMl].
  final bool capped;
}

int _round5(num ml) => ((ml / 5).round() * 5).toInt();

/// Returns null when the age is outside 0–60 months, or when the stage needs
/// a weight and [weightKg] is missing/invalid.
MilkEstimate? estimateMilk({required int ageDays, double? weightKg, int? feedsPerDay}) {
  final stage = milkStageFor(ageDays);
  if (stage == null) return null;
  final feeds = (feedsPerDay ?? ((stage.minFeeds + stage.maxFeeds) / 2).round())
      .clamp(stage.minFeeds, stage.maxFeeds);

  if (ageDays < 7) {
    final day = ageDays + 1;
    final (lo, hi) = _firstWeekPerFeed(day);
    return MilkEstimate(
      stage: stage,
      feedsPerDay: feeds,
      minPerDay: lo * feeds,
      maxPerDay: hi * feeds,
      minPerFeed: lo,
      maxPerFeed: hi,
      basis: 'Theo dung tích dạ dày trẻ sơ sinh ngày thứ $day: $lo–$hi ml/cữ.',
    );
  }

  final int minDay;
  final int maxDay;
  var capped = false;
  String basis;
  if (stage.needsWeight) {
    if (weightKg == null || weightKg <= 0 || weightKg > 30) return null;
    final rawMax = weightKg * mlPerKgMax;
    capped = rawMax > maxDailyMl;
    minDay = _round5((weightKg * mlPerKgMin).clamp(0, maxDailyMl));
    maxDay = _round5(rawMax.clamp(0, maxDailyMl));
    basis = '$mlPerKgMin–$mlPerKgMax ml × ${_fmtKg(weightKg)} kg cân nặng mỗi ngày'
        '${capped ? ', giới hạn tối đa ~$maxDailyMl ml/ngày' : ''}.';
  } else {
    (minDay, maxDay) = _fixedDaily[stage.fromDays]!;
    basis = 'Khuyến nghị theo tháng tuổi khi bé đã ăn bổ sung: $minDay–$maxDay ml/ngày.';
  }
  return MilkEstimate(
    stage: stage,
    feedsPerDay: feeds,
    minPerDay: minDay,
    maxPerDay: maxDay,
    minPerFeed: _round5(minDay / feeds),
    maxPerFeed: _round5(maxDay / feeds),
    basis: basis,
    capped: capped,
  );
}

String _fmtKg(double kg) => kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
