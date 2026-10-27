import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_weight_detail.dart' show GrowthAgeChartHeading;
import 'growth_stature_velocity_reference.dart';
import 'growth_visuals.dart';
import 'growth_weight_velocity_axes.dart';
import 'growth_chart_explanation_dialog.dart';
import 'growth_conclusion_explanation.dart';

const growthStatureBlue = Color(0xFF4B92C6);

class GrowthStatureVelocityPoint {
  const GrowthStatureVelocityPoint(
    this.startMonth,
    this.change,
    this.from,
    this.to,
  );
  final int startMonth;
  final double change;
  final GrowthMeasurementDraft from, to;
}

List<GrowthStatureVelocityPoint> growthStatureMonthlyIncrements(
  List<GrowthMeasurementDraft> readings,
  DateTime? birth, {
  int months = 1,
  bool headCircumference = false,
}) {
  if (birth == null) return [];
  final unique = <DateTime, GrowthMeasurementDraft>{};
  for (final p in readings) {
    if (p.value.isFinite && p.value > 0) {
      unique[DateUtils.dateOnly(p.measuredAt)] = p;
    }
  }
  final sorted = unique.values.toList()
    ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  final result = <GrowthStatureVelocityPoint>[];
  if (months != 1 && months != 2) return [];
  for (var i = 0; i < sorted.length; i++) {
    final b = sorted[i];
    final bAge = growthChartAgeMonths(birth, b.measuredAt);
    if (bAge == null) continue;
    final candidates = sorted
        .take(i)
        .where(
          (p) => growthChartAgeMonths(birth, p.measuredAt) == bAge - months,
        );
    if (candidates.isEmpty) continue;
    final a = candidates.last;
    final start = growthChartAgeMonths(birth, a.measuredAt),
        end = growthChartAgeMonths(birth, b.measuredAt);
    if (start == null ||
        end == null ||
        start != start.roundToDouble() ||
        end != start + months ||
        (!headCircumference && (a.method == null || a.method != b.method))) {
      continue;
    }
    if (headCircumference) {
      if (months == 2 && end > 12) continue;
      result.add(
        GrowthStatureVelocityPoint(start.toInt(), b.value - a.value, a, b),
      );
      continue;
    }
    if (months == 2 &&
        (end > 24 || b.method != GrowthMeasurementMethod.recumbent)) {
      continue;
    }
    final expected = end < 24 || (months == 2 && end == 24)
        ? GrowthMeasurementMethod.recumbent
        : GrowthMeasurementMethod.standing;
    if (months == 1 && (start < 24) != (end < 24)) continue;
    if (a.method != expected) continue;
    result.add(
      GrowthStatureVelocityPoint(start.toInt(), b.value - a.value, a, b),
    );
  }
  return result;
}

class GrowthStatureVelocityTab extends StatefulWidget {
  const GrowthStatureVelocityTab({
    required this.repository,
    required this.readings,
    required this.name,
    this.easyRead = false,
    this.headCircumference = false,
    this.bmiMode = false,
    super.key,
  });
  final GrowthRepository repository;
  final List<GrowthMeasurementDraft> readings;
  final String name;
  final bool easyRead;
  final bool headCircumference;
  final bool bmiMode;
  @override
  State<GrowthStatureVelocityTab> createState() =>
      _GrowthStatureVelocityTabState();
}

class _GrowthStatureVelocityTabState extends State<GrowthStatureVelocityTab> {
  Color get _accent => widget.bmiMode
      ? growthGreen
      : widget.headCircumference
      ? const Color(0xFF9B7AC2)
      : growthStatureBlue;
  int get _whoMax => widget.headCircumference ? 12 : 24;
  Future<GrowthStatureVelocityReference?> _loadReference() => widget.bmiMode
      ? Future.value(null)
      : widget.headCircumference
      ? widget.repository.headVelocityReference()
      : widget.repository.statureVelocityReference();
  late int _months = widget.bmiMode ? 1 : 2;
  late Future<GrowthStatureVelocityReference?> _reference = _loadReference();
  int _range = 0;
  int? _selected;
  static const _ranges = [
    (0, 60, 'Toàn bộ'),
    (0, 3, '0 - 3 tháng'),
    (3, 6, '3 - 6 tháng'),
    (6, 9, '6 - 9 tháng'),
    (9, 12, '9 - 12 tháng'),
    (12, 36, '1 - 3 tuổi'),
    (36, 60, '3 - 5 tuổi'),
  ];
  String value(double n) =>
      formatGrowthValue(double.parse(n.toStringAsFixed(2)));
  String signed(double n) => '${n > 0 ? '+' : ''}${value(n)}';
  String date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget paper(String title, String body) => Transform.rotate(
    angle: widget.easyRead ? 0 : -.07,
    child: CustomPaint(
      painter: const GrowthNotePaperPainter(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: widget.easyRead ? 'Nunito' : 'DancingScript',
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
            Text(
              body,
              style: TextStyle(
                fontFamily: widget.easyRead ? 'Nunito' : 'DancingScript',
                fontSize: 16,
                color: const Color(0xFF20365D),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<GrowthStatureVelocityReference?>(
        future: _reference,
        builder: (context, snapshot) =>
            _content(context, snapshot.data, snapshot.hasError),
      );

  Widget _content(
    BuildContext context,
    GrowthStatureVelocityReference? reference,
    bool failed,
  ) {
    final measurementUnit = widget.bmiMode ? 'kg/m²' : 'cm';
    final unit = widget.bmiMode
        ? 'kg/m²/tháng'
        : _months == 1
        ? 'cm/tháng'
        : 'cm/2 tháng';
    final period = _months == 1 ? 'một tháng' : 'hai tháng';
    final range = _ranges[_range];
    final chartEnd = _months == 2 && range.$1 < _whoMax
        ? math.min(_whoMax, range.$2)
        : range.$2;
    final points =
        growthStatureMonthlyIncrements(
              widget.readings,
              widget.repository.dateOfBirth,
              months: _months,
              headCircumference: widget.headCircumference,
            )
            .where(
              (p) =>
                  p.startMonth >= range.$1 &&
                  p.startMonth + _months <= range.$2,
            )
            .toList();
    final latest = points.lastOrNull;
    final activeReference = _months == 2 && range.$1 < _whoMax
        ? reference
        : null;
    final bounds = latest == null
        ? null
        : activeReference?.rows
              .where((r) => r.start == latest.startMonth)
              .firstOrNull;
    final comparison = bounds == null
        ? null
        : 'Kỳ ${latest!.startMonth}–${latest.startMonth + 2} tháng · ${activeReference!.sexLabel}: −2 SD = ${value(bounds.low)} $measurementUnit, trung vị = ${value(bounds.median)} $measurementUnit, +2 SD = ${value(bounds.high)} $measurementUnit. Mức tăng đã ghi nhận: ${value(latest.change)} $measurementUnit/2 tháng.';
    final previous =
        points.length > 1 &&
            points[points.length - 2].startMonth + 1 == latest!.startMonth
        ? points[points.length - 2]
        : null;
    final delta = previous == null ? null : latest!.change - previous.change;
    final differences = <double>[
      for (var i = 1; i < points.length; i++)
        if (points[i].startMonth == points[i - 1].startMonth + 1)
          points[i].change - points[i - 1].change,
    ].where((d) => d.abs() >= .01).toList();
    final oscillates =
        differences.any((d) => d > 0) && differences.any((d) => d < 0);
    final direction = delta == null
        ? 'Chưa đủ dữ liệu nhận xét xu hướng'
        : oscillates
        ? 'Dao động qua các tháng'
        : delta.abs() < .01
        ? 'Ít thay đổi'
        : delta > 0
        ? 'Tốc độ tăng so với kỳ trước'
        : 'Tốc độ giảm so với kỳ trước';
    final comment = latest == null
        ? 'Cần ít nhất hai số đo cùng cách đo, cách nhau đúng $period để tính tốc độ.'
        : '${widget.name} của bé ${latest.change >= 0 ? 'tăng' : 'giảm'} ${value(latest.change.abs())} $measurementUnit trong kỳ $period gần nhất.${delta == null ? ' Chưa có kỳ liền trước để so sánh.' : ' Mức tăng ${delta.abs() < .01 ? 'gần như không đổi' : '${delta > 0 ? 'nhiều' : 'ít'} hơn ${value(delta.abs())} $measurementUnit'} so với kỳ trước.'} Ba mẹ hãy tiếp tục theo dõi các lần đo tiếp theo nhé!';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final months in widget.bmiMode ? [1] : [1, 2])
                ChoiceChip(
                  label: Text(months == 1 ? 'Từng tháng' : 'Kỳ 2 tháng · WHO'),
                  selected: _months == months,
                  onSelected: (_) => setState(() {
                    _months = months;
                    _selected = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!widget.easyRead)
                const GrowthAsset('weight-chart-arrow-left', size: 42),
              const SizedBox(width: 4),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: Text(
                    'Mỗi lần đo giúp ba mẹ hiểu thêm hành trình lớn lên của con',
                    style: TextStyle(
                      fontFamily: widget.easyRead ? 'Nunito' : 'DancingScript',
                      fontSize: 18,
                      height: 1.35,
                      color: const Color(0xFF20365D),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: paper(
              latest == null
                  ? 'Chưa đủ số đo'
                  : '${signed(latest.change)} $unit',
              widget.bmiMode
                  ? 'Thay đổi BMI tháng gần nhất'
                  : 'Tốc độ tăng ${widget.name.toLowerCase()} kỳ gần nhất',
            ),
          ),
          if (!widget.easyRead)
            const Align(
              alignment: Alignment.center,
              child: GrowthAsset('weight-note-arrow', size: 52),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: paper(
              delta == null ? 'Chưa đủ dữ liệu' : '${signed(delta)} $unit',
              'Thay đổi tốc độ so với kỳ liền trước',
            ),
          ),
          const SizedBox(height: 28),
          GrowthAgeChartHeading(
            title: widget.bmiMode
                ? 'Thay đổi BMI theo tháng'
                : 'Tốc độ tăng ${widget.name.toLowerCase()} ${_months == 1 ? 'theo tháng' : 'kỳ 2 tháng'}',
            months: _ranges[_range].$2 == 60 && _range == 0
                ? 0
                : _ranges[_range].$2,
            easyRead: widget.easyRead,
            onChanged: (end) => setState(() {
              _range = end == 0 ? 0 : _ranges.indexWhere((r) => r.$2 == end);
              _selected = null;
            }),
            onExplain: () => showDialog<void>(
              context: context,
              builder: (_) => GrowthChartExplanationDialog(
                title: const Text('Giải thích biểu đồ'),
                content: Text(
                  widget.bmiMode
                      ? 'BMI = cân nặng (kg) / chiều dài hoặc chiều cao (m)². Hai số đo dùng để tính mỗi giá trị BMI phải cùng ngày.\n\nTrục ngang là tuổi (tháng); trục dọc là thay đổi BMI (kg/m²/tháng). Mỗi điểm so sánh hai giá trị BMI cách nhau đúng một tháng, cùng cách đo chiều dài/chiều cao. Không nối qua kỳ thiếu dữ liệu hoặc đổi cách đo.\n\nChưa có chuẩn WHO riêng cho tốc độ BMI. Biểu đồ không có dải tham chiếu hoặc Z-score vận tốc; mức giảm BMI không tự đồng nghĩa với tăng trưởng chậm.'
                      : 'Trục ngang là tuổi (tháng), trục dọc là mức tăng ($unit). Mỗi điểm dùng hai số đo cách nhau đúng $period, cùng cách đo. Điểm nằm tại giữa kỳ đo. Không nối qua kỳ thiếu số đo.\n\n${_months == 2 ? 'Dải WHO từ −2 SD đến +2 SD, đúng giới tính, dùng ${widget.headCircumference ? 'vòng đầu' : 'chiều dài nằm'} trong phạm vi 0–$_whoMax tháng. Mỗi ô dải quanh mốc giữa kỳ biểu thị bảng tham chiếu riêng của kỳ hai tháng đó; không nội suy giữa các kỳ. Các kỳ liên tiếp có thể chồng lấn thời gian.' : 'WHO không có bảng tốc độ ${widget.name.toLowerCase()} kỳ một tháng. Chọn Kỳ 2 tháng để xem tham chiếu.'}',
                ),
                actions: const [],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (points.isEmpty && activeReference == null)
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chưa đủ số đo để hiển thị tốc độ trong khoảng tuổi này.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final painter = _StatureVelocityPainter(
                  points,
                  growthVelocityAgeTicks(
                    range.$1,
                    chartEnd,
                    largeText: MediaQuery.textScalerOf(context).scale(12) > 20,
                  ),
                  _selected,
                  MediaQuery.textScalerOf(context).scale(12),
                  _months,
                  activeReference,
                  _accent,
                  widget.bmiMode,
                );
                final size = Size(
                  constraints.maxWidth,
                  widget.easyRead ? 340 : 280,
                );
                void hover(Offset position) {
                  int? selected;
                  for (var i = 0; i < points.length; i++) {
                    if ((painter.point(i, size) - position).distance <= 20) {
                      selected = i;
                      break;
                    }
                  }
                  if (selected != _selected) {
                    setState(() => _selected = selected);
                  }
                }

                final selected = _selected != null && _selected! < points.length
                    ? points[_selected!]
                    : null;
                final at = selected == null
                    ? null
                    : painter.point(_selected!, size);
                return MouseRegion(
                  onHover: (e) => hover(e.localPosition),
                  onExit: (_) => setState(() => _selected = null),
                  child: GestureDetector(
                    onTapDown: (e) => hover(e.localPosition),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(size: size, painter: painter),
                        if (selected != null)
                          Positioned(
                            left: (at!.dx - 110)
                                .clamp(0, math.max(0, size.width - 220))
                                .toDouble(),
                            top: math.max(0, at.dy - 110),
                            child: IgnorePointer(
                              child: Container(
                                width: math.min(220, size.width),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFE9EDE8),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text.rich(
                                  growthMeasurementTooltipSpan(
                                    measurement:
                                        '${signed(selected.change)} $unit',
                                    zScore: widget.bmiMode
                                        ? 'Chưa có chuẩn WHO cho tốc độ BMI'
                                        : 'Z-score: Chưa có kết quả đối chiếu',
                                    contextLabel:
                                        '${selected.startMonth}–${selected.startMonth + _months} tháng',
                                    date:
                                        '${date(selected.from.measuredAt)} – ${date(selected.to.measuredAt)}',
                                  ),
                                  textScaler: MediaQuery.textScalerOf(context),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          if (activeReference != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Icon(
                    Icons.rectangle,
                    size: 16,
                    color: _accent.withValues(alpha: .44),
                  ),
                  Text(
                    'WHO · −2 SD đến +2 SD · kỳ 2 tháng',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          if (_months == 2 && reference == null)
            Text(
              failed
                  ? 'Chưa tải được tham chiếu WHO.'
                  : 'Chưa có tham chiếu WHO đúng giới tính.',
              style: const TextStyle(fontSize: 13, color: growthMuted),
            ),
          if (failed && _months == 2)
            TextButton(
              onPressed: () => setState(() => _reference = _loadReference()),
              child: const Text('Thử lại'),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 9, color: _accent),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.bmiMode ? 'Thay đổi BMI của trẻ' : 'Mức tăng của trẻ',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          if (_months == 2 && range.$2 > _whoMax)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tham chiếu WHO chỉ áp dụng cho ${widget.headCircumference ? 'vòng đầu' : 'chiều dài nằm'} trong khoảng 0–$_whoMax tháng.',
                style: TextStyle(fontSize: 13, color: growthMuted),
              ),
            ),
          if (widget.bmiMode)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Chưa có chuẩn WHO riêng cho tốc độ thay đổi BMI. Xem BMI theo tuổi trong tab Tổng quan.',
                style: TextStyle(fontSize: 13, color: growthMuted),
              ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: (widget.bmiMode
                  ? const Color(0xFFEAF5E9)
                  : widget.headCircumference
                  ? const Color(0xFFF2ECF8)
                  : const Color(0xFFEAF3FA)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GrowthAsset(
                      widget.bmiMode
                          ? 'result-smile'
                          : widget.headCircumference
                          ? 'result-smile-head'
                          : 'result-smile-stature',
                      size: 48,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tốc độ ${widget.name.toLowerCase()} của bé thế nào?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  widget.bmiMode
                      ? 'Thay đổi BMI được ghi nhận'
                      : bounds == null
                      ? 'Chưa đủ căn cứ phân loại theo WHO'
                      : 'Đối chiếu khoảng tham chiếu WHO',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.bmiMode
                      ? 'BMI thay đổi khi cân nặng và chiều dài/chiều cao cùng thay đổi. Mức tăng hoặc giảm giữa các kỳ không tự xác định tình trạng dinh dưỡng.'
                      : comparison ?? 'Chưa có kết quả đối chiếu tốc độ phù hợp với giới tính, tuổi và kỳ đo này.',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đánh giá tốc độ hiện tại',
                  style: TextStyle(fontSize: 13, color: growthMuted),
                ),
                const SizedBox(height: 18),
                Text(
                  direction,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Xu hướng qua các tháng',
                  style: TextStyle(fontSize: 13, color: growthMuted),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nhận xét',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  comment,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),
                Material(
                  color: const Color(0xFFFFFEFA),
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    leading: const GrowthAsset('lightbulb', size: 26),
                    title: const Text(
                      'Vì sao có kết luận này?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => GrowthConclusionExplanationScreen(
                          easyRead: widget.easyRead,
                          introText:
                              'Cùng tìm hiểu mức tăng ${widget.name.toLowerCase()} của con qua các kỳ đo nhé!',
                          sources: activeReference == null
                              ? const {}
                              : {
                                  'WHO · tốc độ ${widget.name.toLowerCase()} · kỳ 2 tháng':
                                      activeReference.sourceUrl,
                                },
                          sections: [
                            if (widget.bmiMode)
                              const GrowthExplanationSection(
                                'BMI được xác định thế nào?',
                                'BMI = cân nặng (kg) / chiều dài hoặc chiều cao (m)². Mỗi giá trị sử dụng hai số đo cùng ngày. Chỉ so sánh các giá trị cách nhau đúng một tháng, cùng cách đo chiều dài/chiều cao.',
                              ),
                            GrowthExplanationSection(
                              '1. Dữ liệu được sử dụng',
                              latest == null
                                  ? 'Chưa đủ hai số đo cùng cách đo trong kỳ.'
                                  : '${date(latest.from.measuredAt)}: ${value(latest.from.value)} $measurementUnit; ${date(latest.to.measuredAt)}: ${value(latest.to.value)} $measurementUnit. Hai số đo cùng cách đo và cách nhau đúng $period.',
                            ),
                            GrowthExplanationSection(
                              '2. Cách tính',
                              latest == null
                                  ? 'Tốc độ = mức thay đổi ${widget.name.toLowerCase()} / số tháng giữa hai lần đo.'
                                  : '(${value(latest.to.value)} − ${value(latest.from.value)}) = ${signed(latest.change)} $measurementUnit trong $_months tháng (${value(latest.change / _months)} $measurementUnit/tháng trung bình).',
                            ),
                            GrowthExplanationSection(
                              '3. Xu hướng qua các tháng',
                              '$direction. $comment Tốc độ giảm so với kỳ trước không tự đồng nghĩa với bất thường.',
                            ),
                            GrowthExplanationSection(
                              '4. Căn cứ WHO',
                              widget.bmiMode
                                  ? 'Bộ chuẩn WHO không có dải tốc độ BMI riêng. Biểu đồ chỉ mô tả mức thay đổi BMI; không suy ra Z-score vận tốc hoặc tình trạng dinh dưỡng từ chiều hướng tăng/giảm. Xem BMI theo tuổi trong tab Tổng quan để đối chiếu theo tuổi và giới tính.'
                                  : comparison == null
                                  ? 'WHO không có chuẩn ${widget.name.toLowerCase()} kỳ một tháng. Tham chiếu kỳ hai tháng chỉ dùng cho ${widget.headCircumference ? 'vòng đầu' : 'chiều dài nằm'} từ 0 đến $_whoMax tháng, theo đúng giới tính; cần đủ hai số đo đúng kỳ. Không tự suy ra Z-score từ dải màu.'
                                  : '$comparison Dải màu biểu thị các giá trị −2 SD và +2 SD trong bảng WHO, không phải kết quả tính Z-score riêng của trẻ. Các kỳ hai tháng liền nhau có thể chồng lấn; nhận xét chỉ mô tả xu hướng.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatureVelocityPainter extends CustomPainter {
  _StatureVelocityPainter(
    this.points,
    this.ticks,
    this.selected,
    this.fontSize,
    this.months,
    this.reference,
    this.accent,
    this.bmiMode,
  );
  final List<GrowthStatureVelocityPoint> points;
  final List<int> ticks;
  final int? selected;
  final double fontSize;
  final int months;
  final Color accent;
  final bool bmiMode;
  final GrowthStatureVelocityReference? reference;
  late final rows =
      reference?.rows
          .where((r) => r.start + 2 <= ticks.last && r.start >= ticks.first)
          .toList() ??
      [];
  late final axis = growthVelocityValueAxis([
    if (points.every((p) => p.change == 0) && rows.isEmpty) 1,
    ...points.map((p) => p.change),
    ...rows.expand((r) => [r.low, r.high]),
  ]);
  Offset offset(double month, double value, Size s) => Offset(
    62 + (month - ticks.first) / (ticks.last - ticks.first) * (s.width - 76),
    12 + (axis.max - value) / (axis.max - axis.min) * (s.height - 56),
  );
  Offset point(int i, Size s) =>
      offset(points[i].startMonth + months / 2, points[i].change, s);
  void label(Canvas c, String text, Offset at, {bool centered = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: fontSize,
          color: const Color(0xFF62738D),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, centered ? Offset(at.dx - p.width / 2, at.dy) : at);
  }

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.clipRect(Rect.fromLTRB(62, 12, s.width - 14, s.height - 44));
    for (final r in rows) {
      final left = offset(r.start + .5, r.high, s);
      final right = offset(r.start + 1.5, r.low, s);
      c.drawRect(
        Rect.fromPoints(left, right),
        Paint()..color = accent.withValues(alpha: .44),
      );
      final medianLeft = offset(r.start + .5, r.median, s),
          medianRight = offset(r.start + 1.5, r.median, s);
      c.drawLine(
        medianLeft,
        medianRight,
        Paint()
          ..color = accent.withValues(alpha: .6)
          ..strokeWidth = 1,
      );
    }
    c.restore();
    final grid = Paint()
      ..color = const Color(0x709BAAB0)
      ..strokeWidth = .7;
    for (final v in axis.ticks) {
      final y = offset(ticks.first.toDouble(), v, s).dy;
      c.drawLine(Offset(62, y), Offset(s.width - 14, y), grid);
      label(c, formatGrowthValue(v), Offset(28, y - fontSize / 2));
    }
    for (final m in ticks) {
      final at = offset(m.toDouble(), axis.min, s);
      c.drawLine(Offset(at.dx, 12), at, grid);
      label(c, '$m', Offset(at.dx, s.height - 36), centered: true);
    }
    c.save();
    c.translate(5, s.height / 2 + 65);
    c.rotate(-math.pi / 2);
    label(
      c,
      bmiMode
          ? 'Thay đổi (kg/m²/tháng)'
          : months == 1
          ? 'Mức tăng (cm/tháng)'
          : 'Mức tăng (cm/2 tháng)',
      Offset.zero,
    );
    c.restore();
    label(
      c,
      'Tuổi (tháng)',
      Offset((62 + s.width - 14) / 2, s.height - 16),
      centered: true,
    );
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final at = point(i, s);
      if (i == 0 || points[i].startMonth != points[i - 1].startMonth + 1) {
        path.moveTo(at.dx, at.dy);
      } else {
        path.lineTo(at.dx, at.dy);
      }
    }
    c.drawPath(
      path,
      Paint()
        ..color = accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      final at = point(i, s);
      if (i == selected) {
        c.drawCircle(at, 8, Paint()..color = accent.withValues(alpha: .21));
      }
      c.drawCircle(at, 3.5, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _StatureVelocityPainter old) =>
      old.points != points ||
      old.ticks != ticks ||
      old.selected != selected ||
      old.months != months ||
      old.bmiMode != bmiMode ||
      old.reference != reference ||
      old.fontSize != fontSize;
}
