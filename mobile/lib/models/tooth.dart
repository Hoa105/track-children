enum Jaw { upper, lower }

enum JawSide { right, left }

/// The 5 primary tooth types, ordered from the midline outwards.
enum ToothType { centralIncisor, lateralIncisor, canine, firstMolar, secondMolar }

extension ToothTypeX on ToothType {
  String get label => switch (this) {
        ToothType.centralIncisor => 'Răng cửa giữa',
        ToothType.lateralIncisor => 'Răng cửa bên',
        ToothType.canine => 'Răng nanh',
        ToothType.firstMolar => 'Răng hàm thứ nhất',
        ToothType.secondMolar => 'Răng hàm thứ hai',
      };
}

/// One of the 20 primary (milk) teeth.
class PrimaryTooth {
  final Jaw jaw;
  final JawSide side;
  final ToothType type;

  const PrimaryTooth(this.jaw, this.side, this.type);

  String get id => '${jaw.name}-${side.name}-${type.name}';

  String get label =>
      '${type.label} ${jaw == Jaw.upper ? 'hàm trên' : 'hàm dưới'} ${side == JawSide.right ? 'bên phải' : 'bên trái'}';

  /// Typical eruption window in months (ADA primary-teeth chart).
  (int, int) get eruptionMonths => switch ((jaw, type)) {
        (Jaw.upper, ToothType.centralIncisor) => (8, 12),
        (Jaw.upper, ToothType.lateralIncisor) => (9, 13),
        (Jaw.upper, ToothType.canine) => (16, 22),
        (Jaw.upper, ToothType.firstMolar) => (13, 19),
        (Jaw.upper, ToothType.secondMolar) => (25, 33),
        (Jaw.lower, ToothType.centralIncisor) => (6, 10),
        (Jaw.lower, ToothType.lateralIncisor) => (10, 16),
        (Jaw.lower, ToothType.canine) => (17, 23),
        (Jaw.lower, ToothType.firstMolar) => (14, 18),
        (Jaw.lower, ToothType.secondMolar) => (23, 31),
      };

  String get eruptionLabel => '${eruptionMonths.$1}–${eruptionMonths.$2} tháng';

  static final all = [
    for (final jaw in Jaw.values)
      for (final side in JawSide.values)
        for (final type in ToothType.values) PrimaryTooth(jaw, side, type),
  ];
}

class ToothRecord {
  final String childId;
  final String toothId;
  final DateTime eruptedDate;

  const ToothRecord({required this.childId, required this.toothId, required this.eruptedDate});
}
