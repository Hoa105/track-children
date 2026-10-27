import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_visuals.dart';

String growthHistoryAge(DateTime? birth, DateTime date) {
  if (birth == null) return 'Chưa có ngày sinh';
  final age = growthChartAgeMonths(birth, date);
  if (age == null) return 'Ngoài khoảng tuổi 0–60 tháng';
  final months = age.floor();
  final month = DateTime(birth.year, birth.month + months);
  final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
  final anchor = DateTime.utc(
    month.year,
    month.month,
    birth.day > lastDay ? lastDay : birth.day,
  );
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(anchor).inDays;
  return days == 0 ? '$months tháng' : '$months tháng $days ngày';
}

class GrowthWeightHistoryTab extends StatelessWidget {
  const GrowthWeightHistoryTab({
    required this.readings,
    required this.repository,
    this.easyRead = false,
    this.metric = GrowthMetric.weight,
    this.bmiMode = false,
    this.zScoreForPoint,
    super.key,
  });
  final List<GrowthMeasurementDraft> readings;
  final GrowthRepository repository;
  final bool easyRead;
  final GrowthMetric metric;
  final bool bmiMode;
  final double? Function(GrowthMeasurementDraft)? zScoreForPoint;
  bool get _weight => !bmiMode && metric == GrowthMetric.weight;
  String get _unit => bmiMode
      ? 'kg/m²'
      : _weight
      ? 'kg'
      : 'cm';
  String get _key => bmiMode ? 'bmi' : metric.routeKey;
  Color get _color => bmiMode
      ? growthGreen
      : metric == GrowthMetric.lengthHeight
      ? const Color(0xFF4B92C6)
      : metric == GrowthMetric.headCircumference
      ? const Color(0xFF9B7AC2)
      : growthWeightOrange;
  String _number(double value) => formatGrowthValue(
    bmiMode ? double.parse(value.toStringAsFixed(2)) : value,
  );
  String _label(GrowthMeasurementDraft point) {
    if (bmiMode) return 'BMI';
    if (metric == GrowthMetric.headCircumference) return 'Vòng đầu';
    if (_weight) return 'Cân nặng';
    final age = repository.dateOfBirth == null
        ? null
        : growthChartAgeMonths(repository.dateOfBirth!, point.measuredAt);
    return age == null
        ? 'Chiều dài/chiều cao'
        : age < 24
        ? 'Chiều dài'
        : 'Chiều cao';
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _delta(double value) =>
      '${value > 0
          ? '+'
          : value < 0
          ? '−'
          : ''}${_weight ? value.abs().round() : _number(value.abs())} ${_weight ? 'g' : _unit}';

  @override
  Widget build(BuildContext context) {
    final points = [...readings]
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lịch sử đo',
            style: TextStyle(
              fontSize: easyRead ? 20 : 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF20365D),
            ),
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                bmiMode
                    ? 'Chưa đủ số đo cùng ngày để tính BMI.'
                    : 'Chưa có số đo ${metric == GrowthMetric.lengthHeight
                          ? 'chiều dài/chiều cao'
                          : metric == GrowthMetric.headCircumference
                          ? 'vòng đầu'
                          : 'cân nặng'}.',
                textAlign: TextAlign.center,
              ),
            ),
          for (var i = 0; i < points.length; i++)
            _row(
              context,
              points[i],
              i + 1 < points.length ? points[i + 1] : null,
              i,
              points.length,
            ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Transform.rotate(
                  angle: easyRead ? 0 : -.06,
                  child: Text(
                    'Mỗi cột mốc nhỏ\nđều là một bước tiến lớn!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: easyRead ? 'Nunito' : 'DancingScript',
                      fontSize: easyRead ? 18 : 22,
                      height: 1.4,
                      color: const Color(0xFF20365D),
                    ),
                  ),
                ),
              ),
              if (!easyRead) const SizedBox(width: 8),
              if (!easyRead) const GrowthAsset('overview-arrow', size: 34),
              if (!easyRead) const GrowthAsset('heart', size: 22),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    GrowthMeasurementDraft point,
    GrowthMeasurementDraft? previous,
    int index,
    int count,
  ) {
    final comparable =
        previous != null &&
        (_weight ||
            metric == GrowthMetric.headCircumference && !bmiMode ||
            point.method != null && point.method == previous.method);
    final grams = !comparable
        ? null
        : _weight
        ? ((point.value - previous.value) * 1000).roundToDouble()
        : point.value - previous.value;
    final age = growthHistoryAge(repository.dateOfBirth, point.measuredAt);
    final color = !_weight
        ? _color
        : index < 2
        ? growthWeightOrange
        : index == 2
        ? const Color(0xFFAE652B)
        : const Color(0xFFE89B27);
    final bodyStyle = TextStyle(
      fontSize: easyRead ? 18 : 14,
      color: const Color(0xFF20365D),
      height: 1.35,
    );
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: CustomPaint(
            painter: _HistoryMarker(color, index == 0, index == count - 1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Material(
            color: Colors.white,
            child: InkWell(
              key: ValueKey(
                '$_key-history-${point.measuredAt.toIso8601String()}',
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                showDragHandle: true,
                backgroundColor: Colors.white,
                builder: (sheetContext) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weight
                            ? 'Chi tiết số đo'
                            : 'Chi tiết ${_label(point)}',
                        style: TextStyle(
                          fontSize: easyRead ? 24 : 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF20365D),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_number(point.value)} $_unit',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ngày đo: ${_date(point.measuredAt)}\nTuổi tại ngày đo: $age',
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 12),
                      if (!_weight &&
                          !bmiMode &&
                          metric == GrowthMetric.lengthHeight)
                        Text(
                          'Cách đo: ${point.method == null
                              ? 'Chưa có'
                              : point.method == GrowthMeasurementMethod.recumbent
                              ? 'Đo nằm'
                              : 'Đo đứng'}',
                          style: bodyStyle,
                        ),
                      Text(
                        grams == null
                            ? (previous == null
                                  ? 'Chưa có lần đo trước để so sánh.'
                                  : 'Khác hoặc thiếu cách đo, chưa so sánh mức thay đổi.')
                            : '${_delta(grams)} so với lần đo ${_date(previous!.measuredAt)}.',
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        growthTooltipZScore(
                          zScoreForPoint?.call(point) ??
                              (_weight
                                  ? repository
                                        .weightAssessmentFor(point, null)
                                        ?.wfa
                                        ?.zScore
                                  : null),
                        ),
                        style: bodyStyle,
                      ),
                      if (bmiMode)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'BMI = cân nặng (kg) / chiều dài hoặc chiều cao (m)². Dữ liệu sử dụng hai số đo cùng ngày.',
                          ),
                        ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Đóng'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: index == count - 1
                          ? Colors.transparent
                          : const Color(0xFFEBEEF0),
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dateColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_date(point.measuredAt), style: bodyStyle),
                        const SizedBox(height: 2),
                        Text(
                          age,
                          style: TextStyle(
                            fontSize: easyRead ? 16 : 12,
                            height: 1.35,
                            color: const Color(0xFF62738D),
                          ),
                        ),
                      ],
                    );
                    final value = Text(
                      '${_number(point.value)} $_unit',
                      style: bodyStyle.copyWith(fontWeight: FontWeight.w800),
                    );
                    final change = Text(
                      grams == null ? '—' : _delta(grams),
                      style: bodyStyle.copyWith(
                        color: grams == null
                            ? growthMuted
                            : grams < 0
                            ? const Color(0xFFB87921)
                            : _color,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                    if (easyRead ||
                        bmiMode ||
                        constraints.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(14) > 19) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          dateColumn,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: value),
                              Flexible(child: change),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Color(0xFF20365D),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 5, child: dateColumn),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: value),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: change,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFF20365D),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryMarker extends CustomPainter {
  const _HistoryMarker(this.color, this.first, this.last);
  final Color color;
  final bool first, last;
  @override
  void paint(Canvas canvas, Size size) {
    const y = 23.0;
    canvas.drawLine(
      Offset(10, first ? y : 0),
      Offset(10, last ? y : size.height),
      Paint()
        ..color = color.withValues(alpha: .3)
        ..strokeWidth = 1.2,
    );
    if (first) {
      canvas.drawCircle(
        const Offset(10, y),
        9,
        Paint()..color = color.withValues(alpha: .12),
      );
    }
    canvas.drawCircle(const Offset(10, y), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HistoryMarker old) =>
      old.color != color || old.first != first || old.last != last;
}
