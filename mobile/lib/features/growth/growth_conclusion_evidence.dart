import 'growth_repository.dart' show formatGrowthValue;

/// Populated by the assessment domain, never inferred from chart colors.
class GrowthCalculatedBasis {
  const GrowthCalculatedBasis({
    required this.indicator,
    required this.zScore,
    required this.classificationCode,
    required this.classificationLabel,
    required this.thresholdDescription,
    required this.explanation,
    required this.datasetVersion,
    required this.rulesVersion,
  });
  final String indicator, classificationCode, classificationLabel;
  final String thresholdDescription, explanation, datasetVersion, rulesVersion;
  final double zScore;
  bool get complete =>
      zScore.isFinite &&
      [
        indicator,
        classificationCode,
        classificationLabel,
        thresholdDescription,
        explanation,
        datasetVersion,
        rulesVersion,
      ].every((v) => v.trim().isNotEmpty);
}

class GrowthConclusionEvidence {
  const GrowthConclusionEvidence({
    this.ageMonths,
    this.sex,
    this.weight,
    this.stature,
    this.measuredAt,
    this.statureLabel = 'chiều dài/chiều cao',
    this.method,
    this.results = const [],
  });
  final double? ageMonths, weight, stature;
  final String? sex, method;
  final DateTime? measuredAt;
  final String statureLabel;
  final List<GrowthCalculatedBasis> results;
  bool get inScope =>
      ageMonths != null &&
      ageMonths!.isFinite &&
      ageMonths! >= 0 &&
      ageMonths! <= 60;
  bool get outside => ageMonths != null && !inScope;
  List<GrowthCalculatedBasis> get available =>
      inScope &&
          sex != null &&
          measuredAt != null &&
          weight != null &&
          weight! > 0
      ? results
            .where(
              (r) =>
                  r.complete &&
                  (r.indicator == 'WFA' ||
                      ((r.indicator == 'WFL' || r.indicator == 'WFH') &&
                          stature != null &&
                          stature! > 0 &&
                          method != null &&
                          (r.indicator == 'WFL'
                              ? ageMonths! < 24 && method == 'Đo nằm'
                              : ageMonths! >= 24 && method == 'Đo đứng'))),
            )
            .toList()
      : const [];
  String get inputs => [
    measuredAt == null
        ? 'Chưa có ngày đo.'
        : 'Lần đo ${measuredAt!.day}/${measuredAt!.month}/${measuredAt!.year}.',
    ageMonths == null
        ? 'Chưa có tuổi tại ngày đo.'
        : 'Tuổi tại ngày đo: ${formatGrowthValue(ageMonths!)} tháng.',
    sex == null ? 'Chưa có giới tính từ hồ sơ.' : 'Giới tính: $sex.',
    weight == null
        ? 'Chưa có cân nặng.'
        : 'Cân nặng: ${formatGrowthValue(weight!)} kg.',
    stature == null
        ? 'Chưa có $statureLabel cùng ngày.'
        : '${statureLabel[0].toUpperCase()}${statureLabel.substring(1)}: ${formatGrowthValue(stature!)} cm${method == null ? '' : ' ($method)'}.',
  ].join(' ');
  String get reference => outside
      ? 'Lần đo nằm ngoài 0–60 tháng; không áp dụng bộ chuẩn WHO này.'
      : available.isEmpty
      ? 'Cần WHO Child Growth Standards: cân nặng theo tuổi và cân nặng theo $statureLabel, đúng giới tính và cách đo. Chưa có bộ chuẩn, phiên bản và bộ quy tắc gắn với kết quả tính toán của lần đo này.'
      : available
            .map(
              (r) =>
                  '${r.indicator}: WHO Child Growth Standards, ${r.datasetVersion}; quy tắc ${r.rulesVersion}.',
            )
            .join('\n');
  String get scores => available.isEmpty
      ? 'Chưa có kết quả tính toán Z-score cho lần đo này. Không dùng giá trị mẫu hoặc ước lượng từ biểu đồ.'
      : available
            .map(
              (r) =>
                  '${r.indicator}: ${r.zScore > 0 ? '+' : ''}${r.zScore.toStringAsFixed(2).replaceAll('.', ',')} SD.',
            )
            .join('\n');
  String get thresholds => available.isEmpty
      ? 'Chưa có ngưỡng phân loại từ bộ quy tắc WHO đã cấu hình; chưa thể xác định nhóm đánh giá.'
      : available
            .map(
              (r) =>
                  '${r.indicator}: ${r.thresholdDescription} → ${r.classificationLabel}.',
            )
            .join('\n');
  String get explanation => available.isEmpty
      ? 'Chưa đủ dữ liệu đánh giá. Cần kết quả tính toán và quy tắc phân loại để giải thích kết luận; không suy đoán từ màu vùng hay một chỉ số riêng lẻ.'
      : '${available.map((r) => '${r.indicator}: ${r.explanation}').join('\n')}${available.any((r) => r.indicator == 'WFA') && available.any((r) => r.indicator == 'WFL' || r.indicator == 'WFH') ? '' : '\nChưa đủ cả hai chỉ số để nhận xét tổng hợp.'}';
}
