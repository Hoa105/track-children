import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/bmi_result.dart';
import '../../../models/child.dart';
import '../../../models/growth_record.dart';
import '../../../services/service_locator.dart';
import '../screens/growth_history_screen.dart';

String formatBmiDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatBmi(double bmi) => bmi.toStringAsFixed(1).replaceAll('.', ',');

extension BmiCategoryColors on BmiCategory {
  Color get color => switch (this) {
        BmiCategory.severeWasting || BmiCategory.obese => AppColors.danger,
        BmiCategory.wasting || BmiCategory.overweight => AppColors.amberDark,
        BmiCategory.normal => AppColors.primaryDark,
      };

  Color get surface => switch (this) {
        BmiCategory.severeWasting || BmiCategory.obese => AppColors.dangerSurface,
        BmiCategory.wasting || BmiCategory.overweight => AppColors.amberSurface,
        BmiCategory.normal => AppColors.surfaceGreen,
      };
}

/// BMI tab of the Growth screen: the parent picks one recorded height and one
/// recorded weight, then computes BMI. Pairs measured too far apart for the
/// child's age are rejected with a message instead of a value.
class BmiTab extends StatefulWidget {
  const BmiTab({super.key});

  @override
  State<BmiTab> createState() => _BmiTabState();
}

class _BmiTabState extends State<BmiTab> {
  List<GrowthRecord>? _heights;
  List<GrowthRecord>? _weights;
  Child? _child;
  GrowthRecord? _height;
  GrowthRecord? _weight;
  BmiResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final growth = ServiceLocator.growthService;
    final results = await Future.wait([
      growth.getRecords('c1', GrowthMetricType.height),
      growth.getRecords('c1', GrowthMetricType.weight),
    ]);
    final children = await ServiceLocator.childService.getChildren();
    if (!mounted) return;
    setState(() {
      _heights = results[0];
      _weights = results[1];
      _child = children.firstWhere((c) => c.id == 'c1');
      _height = _heights!.isEmpty ? null : _heights!.first;
      _weight = _weights!.isEmpty ? null : _weights!.first;
    });
  }

  void _calculate() {
    setState(() {
      _result = BmiResult.calculate(weight: _weight!, height: _height!, child: _child!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final heights = _heights;
    final weights = _weights;
    if (heights == null || weights == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tính chỉ số BMI', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  'Chọn lần đo chiều cao và cân nặng gần nhau để kết quả chính xác.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                _RecordDropdown(
                  label: 'Ngày đo chiều cao',
                  records: heights,
                  selected: _height,
                  unit: GrowthMetricType.height.unit,
                  onChanged: (r) => setState(() {
                    _height = r;
                    _result = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                _RecordDropdown(
                  label: 'Ngày đo cân nặng',
                  records: weights,
                  selected: _weight,
                  unit: GrowthMetricType.weight.unit,
                  onChanged: (r) => setState(() {
                    _weight = r;
                    _result = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Tính chỉ số BMI',
                  onPressed: _height != null && _weight != null ? _calculate : null,
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _BmiResultCard(result: _result!),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () => context.push(AppRoutes.growthHistory, extra: GrowthHistoryScreen.bmiTabExtra),
            child: const Text('Xem lịch sử →'),
          ),
        ],
      ),
    );
  }
}

class _RecordDropdown extends StatelessWidget {
  const _RecordDropdown({
    required this.label,
    required this.records,
    required this.selected,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final List<GrowthRecord> records;
  final GrowthRecord? selected;
  final String unit;
  final ValueChanged<GrowthRecord?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        const SizedBox(height: 6),
        DropdownButtonFormField<GrowthRecord>(
          initialValue: selected,
          isExpanded: true,
          hint: Text('Chưa có số đo', style: AppTextStyles.body),
          style: AppTextStyles.body,
          items: [
            for (final r in records)
              DropdownMenuItem(
                value: r,
                child: Text('${formatBmiDate(r.date)} · ${r.value} $unit'),
              ),
          ],
          onChanged: records.isEmpty ? null : onChanged,
        ),
      ],
    );
  }
}

class _BmiResultCard extends StatelessWidget {
  const _BmiResultCard({required this.result});
  final BmiResult result;

  @override
  Widget build(BuildContext context) {
    if (result.isTooFarApart) {
      return CardContainer(
        color: AppColors.amberSurfaceLight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.amberDark),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hai ngày đo cách nhau quá xa',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.amberHeadline),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hai lần đo cách nhau ${result.dayGap} ngày. Với bé ${result.ageMonths} tháng tuổi, '
                    'chiều cao và cân nặng cần đo cách nhau không quá ${result.maxDayGap} ngày để tính BMI chính xác. '
                    'Hãy chọn hai lần đo gần nhau hơn hoặc đo lại cho bé.',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final category = result.category;
    final zScore = result.zScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          color: AppColors.surfaceGreenLighter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chỉ số BMI', style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      Text(formatBmi(result.bmi!), style: AppTextStyles.h1.copyWith(color: AppColors.primaryDark)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Phân loại', style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      BmiCategoryChip(category: category),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Chiều cao ${result.height.value} cm (${formatBmiDate(result.height.date)}) · '
                'Cân nặng ${result.weight.value} kg (${formatBmiDate(result.weight.date)})',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BMI theo tuổi (chuẩn WHO)', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text(
                zScore == null
                    ? 'Chưa có dữ liệu chuẩn WHO cho bé ${result.ageMonths} tháng tuổi nên chưa thể phân loại.'
                    : 'Bé ${result.ageMonths} tháng tuổi · Z-score ${zScore >= 0 ? '+' : ''}'
                        '${zScore.toStringAsFixed(1).replaceAll('.', ',')}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              BmiCategoryScale(current: category),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const MedicalDisclaimerBanner(text: MedicalDisclaimerBanner.resultsText),
      ],
    );
  }
}

/// BMI tab of the Growth history screen: each weight record is paired with
/// the height measured closest to it. Pairs too far apart stay in the list
/// with a note instead of a value, so the parent sees which one is missing.
class BmiHistoryList extends StatefulWidget {
  const BmiHistoryList({super.key});

  @override
  State<BmiHistoryList> createState() => _BmiHistoryListState();
}

class _BmiHistoryListState extends State<BmiHistoryList> {
  List<BmiResult>? _results;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final growth = ServiceLocator.growthService;
    final records = await Future.wait([
      growth.getRecords('c1', GrowthMetricType.weight),
      growth.getRecords('c1', GrowthMetricType.height),
    ]);
    final children = await ServiceLocator.childService.getChildren();
    if (!mounted) return;
    setState(() {
      _results = BmiResult.pairNearest(
        weights: records[0],
        heights: records[1],
        child: children.firstWhere((c) => c.id == 'c1'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    if (results == null) return const Center(child: CircularProgressIndicator());
    // Records are newest first; the chart reads oldest → newest.
    final valid = results.where((r) => !r.isTooFarApart).toList().reversed.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xu hướng BMI', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 160,
                  child: valid.length < 2
                      ? Center(child: Text('Cần ít nhất 2 lần đo hợp lệ.', style: AppTextStyles.caption))
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [for (var i = 0; i < valid.length; i++) FlSpot(i.toDouble(), valid[i].bmi!)],
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData:
                                    BarAreaData(show: true, color: AppColors.surfaceGreen.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Các lần đo', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          if (results.isEmpty) Text('Chưa có số đo chiều cao để tính BMI.', style: AppTextStyles.caption),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: CardContainer(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.isTooFarApart ? '${formatBmiDate(r.date)} · BMI —' : '${formatBmiDate(r.date)} · BMI ${formatBmi(r.bmi!)}',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.isTooFarApart
                                ? 'Chiều cao gần nhất lệch ${r.dayGap} ngày (tối đa ${r.maxDayGap} ngày) — chưa tính được'
                                : '${r.height.value} cm (${formatBmiDate(r.height.date)}) · '
                                    '${r.weight.value} kg (${formatBmiDate(r.weight.date)})',
                            style: AppTextStyles.caption.copyWith(
                              color: r.isTooFarApart ? AppColors.amberDark : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!r.isTooFarApart) ...[
                      const SizedBox(width: AppSpacing.sm),
                      BmiCategoryChip(category: r.category),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill showing the WHO category, or a muted "Chưa phân loại" when the
/// standard table has no data for this age yet.
class BmiCategoryChip extends StatelessWidget {
  const BmiCategoryChip({super.key, required this.category});
  final BmiCategory? category;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c?.surface ?? AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        c?.label ?? 'Chưa phân loại',
        style: AppTextStyles.caption.copyWith(
          color: c?.color ?? AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Five-band WHO scale; the child's band is highlighted, the rest muted.
class BmiCategoryScale extends StatelessWidget {
  const BmiCategoryScale({super.key, required this.current});
  final BmiCategory? current;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in BmiCategory.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: c == current ? c.color : c.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: c == current ? c.color : AppColors.textSecondaryAlt,
                      fontWeight: c == current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    c.zScoreRange,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
