import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
export 'growth_repository.dart';
import 'growth_tracking_flow.dart';
import '../navigation/app_bottom_navigation_bar.dart';

class GrowthOverview extends StatefulWidget {
  const GrowthOverview({
    super.key,
    this.repository,
    this.onNavigation,
    this.openEditorOnStart = false,
  });
  final GrowthRepository? repository;
  final ValueChanged<String>? onNavigation;
  final bool openEditorOnStart;
  @override
  State<GrowthOverview> createState() => _GrowthOverviewState();
}

class _GrowthOverviewState extends State<GrowthOverview> {
  late final GrowthRepository _repository =
      widget.repository ?? MockGrowthRepository();
  late Future<List<List<GrowthMeasurementDraft>>> _data;
  GrowthMetric _metric = GrowthMetric.weight;
  bool _didOpenEditor = false;
  static const _teal = AppColors.primary;
  static const _ink = AppColors.textPrimary;
  static const _paper = AppColors.background;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = () async {
      await _repository.refreshMeasurements();
      return Future.wait(GrowthMetric.values.map(_repository.measurements));
    }();
    _data.then((_) {
      if (mounted) setState(() {});
      if (mounted && widget.openEditorOnStart && !_didOpenEditor) {
        _didOpenEditor = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _add();
        });
      }
    }, onError: (Object _) {});
    _data.ignore();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(_reload);
  }

  Future<void> _add() async {
    if (!_repository.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có quyền xem số đo.')),
      );
      return;
    }
    if (await openTrackingEditor(context, _repository) && mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu số đo')));
    }
  }

  String _date(DateTime day) => trackingDate(day);
  List<GrowthMeasurementDraft> _sorted(List<GrowthMeasurementDraft> rows) =>
      [...rows]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  Widget _profile() {
    final birth = _repository.dateOfBirth;
    final months = birth == null
        ? null
        : growthChartAgeMonths(birth, DateTime.now())?.floor();
    final age = months == null
        ? null
        : months < 12
        ? '$months tháng tuổi'
        : '${months ~/ 12} tuổi${months % 12 == 0 ? '' : ' ${months % 12} tháng'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: AppColors.primarySoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bé ${_repository.childLabel ?? 'của bạn'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (age != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        age,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(GrowthMetric metric, List<GrowthMeasurementDraft> rows) {
    final latest = rows.lastOrNull;
    final (icon, tint, color) = switch (metric) {
      GrowthMetric.weight => (
        Icons.monitor_weight_outlined,
        const Color(0xFFFFEFE5),
        const Color(0xFFAD714F),
      ),
      GrowthMetric.lengthHeight => (
        Icons.height,
        const Color(0xFFE8F2EA),
        const Color(0xFF4E8269),
      ),
      GrowthMetric.headCircumference => (
        Icons.face_retouching_natural_outlined,
        const Color(0xFFF0ECF8),
        const Color(0xFF85709E),
      ),
    };
    final title = metric == GrowthMetric.lengthHeight
        ? latest?.method == GrowthMeasurementMethod.recumbent
              ? 'Chiều dài'
              : latest?.method == GrowthMeasurementMethod.standing
              ? 'Chiều cao'
              : 'Dài/cao'
        : metric.title;
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(
          TrackingHistoryScreen(repository: _repository, metric: metric),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(180),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(150),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (latest == null)
                const Text(
                  'Chưa có',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatGrowthValue(latest.value),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: ' ${metric.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                latest == null ? 'Chưa có số đo' : _date(latest.measuredAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(List<List<GrowthMeasurementDraft>> rows) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        for (final metric in GrowthMetric.values)
          _tile(metric, rows[metric.index]),
      ];
      if (constraints.maxWidth < 270 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(width: double.infinity, child: card),
              ),
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    },
  );

  Widget _assessment() => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      splashFactory: InkSparkle.splashFactory,
      splashColor: AppColors.primarySoft,
      highlightColor: AppColors.primarySoft.withAlpha(110),
      onTap: () =>
          _open(TrackingAssessmentScreen(repository: _repository, kind: 'bmi')),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: _teal,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tình trạng cân nặng',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_repository.pairingInfo?['ready'] == false)
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        'Cần thêm số đo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF617B71),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: _teal,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _headAssessment() => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      splashFactory: InkSparkle.splashFactory,
      splashColor: AppColors.purpleSurfaceLight,
      highlightColor: AppColors.purpleSurfaceLight.withAlpha(150),
      onTap: () => _open(
        TrackingAssessmentScreen(repository: _repository, kind: 'head'),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.purpleSurfaceLight,
                borderRadius: BorderRadius.all(Radius.circular(13)),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.face_retouching_natural_outlined,
                  color: AppColors.purpleText,
                  size: 22,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tình trạng vòng đầu',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.purpleSurfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: _teal,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _expand(List<GrowthMeasurementDraft> rows) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(_metric.title)),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _MeasurementChart(
                rows: rows,
                birth: _repository.dateOfBirth,
                metric: _metric,
                zoom: true,
              ),
            ),
          ),
        ),
      );

  Widget _chart(List<GrowthMeasurementDraft> rows) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Biểu đồ số đo',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Phóng to',
              onPressed: () => _expand(rows),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: _teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.open_in_full, size: 17, color: _teal),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final metric in GrowthMetric.values)
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
                    selected: _metric == metric,
                    selectedColor: _teal,
                    backgroundColor: AppColors.background,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                    onSelected: (_) => setState(() => _metric = metric),
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        metric == GrowthMetric.lengthHeight
                            ? 'Dài/cao'
                            : metric.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _metric == metric
                              ? Colors.white
                              : const Color(0xFF71817E),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MeasurementChart(
          key: ValueKey(_metric),
          rows: rows,
          birth: _repository.dateOfBirth,
          metric: _metric,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _teal,
        surface: Colors.white,
      ),
      textTheme: Theme.of(context).textTheme
          .apply(fontFamily: 'Nunito', bodyColor: _ink, displayColor: _ink),
    ),
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: _paper,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tăng trưởng',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selected: 'Theo dõi',
        onTap: (destination) {
          if (destination == 'Theo dõi') return;
          if (destination == 'Tạo ghi chép') {
            _add();
            return;
          }
          if (widget.onNavigation != null) {
            widget.onNavigation!(destination);
          } else if (destination == 'Trang chủ' &&
              Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<List<GrowthMeasurementDraft>>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Đang tải số đo',
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Chưa tải được số đo.'),
                    TextButton(
                      onPressed: () => setState(_reload),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              );
            }
            final rows =
                (snapshot.data ??
                        [
                          for (final _ in GrowthMetric.values)
                            <GrowthMeasurementDraft>[],
                        ])
                    .map(_sorted)
                    .toList();
            return RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                await _data;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _profile(),
                  _summary(rows),
                  const SizedBox(height: 12),
                  _assessment(),
                  const SizedBox(height: 10),
                  _headAssessment(),
                  const SizedBox(height: 20),
                  _chart(rows[_metric.index]),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _MeasurementChart extends StatefulWidget {
  const _MeasurementChart({
    super.key,
    required this.rows,
    required this.birth,
    required this.metric,
    this.zoom = false,
  });
  final List<GrowthMeasurementDraft> rows;
  final DateTime? birth;
  final GrowthMetric metric;
  final bool zoom;
  @override
  State<_MeasurementChart> createState() => _MeasurementChartState();
}

class _MeasurementChartState extends State<_MeasurementChart> {
  static const _maxVisiblePoints = 60;
  GrowthMeasurementDraft? _selected;
  @override
  Widget build(BuildContext context) {
    final birth = widget.birth;
    if (birth == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Cần ngày sinh của bé để hiển thị biểu đồ.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final end = DateTime(
      birth.year + 5,
      birth.month,
      birth.day.clamp(1, DateUtils.getDaysInMonth(birth.year + 5, birth.month)),
    );
    final validRows = widget.rows
        .where(
          (r) =>
              r.value.isFinite &&
              r.value > 0 &&
              !r.measuredAt.isBefore(birth) &&
              !r.measuredAt.isAfter(end),
        )
        .toList();
    validRows.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (validRows.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: Center(child: Text('Chưa có số đo trong độ tuổi này.')),
      );
    }
    final rows = validRows.length > _maxVisiblePoints
        ? validRows.sublist(validRows.length - _maxVisiblePoints)
        : validRows;
    final selected = rows.contains(_selected) ? _selected! : rows.last;
    final painter = _MeasurementPainter(
      rows,
      birth,
      end,
      widget.metric,
      widget.zoom,
      selected,
    );
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'LẦN ĐO ĐANG XEM',
                style: TextStyle(
                  color: Color(0xFF21847E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${formatGrowthValue(selected.value)} ${widget.metric.unit} · ${selected.measuredAt.day}/${selected.measuredAt.month}/${selected.measuredAt.year}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF233E47),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (validRows.length > rows.length)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Đang hiển thị 60 số đo gần nhất để biểu đồ dễ đọc.',
                style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
            ),
          ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            width: c.maxWidth,
            height: c.maxWidth + 8,
            child: MouseRegion(
              onHover: (event) {
                final nearest = _nearestRow(
                  rows,
                  painter,
                  Size(c.maxWidth, c.maxWidth + 8),
                  event.localPosition,
                );
                if (nearest != null && nearest != _selected) {
                  setState(() {
                    _selected = nearest;
                  });
                }
              },
              child: GestureDetector(
                onTapDown: (event) {
                  final size = Size(c.maxWidth, c.maxWidth + 8);
                  final nearest = _nearestRow(
                    rows,
                    painter,
                    size,
                    event.localPosition,
                  );
                  if (nearest != null) setState(() => _selected = nearest);
                },
                child: Semantics(
                  label:
                      '${widget.metric.title}. ${validRows.length} lần đo${validRows.length > rows.length ? ', đang hiển thị ${rows.length} lần gần nhất' : ''}. Chạm để chọn số đo.',
                  child: CustomPaint(painter: painter),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  GrowthMeasurementDraft? _nearestRow(
    List<GrowthMeasurementDraft> rows,
    _MeasurementPainter painter,
    Size size,
    Offset position,
  ) {
    GrowthMeasurementDraft? nearest;
    var distance = 24.0;
    for (final row in rows) {
      final candidate = (painter.point(row, size) - position).distance;
      if (candidate <= distance) {
        distance = candidate;
        nearest = row;
      }
    }
    return nearest;
  }
}

class _MeasurementPainter extends CustomPainter {
  _MeasurementPainter(
    this.rows,
    this.birth,
    this.end,
    this.metric,
    this.zoom,
    this.selected,
  );
  final List<GrowthMeasurementDraft> rows;
  final DateTime birth, end;
  final GrowthMetric metric;
  final bool zoom;
  final GrowthMeasurementDraft selected;
  static const color = Color(0xFF168B87);
  double get low => math.max(
    0,
    rows.map((r) => r.value).reduce(math.min).floorToDouble() - 1,
  );
  double get high => math.max(
    low + 2,
    rows.map((r) => r.value).reduce(math.max).ceilToDouble() + 1,
  );
  DateTime get start => rows.first.measuredAt;
  DateTime get stop {
    final zoomEnd = rows.last.measuredAt.add(const Duration(days: 30));
    return zoom && zoomEnd.isBefore(end) ? zoomEnd : end;
  }

  Rect plot(Size size) {
    const rightMargin = 62.0;
    return Rect.fromLTWH(46, 18, size.width - rightMargin, size.width - 62);
  }

  Offset point(GrowthMeasurementDraft row, Size size) {
    final r = plot(size);
    final span = math.max(1, stop.difference(start).inDays);
    final day = DateUtils.dateOnly(row.measuredAt);
    final sameDayRows = rows
        .where((item) => DateUtils.isSameDay(item.measuredAt, day))
        .toList();
    final sameDayIndex = sameDayRows.indexOf(row);
    final dayOffset = sameDayRows.length <= 1
        ? 0.0
        : (sameDayIndex - (sameDayRows.length - 1) / 2) *
              math.min(8.0, r.width / (sameDayRows.length * 2));
    return Offset(
      r.left +
          row.measuredAt.difference(start).inDays / span * r.width +
          dayOffset,
      r.bottom - (row.value - low) / (high - low) * r.height,
    );
  }

  void label(
    Canvas canvas,
    String value,
    Offset at, {
    bool center = false,
    bool right = false,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          fontFamily: 'Nunito',
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(
        center
            ? at.dx - text.width / 2
            : right
            ? at.dx - text.width
            : at.dx,
        at.dy,
      ),
    );
  }

  String naturalLabel(double value) => value.round().toString();

  @override
  void paint(Canvas canvas, Size size) {
    final r = plot(size);
    final grid = Paint()
      ..color = const Color(0xFFD8E1DD)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = r.bottom - r.height * i / 4;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
      label(canvas, naturalLabel(low + (high - low) * i / 4), Offset(8, y - 7));
    }
    final firstAge = growthChartAgeMonths(birth, start) ?? 0;
    final lastAge = growthChartAgeMonths(birth, stop) ?? 60;
    final spanMonths = lastAge - firstAge;
    final step = spanMonths <= 6
        ? 1
        : spanMonths <= 12
        ? 3
        : spanMonths <= 24
        ? 6
        : 12;
    double xFor(DateTime day) =>
        r.left +
        day.difference(start).inDays /
            math.max(1, stop.difference(start).inDays) *
            r.width;
    final ticks = <DateTime>[start];
    for (
      var month = (firstAge / step).floor() * step + step;
      month < lastAge;
      month += step
    ) {
      final anchor = DateTime(birth.year, birth.month + month);
      final day = DateTime(
        anchor.year,
        anchor.month,
        birth.day.clamp(1, DateUtils.getDaysInMonth(anchor.year, anchor.month)),
      );
      if (xFor(day) - xFor(ticks.last) > 42 && r.right - xFor(day) > 42) {
        ticks.add(day);
      }
    }
    if (stop.isAfter(start)) {
      ticks.add(stop);
    }
    for (final date in ticks) {
      final months = (growthChartAgeMonths(birth, date) ?? 60).floor();
      label(canvas, '$months', Offset(xFor(date), r.bottom + 10), center: true);
    }
    label(canvas, metric.unit, Offset(r.left, 0));
    label(canvas, 'Tháng', Offset(r.center.dx, r.bottom + 28), center: true);
    final axis = Paint()
      ..color = const Color(0xFF526B68)
      ..strokeWidth = 1.5;
    canvas.drawLine(r.topLeft, r.bottomLeft, axis);
    canvas.drawLine(r.bottomLeft, r.bottomRight, axis);
    final path = Path();
    GrowthMeasurementDraft? previous;
    for (final row in rows) {
      final p = point(row, size);
      if (previous == null ||
          DateUtils.isSameDay(row.measuredAt, previous.measuredAt)) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      previous = row;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (final row in rows) {
      final p = point(row, size);
      if (identical(row, selected)) {
        canvas.drawCircle(p, 9, Paint()..color = color.withValues(alpha: .15));
      }
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurementPainter old) => true;
}
