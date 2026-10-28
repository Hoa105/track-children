import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_visuals.dart';
import 'growth_stature_age_axis.dart';
import 'growth_status_badge.dart';
import 'growth_chart_explanation_dialog.dart';
import 'growth_weight_assessment.dart';
import 'growth_weight_velocity.dart';
import 'growth_weight_history.dart';
import 'growth_weight_input.dart';
import 'growth_weight_stature_chart.dart';
import 'growth_weight_chart_legend.dart';

int growthWeightAgeStart(int end) =>
    const {0: 0, 3: 0, 6: 3, 9: 6, 12: 9, 36: 12, 60: 36}[end]!;

bool growthWeightAgeInRange(double age, int end) =>
    age >= growthWeightAgeStart(end) &&
    (end == 0
        ? age <= 60
        : end == 60
        ? age <= end
        : age < end);

class GrowthWeightDetailScreen extends StatefulWidget {
  const GrowthWeightDetailScreen({
    required this.repository,
    this.easyReadMode = false,
    super.key,
  });
  final GrowthRepository repository;
  final bool easyReadMode;
  @override
  State<GrowthWeightDetailScreen> createState() =>
      _GrowthWeightDetailScreenState();
}

class _GrowthWeightDetailScreenState extends State<GrowthWeightDetailScreen> {
  late Future<List<GrowthMeasurementDraft>> _measurements = _load();
  GrowthMeasurementDraft? _selected;
  String? _selectedTab;
  String get _tab => _selectedTab ?? 'T\u1ed5ng quan';
  int? _selectedAgeEnd;
  int get _ageRange => _selectedAgeEnd ?? 0;
  int get _ageStart => growthWeightAgeStart(_ageRange);
  late bool _showTooltip = true;
  GrowthWeightReference? _referenceData;
  bool _referenceFailed = false;
  GrowthStatureReference? _statureReference;
  List<GrowthMeasurementDraft>? _loadedStatureMeasurements;
  List<GrowthMeasurementDraft> get _statureMeasurements =>
      _loadedStatureMeasurements ?? const <GrowthMeasurementDraft>[];

  Future<List<GrowthMeasurementDraft>> _load() {
    final future = _loadData();
    future.ignore();
    return future;
  }

  Future<List<GrowthMeasurementDraft>> _loadData() async {
    final data = await widget.repository.weightMeasurements();
    try {
      _loadedStatureMeasurements = await widget.repository.measurements(
        GrowthMetric.lengthHeight,
      );
    } catch (_) {
      _loadedStatureMeasurements = const [];
    }
    try {
      _referenceData = await widget.repository.weightReference();
      _referenceFailed = false;
    } catch (_) {
      _referenceData = null;
      _referenceFailed = true;
    }
    final sorted = [...data]
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final birth = widget.repository.dateOfBirth;
    final age = birth == null || sorted.isEmpty
        ? null
        : growthChartAgeMonths(birth, sorted.last.measuredAt);
    try {
      _statureReference = age == null
          ? null
          : await widget.repository.statureReference(age < 24);
    } catch (_) {
      _statureReference = null;
    }
    return sorted;
  }

  Future<void> _update() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/growth/weight-input'),
        builder: (_) => GrowthWeightInputScreen(
          repository: widget.repository,
          easyReadMode: widget.easyReadMode,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _selected = null;
        _showTooltip = true;
        _measurements = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final easy = widget.easyReadMode;
    final large = MediaQuery.textScalerOf(context).scale(20) > 30;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Nunito',
          bodyColor: growthInk,
          displayColor: growthInk,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: growthWeightOrange),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: growthInk,
            toolbarHeight: large ? 120 : 56,
            centerTitle: true,
            leading: IconButton(
              tooltip: 'Về tổng quan tăng trưởng',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrowthAsset('overview-weight', size: 30),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Cân nặng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn cân nặng',
                icon: const Icon(Icons.more_horiz),
                onSelected: (_) => _update(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'update',
                    child: Text('Cập nhật cân nặng'),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  children: [
                    for (final label in ['Tổng quan', 'Tốc độ', 'Lịch sử'])
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: label == _tab
                                    ? growthWeightOrange
                                    : const Color(0xFFEEF0EC),
                                width: label == _tab ? 2 : 1,
                              ),
                            ),
                          ),
                          child: Semantics(
                            selected: label == _tab,
                            child: TextButton(
                              onPressed: () {
                                setState(() => _selectedTab = label);
                              },
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: label == _tab
                                      ? growthWeightOrange
                                      : growthMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: FutureBuilder<List<GrowthMeasurementDraft>>(
                    future: _measurements,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Đang tải cân nặng',
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Chưa tải được cân nặng.'),
                              TextButton(
                                onPressed: () => setState(() {
                                  _measurements = _load();
                                }),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        );
                      }
                      final points = snapshot.data ?? [];
                      if (points.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const GrowthAsset('no-measurements', size: 96),
                                const SizedBox(height: 16),
                                const Text('Chưa có số đo cân nặng'),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _update,
                                  child: const Text('Cập nhật cân nặng'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (_tab == 'T\u1ed1c \u0111\u1ed9') {
                        return GrowthWeightVelocityTab(
                          repository: widget.repository,
                          readings: points,
                          easyRead: easy,
                        );
                      }
                      if (_tab == 'Lịch sử') {
                        return GrowthWeightHistoryTab(
                          readings: points,
                          repository: widget.repository,
                          easyRead: easy,
                        );
                      }
                      final latest = points.last;
                      final previous = points.length > 1
                          ? points[points.length - 2]
                          : null;
                      final grams = previous == null
                          ? null
                          : ((latest.value - previous.value) * 1000).round();
                      final birth = widget.repository.dateOfBirth;
                      final ageMonths = birth == null
                          ? null
                          : growthChartAgeMonths(birth, latest.measuredAt);
                      final statureLabel = ageMonths == null
                          ? 'chiều dài/chiều cao'
                          : ageMonths < 24
                          ? 'chiều dài'
                          : 'chiều cao';
                      final visiblePoints = birth == null
                          ? <GrowthMeasurementDraft>[]
                          : points.where((point) {
                              final age = growthChartAgeMonths(
                                birth,
                                point.measuredAt,
                              );
                              return age != null &&
                                  growthWeightAgeInRange(age, _ageRange);
                            }).toList();
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WeightCurrentHeader(
                              latest: latest,
                              easyRead: easy,
                              onUpdate: _update,
                            ),
                            const SizedBox(height: 20),
                            _WeightSummaryNotes(
                              statureLabel: statureLabel,
                              measuredAt: latest.measuredAt,
                              previous: previous,
                              grams: grams,
                              easyRead: easy,
                            ),
                            const SizedBox(height: 24),
                            GrowthAgeChartHeading(
                              months: _ageRange,
                              easyRead: easy,
                              onChanged: (value) => setState(() {
                                _selectedAgeEnd = value;
                                _selected = null;
                                _showTooltip = true;
                              }),
                            ),
                            const SizedBox(height: 12),
                            GrowthWeightMeasurementChart(
                              seriesColor: growthWeightOrange,
                              zScoreForPoint: (point) => widget.repository
                                  .weightAssessmentFor(point, null)
                                  ?.wfa
                                  ?.zScore,
                              points: visiblePoints,
                              reference: _referenceData,
                              dateOfBirth: birth,
                              minAgeMonths: _ageStart,
                              maxAgeMonths: _ageRange == 0 ? 60 : _ageRange,
                              showTooltip: _showTooltip,
                              selectedPoint: _selected,
                              onHover: (point) {
                                if (_selected == point) return;
                                setState(() {
                                  _selected = point;
                                  _showTooltip = point != null;
                                });
                              },
                              easyReadMode: easy,
                              onSelect: (point) => setState(() {
                                _selected = point;
                                _showTooltip = true;
                              }),
                            ),
                            const SizedBox(height: 8),
                            if (_referenceData == null)
                              const GrowthWeightChartLegend(
                                seriesColor: growthWeightOrange,
                              ),
                            if (_referenceData != null)
                              const GrowthWeightReferenceLegend(
                                seriesColor: growthWeightOrange,
                              ),
                            const SizedBox(height: 18),
                            Transform.rotate(
                              angle: easy ? 0 : -.035,
                              child: CustomPaint(
                                painter: const GrowthNotePaperPainter(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  child: Text(
                                    'Vùng màu thể hiện cân nặng của bé so với chuẩn WHO theo tuổi và giới tính. Xem thêm Cân nặng theo $statureLabel để đánh giá mức độ cân đối',
                                    style: TextStyle(
                                      fontFamily: easy
                                          ? 'Nunito'
                                          : 'DancingScript',
                                      fontSize: 18,
                                      height: 1.4,
                                      color: const Color(0xFF20365D),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!easy)
                              const Align(
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: EdgeInsets.zero,
                                  child: GrowthAsset(
                                    'weight-chart-arrow-left',
                                    size: 56,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 16),
                            GrowthWeightStatureChart(
                              zScoreForDate: (date) {
                                final weight = points
                                    .where(
                                      (p) => DateUtils.isSameDay(
                                        p.measuredAt,
                                        date,
                                      ),
                                    )
                                    .lastOrNull;
                                final stature = _statureMeasurements
                                    .where(
                                      (p) => DateUtils.isSameDay(
                                        p.measuredAt,
                                        date,
                                      ),
                                    )
                                    .lastOrNull;
                                return weight == null
                                    ? null
                                    : widget.repository
                                          .weightAssessmentFor(weight, stature)
                                          ?.wflh
                                          ?.zScore;
                              },
                              easyReadMode: easy,
                              reference: _statureReference,
                              weights: points,
                              statures: _statureMeasurements,
                              dateOfBirth: birth,
                              useLength: ageMonths == null
                                  ? null
                                  : ageMonths < 24,
                              statureLabel: statureLabel,
                            ),
                            if (_referenceFailed)
                              TextButton(
                                onPressed: () => setState(() {
                                  _measurements = _load();
                                }),
                                child: const Text(
                                  'Chưa tải được đường WHO. Thử lại',
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (_selected != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFE9EDE8),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_formatDate(_selected!.measuredAt)} · ${formatGrowthValue(_selected!.value)} kg',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Đóng chi tiết điểm đo',
                                          onPressed: () => setState(() {
                                            _selected = null;
                                            _showTooltip = false;
                                          }),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            GrowthWeightAssessment(
                              measuredAt: latest.measuredAt,
                              statureMeasurement: _statureMeasurements
                                  .where(
                                    (point) => DateUtils.isSameDay(
                                      point.measuredAt,
                                      latest.measuredAt,
                                    ),
                                  )
                                  .firstOrNull,
                              ageMonths: birth == null
                                  ? null
                                  : (latest.measuredAt
                                                .difference(birth)
                                                .inDays <
                                            0
                                        ? -1
                                        : ageMonths ?? 61),
                              sexLabel: _referenceData?.sexLabel,
                              assessment: widget.repository.weightAssessmentFor(
                                latest,
                                _statureMeasurements
                                    .where(
                                      (point) => DateUtils.isSameDay(
                                        point.measuredAt,
                                        latest.measuredAt,
                                      ),
                                    )
                                    .firstOrNull,
                              ),
                              easyRead: easy,
                              weight: latest.value,
                              statureLabel: statureLabel,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Mức thay đổi ghi nhận chưa phải đánh giá tốc độ theo WHO.',
                              style: TextStyle(
                                fontSize: easy ? 18 : 14,
                                height: 1.4,
                                color: growthMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightCurrentHeader extends StatelessWidget {
  const _WeightCurrentHeader({
    required this.latest,
    required this.easyRead,
    required this.onUpdate,
  });
  final GrowthMeasurementDraft latest;
  final bool easyRead;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final measurement = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cân nặng hiện tại',
            style: TextStyle(
              fontSize: easyRead ? 20 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                '${formatGrowthValue(latest.value)} kg',
                style: TextStyle(
                  fontSize: easyRead ? 36 : 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF172A4B),
                ),
              ),
              IconButton(
                tooltip: 'Cập nhật cân nặng',
                onPressed: onUpdate,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF62738D),
                ),
              ),
            ],
          ),
          Text(
            'Ngày đo: ${_formatDate(latest.measuredAt)}',
            style: TextStyle(
              fontSize: easyRead ? 18 : 13,
              color: const Color(0xFF62738D),
            ),
          ),
        ],
      );
      final reference = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GrowthStatusBadge(
            label: 'Ph\u00f9 h\u1ee3p',
            icon: Icons.check_rounded,
            foreground: const Color(0xFF9A4D1D),
            background: const Color(0xFFFFEDD9),
            angle: easyRead ? 0 : -.045,
            easyRead: easyRead,
          ),
          const SizedBox(height: 12),
          GrowthStatusBadge(
            label: 'C\u00e2n \u0111\u1ed1i',
            icon: Icons.drag_handle_rounded,
            foreground: const Color(0xFFAE652B),
            background: const Color(0xFFFFF3E5),
            angle: easyRead ? 0 : .045,
            easyRead: easyRead,
          ),
        ],
      );
      final stacked =
          easyRead ||
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(15) > 21;
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                measurement,
                const SizedBox(height: 16),
                SizedBox(width: 172, child: reference),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: measurement),
                const SizedBox(width: 12),
                SizedBox(width: 132, child: reference),
              ],
            );
    },
  );
}

String growthRelativeMeasurementInterval(DateTime previous, DateTime current) {
  var months =
      (current.year - previous.year) * 12 + current.month - previous.month;
  if (current.day < previous.day) months--;
  if (months > 0) return 'so với $months tháng trước';
  final days = DateTime.utc(current.year, current.month, current.day)
      .difference(DateTime.utc(previous.year, previous.month, previous.day))
      .inDays;
  return days > 0 ? 'so với $days ngày trước' : 'so với lần đo cùng ngày';
}

class _WeightNotePaper extends StatelessWidget {
  const _WeightNotePaper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const GrowthNotePaperPainter(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: child,
    ),
  );
}

class _WeightSummaryNotes extends StatelessWidget {
  const _WeightSummaryNotes({
    required this.statureLabel,
    required this.measuredAt,
    required this.previous,
    required this.grams,
    required this.easyRead,
  });
  final GrowthMeasurementDraft? previous;
  final DateTime measuredAt;
  final String statureLabel;
  final int? grams;
  final bool easyRead;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Flexible(
            child: Transform.rotate(
              angle: easyRead ? 0 : -.12,
              child: _WeightNotePaper(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: grams == null
                            ? 'Chưa đủ số đo để so sánh'
                            : grams == 0
                            ? 'Cân nặng không đổi'
                            : '${grams! > 0 ? 'Tăng' : 'Giảm'} ${grams!.abs()}g',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: growthWeightOrange,
                        ),
                      ),
                      if (previous != null)
                        TextSpan(
                          text:
                              '\n${growthRelativeMeasurementInterval(previous!.measuredAt, measuredAt)}',
                          style: TextStyle(fontSize: easyRead ? 16 : 17),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: easyRead ? 'Nunito' : 'DancingScript',
                    fontSize: easyRead ? 20 : 21,
                    height: 1.2,
                    color: const Color(0xFF20365D),
                  ),
                ),
              ),
            ),
          ),
          if (!easyRead)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: GrowthAsset('weight-note-arrow', size: 64),
            ),
        ],
      ),
      SizedBox(height: easyRead ? 8 : 0),
      Transform.translate(
        offset: easyRead ? const Offset(0, -30) : const Offset(-8, -26),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Transform.rotate(
              angle: easyRead ? 0 : -.12,
              alignment: Alignment.centerRight,
              child: _WeightNotePaper(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GrowthAsset('overview-chart', size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Cân nặng của bé hiện phù hợp với tuổi\nvà cân đối với $statureLabel',
                        style: TextStyle(
                          fontFamily: easyRead ? 'Nunito' : 'DancingScript',
                          fontSize: easyRead ? 18 : 18,
                          height: 1.25,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class GrowthAgeChartHeading extends StatelessWidget {
  const GrowthAgeChartHeading({
    super.key,
    this.title = 'C\u00e2n n\u1eb7ng theo \u0111\u1ed9 tu\u1ed5i',
    this.onExplain,
    required this.months,
    required this.easyRead,
    required this.onChanged,
  });
  final int months;
  final bool easyRead;
  final ValueChanged<int> onChanged;
  final String title;
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Row(
        children: [
          Expanded(
            child: Text(
              this.title,
              style: TextStyle(
                fontSize: easyRead ? 20 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Giải thích biểu đồ cân nặng',
            icon: const Icon(Icons.info_outline, size: 18),
            color: const Color(0xFF62738D),
            onPressed:
                onExplain ??
                () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => GrowthChartExplanationDialog(
                    title: const Text('Về biểu đồ cân nặng'),
                    content: const Text(
                      'Biểu đồ thể hiện cân nặng (kg) theo tuổi tại ngày đo, tính từ ngày sinh được cung cấp. '
                      'Các đường WHO −3 SD, −2 SD, trung vị, +2 SD, +3 SD được vẽ từ bảng theo giới tính khi có dữ liệu. '
                      'Đường tham chiếu không phải kết luận đánh giá cho số đo của bé.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      );
      final filter = Container(
        width: easyRead ? 160 : 132,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE1E7EB)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: months,
            isDense: true,
            iconSize: 18,
            isExpanded: true,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: easyRead ? 18 : 12,
              color: const Color(0xFF20365D),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('To\u00e0n b\u1ed9')),
              DropdownMenuItem(value: 3, child: Text('0 – 3 tháng')),
              DropdownMenuItem(value: 6, child: Text('3 – 6 tháng')),
              DropdownMenuItem(value: 9, child: Text('6 – 9 tháng')),
              DropdownMenuItem(value: 12, child: Text('9 – 12 tháng')),
              DropdownMenuItem(value: 36, child: Text('1 – 3 tuổi')),
              DropdownMenuItem(value: 60, child: Text('3 – 5 tuổi')),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      );
      return easyRead ||
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(15) > 21
          ? Column(
              children: [
                title,
                Align(alignment: Alignment.centerRight, child: filter),
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                filter,
              ],
            );
    },
  );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class GrowthWeightMeasurementChart extends StatelessWidget {
  const GrowthWeightMeasurementChart({
    required this.points,
    required this.onSelect,
    this.easyReadMode = false,
    this.dateOfBirth,
    this.maxAgeMonths = 60,
    this.minAgeMonths = 0,
    this.selectedPoint,
    this.showTooltip = true,
    this.reference,
    this.zScoreForPoint,
    this.onHover,
    this.unit = 'kg',
    this.axisTitle = 'Cân nặng (kg)',
    this.seriesColor = const Color(0xFF329B6F),
    this.bandColor = const Color(0x482DB878),
    this.medianColor,
    this.fitValueAxis = false,
    super.key,
  });
  final List<GrowthMeasurementDraft> points;
  final ValueChanged<GrowthMeasurementDraft> onSelect;
  final double? Function(GrowthMeasurementDraft)? zScoreForPoint;
  final ValueChanged<GrowthMeasurementDraft?>? onHover;
  final bool easyReadMode;
  final DateTime? dateOfBirth;
  final int maxAgeMonths;
  final int minAgeMonths;
  final GrowthMeasurementDraft? selectedPoint;
  final bool showTooltip;
  final GrowthWeightReference? reference;
  final String unit, axisTitle;
  final Color seriesColor, bandColor;
  final Color? medianColor;
  final bool fitValueAxis;

  String _ageLabel(GrowthMeasurementDraft point) {
    final age = dateOfBirth == null
        ? null
        : growthChartAgeMonths(dateOfBirth!, point.measuredAt);
    if (age == null) return 'Chưa có tuổi tại ngày đo';
    return '${formatGrowthValue(age)} tháng';
  }

  @override
  Widget build(BuildContext context) {
    if (dateOfBirth == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          unit == 'kg'
              ? 'Chưa có ngày sinh để hiển thị cân nặng theo độ tuổi.'
              : 'Chưa có ngày sinh để hiển thị chiều dài/chiều cao theo độ tuổi.',
        ),
      );
    }
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Chưa có số đo trong khoảng tuổi này.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, easyReadMode ? 300 : 230);
        final scaled = MediaQuery.textScalerOf(context)
            .scale(easyReadMode ? 15 : 12);
        final painter = _WeightChartPainter(
          points,
          birth: dateOfBirth!,
          minAge: minAgeMonths,
          maxAge: maxAgeMonths,
          labelSize: scaled,
          selected: selectedPoint,
          reference: reference,
          axisTitle: axisTitle,
          seriesColor: seriesColor,
          bandColor: bandColor,
          medianColor: medianColor,
          fitValueAxis: fitValueAxis,
        );
        final index = selectedPoint == null
            ? -1
            : points.indexOf(selectedPoint!);
        final selected = index < 0 || !showTooltip ? null : points[index];
        final position = index < 0 || !showTooltip
            ? null
            : painter.offsetFor(index, size);
        final tooltipSpan = selected == null
            ? const TextSpan(text: '')
            : growthMeasurementTooltipSpan(
                measurement: '${formatGrowthValue(selected.value)} $unit',
                zScore: growthTooltipZScore(zScoreForPoint?.call(selected)),
                contextLabel: _ageLabel(selected),
                date: _formatDate(selected.measuredAt),
              );
        final tooltipWidth = math.min(
          easyReadMode ? 260.0 : 220.0,
          size.width - 68,
        );
        final tooltipMeasure = TextPainter(
          text: tooltipSpan,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: tooltipWidth - 20);
        return Column(
          children: [
            Semantics(
              label:
                  'Biểu đồ theo tuổi. Trục ngang: tuổi theo tháng, trục dọc: $axisTitle.',
              child: GestureDetector(
                onTapUp: (details) {
                  var closest = 0;
                  var distance = double.infinity;
                  for (var i = 0; i < points.length; i++) {
                    final d =
                        (painter.offsetFor(i, size) - details.localPosition)
                            .distance;
                    if (d < distance) {
                      closest = i;
                      distance = d;
                    }
                  }
                  if (distance <= 36) onSelect(points[closest]);
                },
                child: MouseRegion(
                  onExit: (_) => onHover?.call(null),
                  onHover: (event) {
                    GrowthMeasurementDraft? closest;
                    var distance = 16.0;
                    for (var i = 0; i < points.length; i++) {
                      final d =
                          (painter.offsetFor(i, size) - event.localPosition)
                              .distance;
                      if (d <= distance) {
                        closest = points[i];
                        distance = d;
                      }
                    }
                    onHover?.call(closest);
                  },
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: painter)),
                        if (position != null)
                          Positioned(
                            left: (position.dx + 12).clamp(
                              64,
                              size.width - tooltipWidth - 4,
                            ),
                            top: (position.dy - tooltipMeasure.height - 30)
                                .clamp(
                                  4,
                                  math.max(
                                    4,
                                    size.height - tooltipMeasure.height - 64,
                                  ),
                                ),
                            width: tooltipWidth,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE9EDE8),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x10000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text.rich(tooltipSpan),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Text(
              'Tuổi (tháng)',
              style: TextStyle(fontSize: 13, color: Color(0xFF62738D)),
            ),
          ],
        );
      },
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter(
    this.points, {
    required this.birth,
    required this.maxAge,
    required this.minAge,
    required this.labelSize,
    this.selected,
    this.reference,
    required this.axisTitle,
    required this.seriesColor,
    required this.bandColor,
    this.medianColor,
    this.fitValueAxis = false,
  });
  final List<GrowthMeasurementDraft> points;
  final DateTime birth;
  final int maxAge, minAge;
  final double labelSize;
  final GrowthMeasurementDraft? selected;
  final GrowthWeightReference? reference;
  final String axisTitle;
  final Color seriesColor, bandColor;
  final Color? medianColor;
  final bool fitValueAxis;
  Color get unitMedianColor =>
      medianColor ??
      (axisTitle.endsWith('(cm)')
          ? const Color(0xFF8ABDDD)
          : const Color(0xFF79C99B));
  // These inputs do not change during a painter's lifetime. In particular,
  // never rescan the WHO table for each coordinate or pointer hit test.
  late final List<GrowthWeightReferenceRow> _visibleReferenceRows =
      reference?.rows
          .where((row) => row.month >= minAge && row.month <= maxAge)
          .toList(growable: false) ??
      const [];
  late final List<double> _pointAges = [
    for (final point in points)
      growthChartAgeMonths(birth, point.measuredAt) ?? 0,
  ];
  late final ({double min, double max, double step}) cmAxis =
      growthStatureAgeAxis([
        ...points.map((p) => p.value),
        ..._visibleReferenceRows.expand((row) => row.weights),
      ]);
  late final double low = (fitValueAxis || axisTitle.endsWith('(cm)'))
      ? cmAxis.min
      : 0;
  late final double high = _resolveHigh();
  double _resolveHigh() {
    if (fitValueAxis || axisTitle.endsWith('(cm)')) return cmAxis.max;
    final childMax = points.map((p) => p.value).fold(0.0, math.max);
    final referenceMax = _visibleReferenceRows
        .map((row) => row.weights.last)
        .fold(0.0, math.max);
    return math
        .max(5, ((math.max(childMax, referenceMax) + 1) / 5).ceil() * 5)
        .toDouble();
  }

  Offset _referenceOffset(GrowthWeightReferenceRow row, int index, Size size) =>
      Offset(
        62 + (row.month - minAge) / (maxAge - minAge) * (size.width - 76),
        12 + ((high - row.weights[index]) / (high - low)) * (size.height - 56),
      );

  Path _referencePath(int index, Size size) {
    final path = Path();
    final rows = _visibleReferenceRows;
    for (var i = 0; i < rows.length; i++) {
      final p = _referenceOffset(rows[i], index, size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  void _paintBand(Canvas canvas, Size size, int lower, int upper, Color color) {
    final rows = _visibleReferenceRows;
    final path = _referencePath(lower, size);
    for (final row in rows.reversed) {
      final p = _referenceOffset(row, upper, size);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Offset offsetFor(int index, Size size) {
    final age = _pointAges[index];
    return Offset(
      62 + (age - minAge) / (maxAge - minAge) * (size.width - 76),
      12 + ((high - points[index].value) / (high - low)) * (size.height - 56),
    );
  }

  void _label(Canvas canvas, String text, Offset at, {bool centered = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: labelSize,
          color: const Color(0xFF62738D),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, Offset(centered ? at.dx - p.width / 2 : at.dx, at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x709BAAB0)
      ..strokeWidth = .7;
    final bottom = size.height - 44;
    if (fitValueAxis || axisTitle.endsWith('(cm)')) {
      final axis = cmAxis;
      for (var i = 0; i <= ((axis.max - axis.min) / axis.step).round(); i++) {
        final value = axis.min + i * axis.step;
        final y = 12 + (high - value) / (high - low) * (size.height - 56);
        canvas.drawLine(Offset(62, y), Offset(size.width - 14, y), grid);
        _label(canvas, formatGrowthValue(value), Offset(29, y - labelSize / 2));
      }
    } else {
      for (var i = 0; i <= 3; i++) {
        final y = 12 + i / 3 * (size.height - 56);
        canvas.drawLine(Offset(62, y), Offset(size.width - 14, y), grid);
        _label(
          canvas,
          formatGrowthValue(high * (1 - i / 3)),
          Offset(29, y - labelSize / 2),
        );
      }
    }
    final divisions = labelSize > 20
        ? 3
        : maxAge == 60
        ? 5
        : 4;
    for (var i = 0; i <= divisions; i++) {
      final x = 62 + i / divisions * (size.width - 76);
      canvas.drawLine(Offset(x, 12), Offset(x, bottom), grid);
      _label(
        canvas,
        formatGrowthValue(minAge + (maxAge - minAge) * i / divisions),
        Offset(x, bottom + 8),
        centered: true,
      );
    }
    if (reference != null) {
      _paintBand(canvas, size, 0, 4, const Color(0x38F0AE52));
      _paintBand(canvas, size, 1, 3, bandColor);
    }
    canvas.save();
    canvas.translate(5, bottom / 2 + 46);
    canvas.rotate(-math.pi / 2);
    _label(canvas, axisTitle, Offset.zero);
    canvas.restore();
    if (reference != null) {
      final colors = [
        Color(0xFFFF8D79),
        Color(0xFFF0BE75),
        unitMedianColor,
        Color(0xFFF0BE75),
        Color(0xFFFF8D79),
      ];
      for (var i = 0; i < 5; i++) {
        canvas.drawPath(
          _referencePath(i, size),
          Paint()
            ..color = colors[i]
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      }
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = offsetFor(i, size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final paint = Paint()
      ..color = seriesColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final p = offsetFor(i, size);
      if (identical(points[i], selected)) {
        canvas.drawCircle(
          p,
          8,
          Paint()..color = seriesColor.withValues(alpha: .21),
        );
      }
      canvas.drawCircle(p, 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maxAge != maxAge ||
      oldDelegate.minAge != minAge ||
      oldDelegate.selected != selected ||
      oldDelegate.reference != reference ||
      oldDelegate.labelSize != labelSize ||
      oldDelegate.birth != birth ||
      oldDelegate.axisTitle != axisTitle ||
      oldDelegate.seriesColor != seriesColor ||
      oldDelegate.bandColor != bandColor ||
      oldDelegate.medianColor != medianColor ||
      oldDelegate.fitValueAxis != fitValueAxis;
}
