import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
export 'growth_repository.dart';
import 'growth_tracking_flow.dart';
import 'growth_assessment_card.dart';
import 'growth_measurement_chart.dart';
import '../navigation/app_bottom_navigation_bar.dart';

class GrowthOverview extends StatefulWidget {
  const GrowthOverview({
    super.key,
    this.repository,
    this.onNavigation,
    this.openEditorOnStart = false,
    this.initialMetric = 0,
  });
  final GrowthRepository? repository;
  final ValueChanged<String>? onNavigation;
  final bool openEditorOnStart;
  final int initialMetric;
  @override
  State<GrowthOverview> createState() => _GrowthOverviewState();
}

class _GrowthOverviewState extends State<GrowthOverview> {
  late final GrowthRepository _repository =
      widget.repository ?? MockGrowthRepository();
  late Future<List<List<GrowthMeasurementDraft>>> _data;
  late Map<String, Future<Map<String, dynamic>>> _assessments;
  late GrowthMetric _selectedMetric =
      GrowthMetric.values[widget.initialMetric.clamp(
        0,
        GrowthMetric.values.length - 1,
      )];
  bool _chartPinching = false;
  bool _didOpenEditor = false;
  static const _ink = GrowthColors.textPrimary;
  static const _paper = GrowthColors.background;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool force = false}) {
    _assessments = {
      for (final kind in ['bmi', 'head'])
        kind: _repository.parentAssessment(kind, force: force)..ignore(),
    };
    _data = () async {
      await _repository.refreshMeasurements(force: force);
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
    if (mounted) setState(() => _reload());
  }

  Future<void> _add([GrowthMetric? metric]) async {
    if (!_repository.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có quyền xem số đo.')),
      );
      return;
    }
    if (await openTrackingEditor(context, _repository, metric: metric) &&
        mounted) {
      setState(() => _reload(force: true));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu số đo')));
    }
  }

  String _date(DateTime day) => trackingDate(day);
  List<GrowthMeasurementDraft> _sorted(List<GrowthMeasurementDraft> rows) =>
      [...rows]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  String? _genderLabel() => switch (_repository.childGender
      ?.trim()
      .toLowerCase()) {
    'male' || 'm' || 'boy' || 'bé trai' || 'nam' => 'Bé trai',
    'female' || 'f' || 'girl' || 'bé gái' || 'nữ' => 'Bé gái',
    _ => null,
  };

  IconData _genderIcon(String? genderLabel) => switch (genderLabel) {
    'Bé trai' => Icons.male_rounded,
    'Bé gái' => Icons.female_rounded,
    _ => Icons.child_care_rounded,
  };

  Widget _infoPill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: GrowthColors.primarySoft,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: GrowthColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: GrowthColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

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
    final gender = _genderLabel();
    final rawName = (_repository.childLabel ?? 'của bạn').trim();
    final displayName =
        rawName.toLowerCase().startsWith('bé ') ? rawName : 'Bé $rawName';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GrowthColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GrowthColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: GrowthColors.iconBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.child_care_rounded,
              color: GrowthColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GrowthColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (gender != null || age != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (gender != null)
                        _infoPill(_genderIcon(gender), gender),
                      if (age != null)
                        _infoPill(Icons.cake_outlined, age),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(GrowthMetric metric, List<GrowthMeasurementDraft> rows) {
    final latest = rows.lastOrNull;
    final selected = _selectedMetric == metric;
    final icon = switch (metric) {
      GrowthMetric.weight => Icons.monitor_weight_outlined,
      GrowthMetric.lengthHeight => Icons.height,
      GrowthMetric.headCircumference => Icons.face_retouching_natural_outlined,
    };
    final title = metric == GrowthMetric.lengthHeight
        ? latest?.method == GrowthMeasurementMethod.recumbent
              ? 'Chiều dài'
              : latest?.method == GrowthMeasurementMethod.standing
              ? 'Chiều cao'
              : 'Dài/cao'
        : metric.title;
    return Material(
      color: selected ? GrowthColors.accent : GrowthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: selected ? GrowthColors.primary : GrowthColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashColor: GrowthColors.primarySoft,
        highlightColor: GrowthColors.primarySoft,
        onTap: () {
          if (_selectedMetric != metric) {
            setState(() => _selectedMetric = metric);
          } else {
            _open(
              TrackingHistoryScreen(repository: _repository, metric: metric),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? GrowthColors.surface
                          : GrowthColors.iconBackground,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: selected
                          ? GrowthColors.primaryDark
                          : GrowthColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.query_stats_rounded
                        : Icons.touch_app_outlined,
                    size: 17,
                    color: selected
                        ? GrowthColors.primaryDark
                        : GrowthColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: GrowthColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              if (latest == null)
                const Text(
                  'Chưa có',
                  style: TextStyle(
                    color: GrowthColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
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
                            color: GrowthColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: ' ${metric.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? GrowthColors.primaryDark
                                : GrowthColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                latest == null ? 'Chưa có số đo' : _date(latest.measuredAt),
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? GrowthColors.primaryDark
                      : GrowthColors.textSecondary,
                  fontWeight: FontWeight.w600,
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

  Widget _interactiveChartHub(List<List<GrowthMeasurementDraft>> allRows) {
    final metric = _selectedMetric;
    final metricRows = allRows[metric.index];
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
      decoration: BoxDecoration(
        color: GrowthColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: GrowthColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: GrowthColors.iconBackground,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        trackingMetricIcon(metric),
                        size: 18,
                        color: GrowthColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biểu đồ ${metric.title.toLowerCase()}',
                          style: const TextStyle(
                            color: GrowthColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${metricRows.length} lần ghi nhận',
                          style: const TextStyle(
                            color: GrowthColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: GrowthColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _open(
                          TrackingHistoryScreen(
                            repository: _repository,
                            metric: metric,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 15,
                                color: GrowthColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Lịch sử',
                                style: TextStyle(
                                  color: GrowthColors.primaryDark,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_repository.canEdit) ...[
                      const SizedBox(width: 6),
                      Material(
                        color: GrowthColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _add(metric),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: GrowthColors.surface,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Ghi đo',
                                  style: TextStyle(
                                    color: GrowthColors.surface,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GrowthMeasurementChart(
            key: ValueKey(metric),
            rows: metricRows,
            birth: _repository.dateOfBirth,
            metric: metric,
            onPinchingChanged: (active) {
              if (mounted && _chartPinching != active) {
                setState(() => _chartPinching = active);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _assessmentsHub() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GrowthColors.primarySoft,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: GrowthColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 18,
                color: GrowthColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nhận xét theo chuẩn WHO',
                  style: TextStyle(
                    color: GrowthColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        _assessmentCard('bmi'),
        const SizedBox(height: 8),
        _assessmentCard('head'),
      ],
    ),
  );

  Widget _assessmentCard(String kind) => GrowthAssessmentCard(
    kind: kind,
    assessment: _assessments[kind]!,
    onTap: () =>
        _open(TrackingAssessmentScreen(repository: _repository, kind: kind)),
  );

  @override
  Widget build(BuildContext context) => GrowthTheme(
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: _paper,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
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
                      onPressed: () => setState(() => _reload(force: true)),
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
              color: GrowthColors.primary,
              onRefresh: () async {
                setState(() => _reload(force: true));
                await _data;
              },
              child: ListView(
                physics: _chartPinching
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _profile(),
                  _summary(rows),
                  const SizedBox(height: 14),
                  _interactiveChartHub(rows),
                  const SizedBox(height: 14),
                  _assessmentsHub(),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

