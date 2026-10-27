import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';

void main() {
  test('Six age ranges have no overlapping measurement boundaries', () {
    const ranges = [(0, 3), (3, 6), (6, 9), (9, 12), (12, 36), (36, 60)];
    for (final range in ranges) {
      expect(growthWeightAgeStart(range.$2), range.$1);
      expect(growthWeightAgeInRange(range.$1.toDouble(), range.$2), isTrue);
      expect(growthWeightAgeInRange(range.$1 - .01, range.$2), isFalse);
      expect(growthWeightAgeInRange(range.$2.toDouble(), range.$2), range.$2 == 60);
    }
    expect(growthWeightAgeInRange(60.01, 60), isFalse);
    expect(growthWeightAgeStart(0), 0);
    expect(growthWeightAgeInRange(0, 0), isTrue);
    expect(growthWeightAgeInRange(60, 0), isTrue);
    expect(growthWeightAgeInRange(60.01, 0), isFalse);
  });
}
