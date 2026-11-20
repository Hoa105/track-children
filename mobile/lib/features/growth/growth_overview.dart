import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
export 'growth_repository.dart';
import 'growth_tracking_flow.dart';
import 'growth_assessment_card.dart';
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
  late Map<String, Future<Map<String, dynamic>>> _assessments;
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
    _assessments = {
      for (final kind in ['bmi', 'head'])
        kind: _repository.parentAssessment(kind)..ignore(),
    };
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

  Widget _assessment() => _assessmentCard('bmi');
  Widget _headAssessment() => _assessmentCard('head');

  Widget _assessmentCard(String kind) => GrowthAssessmentCard(
    kind: kind,
    assessment: _assessments[kind]!,
    onTap: () =>
        _open(TrackingAssessmentScreen(repository: _repository, kind: kind)),
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
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
