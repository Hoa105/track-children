import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_weight_history.dart';
import 'growth_stature_velocity.dart';
import 'growth_visuals.dart';
import 'growth_status_badge.dart';
import 'growth_weight_chart_legend.dart';
import 'growth_weight_detail.dart'
    show
        GrowthWeightMeasurementChart,
        GrowthAgeChartHeading,
        growthWeightAgeInRange,
        growthWeightAgeStart,
        growthRelativeMeasurementInterval;
import 'growth_weight_input.dart';
import 'growth_chart_explanation_dialog.dart';
import 'growth_conclusion_explanation.dart';
import 'stature_overview.dart';
import 'head_overview.dart';
import 'bmi_overview.dart';

String growthStatureName(double? age) => age == null
    ? 'Chiều dài/chiều cao'
    : age < 24
    ? 'Chiều dài'
    : 'Chiều cao';

class GrowthStatureDetailScreen extends StatefulWidget {
  const GrowthStatureDetailScreen({
    required this.repository,
    this.easyReadMode = false,
    this.metric = GrowthMetric.lengthHeight,
    this.bmiMode = false,
    super.key,
  });
  final GrowthRepository repository;
  final bool easyReadMode;
  final GrowthMetric metric;
  final bool bmiMode;
  @override
  State<GrowthStatureDetailScreen> createState() =>
      _GrowthStatureDetailScreenState();
}

class _GrowthStatureDetailScreenState extends State<GrowthStatureDetailScreen> {
  bool get _head => widget.metric == GrowthMetric.headCircumference;
  bool get _bmi => widget.bmiMode;
  Color get _tabColor => growthGreen;
  String get _unit => _bmi ? 'kg/m²' : 'cm';
  Color get _series => _bmi
      ? growthGreen
      : _head
      ? const Color(0xFF9468B5)
      : growthStatureBlue;
  Color get _ink => _bmi
      ? _series
      : _head
      ? const Color(0xFF76518F)
      : const Color(0xFF316884);
  Color get _surface => _bmi
      ? const Color(0xFFEAF5E9)
      : _head
      ? const Color(0xFFF2ECF8)
      : const Color(0xFFEAF3FA);
  Color get _region => _bmi
      ? const Color(0xFFB2D6A9)
      : _head
      ? const Color(0xFFD9C4E9)
      : const Color(0xFFB7D8EC);
  Color get _median => _bmi
      ? const Color(0xFF79C99B)
      : _head
      ? const Color(0xFFB397CE)
      : const Color(0xFF8ABDDD);
  late Future<
    ({
      List<GrowthMeasurementDraft> points,
      GrowthWeightReference? reference,
      bool failed,
    })
  >
  _data = _load();
  GrowthMeasurementDraft? _selected;
  int? _range;
  String _tab = 'Tổng quan';
  bool get _velocity => _tab == 'Tốc độ';
  GrowthWeightReference? _lengthReference, _heightReference;
  Future<
    ({
      List<GrowthMeasurementDraft> points,
      GrowthWeightReference? reference,
      bool failed,
    })
  >
  _load() async {
    final points = [
      ...await (_bmi
          ? widget.repository.bmiMeasurements()
          : widget.repository.measurements(widget.metric)),
    ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final age = points.isEmpty || widget.repository.dateOfBirth == null
        ? null
        : growthChartAgeMonths(
            widget.repository.dateOfBirth!,
            points.last.measuredAt,
          );
    try {
      if (_bmi) {
        _lengthReference = await widget.repository.bmiAgeReference(true);
        _heightReference = await widget.repository.bmiAgeReference(false);
        return (points: points, reference: age == null || age < 24 ? _lengthReference : _heightReference, failed: false);
      }
      if (!_head && !_bmi) {
        _lengthReference = await widget.repository.statureAgeReference(true);
        _heightReference = await widget.repository.statureAgeReference(false);
        return (
          points: points,
          reference: age == null || age < 24
              ? _lengthReference
              : _heightReference,
          failed: false,
        );
      }
      final reference = age == null
          ? null
          : _bmi
          ? await widget.repository.bmiAgeReference(age < 24)
          : _head
          ? await widget.repository.headAgeReference()
          : await widget.repository.statureAgeReference(age < 24);
      return (points: points, reference: reference, failed: false);
    } catch (_) {
      return (points: points, reference: null, failed: true);
    }
  }

  Future<void> _update() async {
    var metric = widget.metric;
    if (_bmi) {
      final chosen = await showModalBottomSheet<GrowthMetric>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Cập nhật số đo để tính BMI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const GrowthAsset('overview-weight', size: 28),
              title: const Text('Cập nhật cân nặng'),
              onTap: () => Navigator.pop(context, GrowthMetric.weight),
            ),
            ListTile(
              leading: const GrowthAsset('overview-height', size: 28),
              title: const Text('Cập nhật chiều dài/chiều cao'),
              onTap: () => Navigator.pop(context, GrowthMetric.lengthHeight),
            ),
          ],
        ),
      );
      if (chosen == null || !mounted) return;
      metric = chosen;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(name: '/growth/${metric.routeKey}-input'),
        builder: (_) => GrowthWeightInputScreen(
          repository: widget.repository,
          metric: metric,
          easyReadMode: widget.easyReadMode,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _selected = null;
        _data = _load();
      });
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  // Explicit display fixtures only, kept separate from WHO chart references.
  double? _sampleZ(GrowthMeasurementDraft p) {
    if (widget.repository is! MockGrowthRepository) {
      return widget.repository.indicatorZScore(
        _bmi
            ? 'bmi'
            : _head
            ? 'head_circumference'
            : 'height',
        p.measuredAt,
        _bmi
            ? 'bmifa'
            : _head
            ? 'hcfa'
            : 'lhfa',
      );
    }
    if (_bmi) {
      if (widget.repository is! MockGrowthRepository ||
          (widget.repository as MockGrowthRepository).referenceSex !=
              GrowthReferenceSex.boys ||
          p.method != GrowthMeasurementMethod.recumbent) {
        return null;
      }
      final values = {
        DateTime(2025, 1, 15): (7.7 / (.70 * .70), -.50),
        DateTime(2025, 2, 15): (8 / (.72 * .72), -.60),
        DateTime(2025, 3, 15): (8.2 / (.735 * .735), -.70),
        DateTime(2025, 4, 15): (8.5 / (.75 * .75), -.80),
        DateTime(2025, 5, 15): (8.8 / (.765 * .765), -.80),
      };
      final fixture = values[DateUtils.dateOnly(p.measuredAt)];
      return fixture != null && (p.value - fixture.$1).abs() < .000001
          ? fixture.$2
          : null;
    }
    if (widget.repository is! MockGrowthRepository ||
        (!_head && p.method != GrowthMeasurementMethod.recumbent)) {
      return null;
    }
    if ((widget.repository as MockGrowthRepository).referenceSex !=
        GrowthReferenceSex.boys) {
      return null;
    }
    final values = _head
        ? {
            DateTime(2025, 1, 15): (43.5, .10),
            DateTime(2025, 2, 15): (44.0, .20),
            DateTime(2025, 3, 15): (44.2, .15),
            DateTime(2025, 4, 15): (45.0, .30),
            DateTime(2025, 5, 15): (45.5, .40),
          }
        : {
            DateTime(2025, 1, 15): (70.0, .20),
            DateTime(2025, 2, 15): (72.0, .30),
            DateTime(2025, 3, 15): (73.5, .40),
            DateTime(2025, 4, 15): (75.0, .50),
            DateTime(2025, 5, 15): (76.5, .60),
          };
    final sample = values[DateUtils.dateOnly(p.measuredAt)];
    return sample != null && p.value == sample.$1 ? sample.$2 : null;
  }

  @override
  Widget build(BuildContext context) {
    final easy = widget.easyReadMode;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Nunito',
          bodyColor: growthInk,
          displayColor: growthInk,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: _series),
      ),
      child: FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final points = data?.points ?? const <GrowthMeasurementDraft>[];
          final latest = points.lastOrNull;
          final birth = widget.repository.dateOfBirth;
          final age = latest == null || birth == null
              ? null
              : growthChartAgeMonths(birth, latest.measuredAt);
          final displayAge =
              age ??
              (latest == null || birth == null
                  ? null
                  : ((latest.measuredAt.year - birth.year) * 12 +
                            latest.measuredAt.month -
                            birth.month -
                            (latest.measuredAt.day < birth.day ? 1 : 0))
                        .toDouble());
          final name = _bmi
                  ? 'BMI'
                  : _head
                  ? 'Vòng đầu'
                  : growthStatureName(displayAge),
              lower = name.toLowerCase();
          final length = displayAge == null || displayAge < 24;
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 30
                  ? 120
                  : 56,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              foregroundColor: growthInk,
              leading: IconButton(
                tooltip: 'Về tổng quan tăng trưởng',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.chevron_left),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GrowthAsset(
                    _bmi
                        ? 'overview-bmi'
                        : _head
                        ? 'overview-head'
                        : 'overview-height',
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (!_bmi)
                  IconButton(
                    tooltip: 'Cập nhật $lower',
                    onPressed: _update,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final tab in [
                        'Tổng quan',
                        if (!_bmi) 'Tốc độ',
                        'Lịch sử',
                      ])
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: tab == _tab
                                      ? _tabColor
                                      : const Color(0xFFEEF0EC),
                                  width: tab == _tab ? 2 : 1,
                                ),
                              ),
                            ),
                            child: TextButton(
                              onPressed: () => setState(() => _tab = tab),
                              child: Text(
                                tab,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: tab == _tab ? _tabColor : growthMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: snapshot.connectionState != ConnectionState.done
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Chưa tải được số đo.'),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _data = _load()),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        : _tab == 'Lịch sử'
                        ? GrowthWeightHistoryTab(
                            readings: points,
                            repository: widget.repository,
                            metric: widget.metric,
                            bmiMode: _bmi,
                            easyRead: easy,
                            zScoreForPoint: _sampleZ,
                          )
                        : latest == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const GrowthAsset('no-measurements', size: 90),
                                const SizedBox(height: 16),
                                Text(
                                  _bmi
                                      ? 'Chưa đủ số đo cùng ngày để tính BMI'
                                      : 'Chưa có số đo $lower',
                                ),
                                TextButton(
                                  onPressed: _update,
                                  child: Text(
                                    _bmi ? 'Cập nhật số đo' : 'Cập nhật $lower',
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _velocity && !_bmi
                        ? GrowthStatureVelocityTab(
                            headCircumference: _head,
                            repository: widget.repository,
                            readings: points,
                            name: name,
                            easyRead: easy,
                          )
                        : _content(
                            context,
                            points,
                            data!.reference,
                            data.failed,
                            name,
                            lower,
                            length,
                            age,
                            birth,
                            easy,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<GrowthMeasurementDraft> points,
    GrowthWeightReference? reference,
    bool failed,
    String name,
    String lower,
    bool length,
    double? age,
    DateTime? birth,
    bool easy,
  ) {
    if (_bmi) {
      return BmiOverview(points: points, repository: widget.repository,
        lengthReference: _lengthReference, heightReference: _heightReference,
        scoreFor: _sampleZ, onUpdate: _update,
        onRetry: () => setState(() => _data = _load()), failed: failed, easyRead: easy);
    }
    if (_head) {
      return HeadOverview(
        points: points,
        repository: widget.repository,
        reference: reference,
        scoreFor: _sampleZ,
        onUpdate: _update,
        onRetry: () => setState(() => _data = _load()),
        failed: failed,
        easyRead: easy,
      );
    }
    if (!_head && !_bmi) {
      return StatureOverview(
        points: points,
        repository: widget.repository,
        lengthReference: _lengthReference,
        heightReference: _heightReference,
        scoreFor: _sampleZ,
        onUpdate: _update,
        easyRead: easy,
        failed: failed,
        onRetry: () => setState(() => _data = _load()),
      );
    }
    final latest = points.last;
    final previous = points.length < 2 ? null : points[points.length - 2];
    final comparable =
        previous != null &&
        (_head || (previous.method == latest.method && latest.method != null));
    final change = comparable ? latest.value - previous.value : null;
    final range = _range ?? 0;
    final min = math.max(_head || length ? 0 : 24, growthWeightAgeStart(range));
    final max = math.min(
      _head
          ? 60
          : length
          ? 24
          : 60,
      range == 0 ? 60 : range,
    );
    final visible = points.where((p) {
      final a = birth == null
          ? null
          : growthChartAgeMonths(birth, p.measuredAt);
      return a != null &&
          a >= min &&
          a <= max &&
          growthWeightAgeInRange(a, range) &&
          (_head ||
              p.method ==
                  (length
                      ? GrowthMeasurementMethod.recumbent
                      : GrowthMeasurementMethod.standing));
    }).toList();
    final score = age == null ? null : _sampleZ(latest);
    final noteColor = _head ? const Color(0xFF9B7AC2) : _series;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name hiện tại',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${formatGrowthValue(latest.value)} $_unit',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172A4B),
                            ),
                          ),
                        ),
                        if (!_bmi)
                          IconButton(
                            tooltip: 'C\u1eadp nh\u1eadt $lower',
                            onPressed: _update,
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Color(0xFF62738D),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Ngày đo: ${_date(latest.measuredAt)}',
                      style: TextStyle(fontSize: 13, color: growthMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: easy ? 172 : 132,
                    child: GrowthStatusBadge(
                      label: score == null
                          ? 'Ch\u01b0a \u0111\u1ee7 d\u1eef li\u1ec7u'
                          : 'Ph\u00f9 h\u1ee3p',
                      icon: Icons.check_rounded,
                      foreground: _ink,
                      background: _surface,
                      angle: easy ? 0 : -.045,
                      easyRead: easy,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 8),
              Flexible(
                child: _paper(easy, -.12, [
                  Text(
                    change == null
                        ? (previous == null
                              ? 'Ch\u01b0a \u0111\u1ee7 s\u1ed1 \u0111o \u0111\u1ec3 so s\u00e1nh'
                              : 'Kh\u00e1c c\u00e1ch \u0111o, ch\u01b0a so s\u00e1nh m\u1ee9c thay \u0111\u1ed5i')
                        : '${change >= 0 ? 'T\u0103ng' : 'Gi\u1ea3m'} ${formatGrowthValue(change.abs())} $_unit',
                    style: TextStyle(
                      fontFamily: easy ? 'Nunito' : 'DancingScript',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: noteColor,
                    ),
                  ),
                  if (comparable)
                    Text(
                      growthRelativeMeasurementInterval(
                        previous.measuredAt,
                        latest.measuredAt,
                      ),
                      style: TextStyle(
                        fontFamily: easy ? 'Nunito' : 'DancingScript',
                        fontSize: 16,
                        color: const Color(0xFF20365D),
                      ),
                    ),
                ]),
              ),
              if (!easy)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: GrowthAsset('weight-note-arrow', size: 64),
                ),
            ],
          ),
          SizedBox(height: easy ? 8 : 0),
          Transform.translate(
            offset: easy ? const Offset(0, -30) : const Offset(-8, -26),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _paper(easy, -.12, [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GrowthAsset('overview-chart', size: 28),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            score == null
                                ? 'Ch\u01b0a \u0111\u1ee7 d\u1eef li\u1ec7u \u0111\u00e1nh gi\u00e1 $lower theo tu\u1ed5i'
                                : '$name c\u1ee7a b\u00e9 hi\u1ec7n ph\u00f9 h\u1ee3p v\u1edbi tu\u1ed5i',
                            style: TextStyle(
                              fontFamily: easy ? 'Nunito' : 'DancingScript',
                              fontSize: 18,
                              height: 1.25,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GrowthAgeChartHeading(
            title: '$name theo \u0111\u1ed9 tu\u1ed5i',
            months: range,
            easyRead: easy,
            onChanged: (value) => setState(() {
              _range = value;
              _selected = null;
            }),
            onExplain: () => showDialog<void>(
              context: context,
              builder: (_) => GrowthChartExplanationDialog(
                title: Text('$name theo \u0111\u1ed9 tu\u1ed5i'),
                content: Text(
                  _bmi
                      ? 'BMI = cân nặng (kg) / chiều dài hoặc chiều cao (m)², sử dụng hai số đo cùng ngày.\n\nTrục ngang là tuổi (tháng), trục dọc là BMI (kg/m²). Đối chiếu WHO theo tuổi, giới tính và cách đo: dưới 24 tháng dùng chiều dài nằm, từ 24 tháng dùng chiều cao đứng. Không áp dụng ngưỡng BMI của người lớn.\n\nRê chuột hoặc chạm điểm đo để xem BMI và Z-score.'
                      : _head
                      ? 'Tr\u1ee5c ngang l\u00e0 tu\u1ed5i t\u1ea1i ng\u00e0y \u0111o (th\u00e1ng), tr\u1ee5c d\u1ecdc l\u00e0 v\u00f2ng \u0111\u1ea7u (cm).\n\nC\u00e1c \u0111\u01b0\u1eddng WHO v\u00f2ng \u0111\u1ea7u theo tu\u1ed5i d\u00e0nh cho \u0111\u00fang gi\u1edbi t\u00ednh, t\u1eeb 0 \u0111\u1ebfn 60 th\u00e1ng. Kh\u00f4ng s\u1eed d\u1ee5ng chu\u1ea9n chi\u1ec1u d\u00e0i hay c\u00e2n n\u1eb7ng \u0111\u1ec3 \u0111\u00e1nh gi\u00e1 v\u00f2ng \u0111\u1ea7u.\n\nR\u00ea chu\u1ed9t ho\u1eb7c ch\u1ea1m \u0111i\u1ec3m \u0111o \u0111\u1ec3 xem chi ti\u1ebft.'
                      : 'Tr\u1ee5c ngang l\u00e0 tu\u1ed5i t\u1ea1i ng\u00e0y \u0111o (th\u00e1ng), tr\u1ee5c d\u1ecdc l\u00e0 $lower (cm).\n\nC\u00e1c \u0111\u01b0\u1eddng WHO theo \u0111\u00fang gi\u1edbi t\u00ednh v\u00e0 c\u00e1ch \u0111o. D\u01b0\u1edbi 24 th\u00e1ng d\u00f9ng chi\u1ec1u d\u00e0i n\u1eb1m; t\u1eeb 24 th\u00e1ng d\u00f9ng chi\u1ec1u cao \u0111\u1ee9ng.\n\nTr\u1ee5c cm t\u1ef1 \u0111i\u1ec1u ch\u1ec9nh theo s\u1ed1 \u0111o v\u00e0 tham chi\u1ebfu trong kho\u1ea3ng tu\u1ed5i \u0111ang xem.',
                ),
                actions: const [],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (max <= min)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Khoảng tuổi này không áp dụng cho cách đo đang xem.',
              ),
            )
          else
            GrowthWeightMeasurementChart(
              points: visible,
              dateOfBirth: birth,
              minAgeMonths: min,
              maxAgeMonths: max,
              reference: reference,
              unit: _unit,
              fitValueAxis: _bmi,
              axisTitle: '$name ($_unit)',
              medianColor: _median,
              seriesColor: _series,
              bandColor: (_bmi
                  ? const Color(0x482DB878)
                  : _head
                  ? const Color(0x489B7AC2)
                  : const Color(0x484B92C6)),
              easyReadMode: easy,
              selectedPoint: _selected,
              zScoreForPoint: _sampleZ,
              onSelect: (p) => setState(() => _selected = p),
              onHover: (p) {
                if (_selected != p) setState(() => _selected = p);
              },
            ),
          const SizedBox(height: 12),
          if (reference != null)
            GrowthWeightReferenceLegend(
              seriesColor: _series,
              regionColor: _region,
              medianColor: _median,
            )
          else
            Center(child: GrowthWeightChartLegend(seriesColor: _series)),
          if (failed)
            TextButton(
              onPressed: () => setState(() => _data = _load()),
              child: const Text('Chưa tải được tham chiếu WHO. Thử lại'),
            ),
          if (reference == null && !failed)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Chưa có tham chiếu WHO phù hợp.',
                style: TextStyle(color: growthMuted),
              ),
            ),
          const SizedBox(height: 24),
          _paper(easy, -.025, [
            Text(
              'Vùng màu giúp ba mẹ đối chiếu $lower của bé với chuẩn WHO theo tuổi và giới tính. Cần theo dõi nhiều lần đo để hiểu hành trình phát triển của con.',
              style: TextStyle(
                fontFamily: easy ? 'Nunito' : 'DancingScript',
                fontSize: 18,
                height: 1.4,
                color: const Color(0xFF20365D),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GrowthAsset(
                      !_head && !_bmi ? 'result-smile-stature' : 'result-smile',
                      size: 48,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$name của bé thế nào?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  score == null
                      ? 'Chưa đủ dữ liệu đánh giá'
                      : 'Phù hợp với tuổi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20365D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  score == null
                      ? 'Cần tuổi, giới tính, cách đo và kết quả đối chiếu phù hợp cho lần đo này.'
                      : '$name của bé nằm trong khoảng phù hợp với trẻ cùng tuổi và giới tính.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4C6585),
                  ),
                ),
                const SizedBox(height: 6),
                if (score != null)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Text(
                      'Theo tuổi · ${score >= 0 ? '+' : ''}${score.toStringAsFixed(2).replaceAll('.', ',')} SD',
                      style: TextStyle(fontSize: 13, color: growthMuted),
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Nhận xét',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  score == null
                      ? 'Chưa đủ dữ liệu nhận xét. Ba mẹ hãy kiểm tra cách đo và cập nhật số đo tiếp theo.'
                      : _bmi
                      ? 'Ba mẹ hãy tiếp tục cập nhật cân nặng và chiều dài/chiều cao cùng ngày để theo dõi BMI theo tuổi nhé!'
                      : 'Ba mẹ hãy tiếp tục đo $lower đúng cách và theo dõi các lần đo tiếp theo nhé!',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4C6585),
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: const Color(0xFFFFFEFA),
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    leading: const GrowthAsset('lightbulb', size: 26),
                    title: const Text(
                      'Vì sao có kết luận này?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => GrowthConclusionExplanationScreen(
                          easyRead: easy,
                          introText:
                              'Cùng nhìn lại số đo $lower của con và căn cứ đối chiếu theo tuổi, giới tính nhé!',
                          sources: {
                            'WHO $name theo tuổi':
                                reference?.sourceUrl ??
                                'https://www.who.int/tools/child-growth-standards/standards/${_bmi
                                    ? 'body-mass-index-for-age-bmi-for-age'
                                    : _head
                                    ? 'head-circumference-for-age'
                                    : 'length-height-for-age'}',
                          },
                          sections: [
                            GrowthExplanationSection(
                              '1. Dữ liệu sử dụng',
                              '${_date(latest.measuredAt)}: ${formatGrowthValue(latest.value)} $_unit. ${age == null ? 'Chưa xác định tuổi hợp lệ.' : 'Tuổi tại ngày đo: ${formatGrowthValue(age)} tháng.'} ${_head ? 'V\u00f2ng \u0111\u1ea7u \u0111o b\u1eb1ng th\u01b0\u1edbc d\u00e2y, kh\u00f4ng \u00e1p d\u1ee5ng ph\u00e2n lo\u1ea1i \u0111o n\u1eb1m/\u0111\u1ee9ng.' : 'C\u00e1ch \u0111o: ${latest.method == null
                                        ? 'ch\u01b0a c\u00f3'
                                        : latest.method == GrowthMeasurementMethod.recumbent
                                        ? '\u0111o n\u1eb1m'
                                        : '\u0111o \u0111\u1ee9ng'}.'}',
                            ),
                            GrowthExplanationSection(
                              '2. Chuẩn đối chiếu',
                              reference == null
                                  ? 'Chưa có tham chiếu phù hợp.'
                                  : 'WHO Child Growth Standards, $lower theo tuổi, ${reference.sexLabel}. ${_head ? 'Đối chiếu theo tuổi tại ngày đo và giới tính.' : 'Dữ liệu được chọn riêng theo cách đo.'}',
                            ),
                            if (_bmi)
                              const GrowthExplanationSection(
                                'Cách xác định BMI',
                                'BMI = cân nặng (kg) / chiều dài hoặc chiều cao (m)². Chỉ ghép hai số đo cùng ngày. BMI theo tuổi của trẻ cần đối chiếu theo giới tính và cách đo, không dùng ngưỡng BMI của người lớn.',
                              ),
                            GrowthExplanationSection(
                              '3. Kết quả tính toán',
                              _bmi
                                  ? score == null
                                        ? 'Chưa có Z-score theo tuổi phù hợp cho lần đo này. Chưa đủ dữ liệu đánh giá.'
                                        : 'Z-score theo tuổi: ${score >= 0 ? '+' : ''}${score.toStringAsFixed(2).replaceAll('.', ',')} SD. Giá trị này được đối chiếu theo tuổi, giới tính và cách đo của lần đo đang xem.'
                                  : 'Chưa có kết quả tính toán Z-score xác thực. Giá trị minh họa trong giao diện không thay thế kết quả đánh giá WHO.',
                            ),
                            const GrowthExplanationSection(
                              '4. Giải thích kết luận',
                              'Đánh giá cần kết quả tính toán theo tuổi, giới tính và cách đo. Không tự suy ra kết luận từ màu vùng hoặc mức thay đổi giữa hai lần đo.',
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

  Widget _paper(bool easy, double angle, List<Widget> children) =>
      Transform.rotate(
        angle: easy ? 0 : angle,
        child: CustomPaint(
          painter: const GrowthNotePaperPainter(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      );
}
