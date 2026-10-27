import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_conclusion_evidence.dart';

void main() {
  test(
    'Actual measurement context is shown without fabricated calculations',
    () {
      final evidence = GrowthConclusionEvidence(
        ageMonths: 11,
        sex: 'bé trai',
        weight: 8.5,
        stature: 75,
        statureLabel: 'chiều dài',
        method: 'Đo nằm',
        measuredAt: DateTime(2025, 4, 15),
      );
      expect(evidence.inputs, contains('8,5 kg'));
      expect(evidence.inputs, contains('75 cm (Đo nằm)'));
      expect(evidence.inputs, contains('15/4/2025'));
      expect(evidence.available, isEmpty);
      expect(evidence.scores, contains('Chưa có kết quả tính toán'));
      expect(evidence.thresholds, contains('Chưa có ngưỡng'));
      expect(evidence.explanation, contains('Chưa đủ dữ liệu đánh giá'));
    },
  );
  test('Missing or out-of-scope context does not produce WHO conclusions', () {
    expect(const GrowthConclusionEvidence().available, isEmpty);
    expect(
      const GrowthConclusionEvidence(ageMonths: 60.1).reference,
      contains('ngoài 0–60 tháng'),
    );
    expect(const GrowthConclusionEvidence(ageMonths: 60).inScope, isTrue);
  });
}
