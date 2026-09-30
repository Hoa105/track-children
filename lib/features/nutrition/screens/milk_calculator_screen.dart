import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';
import '../../../models/child_share.dart';
import '../../../models/growth_record.dart';
import '../../../services/active_child.dart';
import '../../../services/milk_calculator.dart';
import '../../../services/service_locator.dart';

/// "Tính lượng sữa tham khảo cho trẻ" — reference daily / per-feed milk
/// amount for the selected child, from its age and (under 6 months) weight.
class MilkCalculatorScreen extends StatefulWidget {
  const MilkCalculatorScreen({super.key});

  static const disclaimer =
      'Lượng sữa chỉ mang tính tham khảo. Mỗi bé có nhu cầu khác nhau — hãy cho bé bú theo tín hiệu đói/no '
      'và hỏi ý kiến bác sĩ nhi khoa nếu bé sinh non, nhẹ cân hoặc tăng cân chậm.';

  @override
  State<MilkCalculatorScreen> createState() => _MilkCalculatorScreenState();
}

class _MilkCalculatorScreenState extends State<MilkCalculatorScreen> {
  final ActiveChildController _active = ServiceLocator.activeChild;
  final _weightCtrl = TextEditingController();
  ActiveChild? _loadedFor;
  bool _loading = true;
  int? _feeds;

  @override
  void initState() {
    super.initState();
    _weightCtrl.addListener(() => setState(() {}));
    _active.addListener(_load);
    _active.ensure().then((_) => _load());
  }

  @override
  void dispose() {
    _active.removeListener(_load);
    _weightCtrl.dispose();
    super.dispose();
  }

  /// Prefills the weight from the child's latest measurement (when the
  /// viewer may see growth data), otherwise from the birth weight.
  Future<void> _load() async {
    final active = _active.value;
    if (active == null || identical(active, _loadedFor)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    double? weight;
    if (active.canView(ShareSection.growth)) {
      final records = await ServiceLocator.growthService.getRecords(active.child.id, GrowthMetricType.weight);
      final own = records.where((r) => r.childId == active.child.id).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (own.isNotEmpty) weight = own.first.value;
    }
    weight ??= active.child.birthWeightKg;
    if (!mounted) return;
    setState(() {
      _loadedFor = active;
      _loading = false;
      _feeds = null;
      _weightCtrl.text = weight == null ? '' : _fmt(weight);
    });
  }

  double? get _weight => double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final active = _active.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Tính lượng sữa tham khảo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : active == null
              ? Center(child: Text('Chưa có hồ sơ bé.', style: AppTextStyles.bodySecondary))
              : _body(active),
    );
  }

  Widget _body(ActiveChild active) {
    final child = active.child;
    final ageDays = DateTime.now().difference(child.dob).inDays;
    final stage = milkStageFor(ageDays);
    final estimate = estimateMilk(ageDays: ageDays, weightKg: _weight, feedsPerDay: _feeds);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        CardContainer(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surfaceGreen, borderRadius: AppRadius.smallRadius),
                child: const Icon(Icons.baby_changing_station_rounded, color: AppColors.primaryDark),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${child.ageLabel(DateTime.now())}${stage == null ? '' : ' · ${stage.label}'}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (child.isPremature) ...[
          const SizedBox(height: AppSpacing.md),
          _Notice(
            icon: Icons.warning_amber_rounded,
            text: 'Bé sinh non${child.gestationalWeeks == null ? '' : ' (${child.gestationalWeeks} tuần)'}: '
                'lượng sữa cần theo chỉ định của bác sĩ, kết quả dưới đây chỉ để tham khảo.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (stage == null)
          _Notice(
            icon: Icons.info_outline_rounded,
            text: 'Công cụ áp dụng cho trẻ từ sơ sinh đến 5 tuổi. Từ 5 tuổi, bé ăn uống như người lớn '
                'và sữa chỉ là một phần trong khẩu phần hằng ngày.',
          )
        else ...[
          if (stage.needsWeight) ...[
            AppTextField(
              label: 'Cân nặng hiện tại của bé (kg)',
              hint: 'VD: 5.6',
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text('Số cữ bú mỗi ngày', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var n = stage.minFeeds; n <= stage.maxFeeds; n++)
                AppChip(
                  label: '$n cữ',
                  selected: n == (estimate?.feedsPerDay ?? _feeds ?? ((stage.minFeeds + stage.maxFeeds) / 2).round()),
                  onTap: () => setState(() => _feeds = n),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (estimate == null)
            _Notice(icon: Icons.scale_outlined, text: 'Nhập cân nặng của bé (0–30 kg) để tính lượng sữa.')
          else
            _ResultCard(estimate: estimate),
          const SizedBox(height: AppSpacing.lg),
          Text('Lưu ý giai đoạn này', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          for (final tip in [
            ...stage.tips,
            if (ageDays < 6 * 30) 'Bé bú mẹ hoàn toàn nên được bú theo nhu cầu; con số trên dùng khi cho bé bú bình (sữa mẹ vắt hoặc sữa công thức).',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(tip, style: AppTextStyles.bodyRegular)),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Bảng tham khảo theo tháng tuổi', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.sm),
        _ReferenceTable(current: stage),
        const SizedBox(height: AppSpacing.lg),
        const MedicalDisclaimerBanner(text: MilkCalculatorScreen.disclaimer),
      ],
    );
  }
}

String _fmt(double kg) => kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.estimate});

  final MilkEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final e = estimate;
    return CardContainer(
      color: AppColors.surfaceGreenLighter,
      borderColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lượng sữa tham khảo mỗi ngày', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 4),
          Text(
            '${e.minPerDay} – ${e.maxPerDay} ml',
            style: AppTextStyles.h1.copyWith(color: AppColors.primaryDarker),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Mỗi cữ', value: '${e.minPerFeed} – ${e.maxPerFeed} ml')),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Stat(label: 'Số cữ/ngày', value: '${e.feedsPerDay} cữ')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(e.basis, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.smallRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.titleMedium),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.amberSurfaceLight,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: AppColors.amberBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.amberDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodyRegular.copyWith(color: AppColors.amberHeadline))),
        ],
      ),
    );
  }
}

class _ReferenceTable extends StatelessWidget {
  const _ReferenceTable({required this.current});

  final MilkStage? current;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < milkStages.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: identical(milkStages[i], current) ? AppColors.surfaceGreen : null,
                border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      milkStages[i].label,
                      style: identical(milkStages[i], current) ? AppTextStyles.captionBold : AppTextStyles.caption,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      '${milkStages[i].summary}\n'
                      '${milkStages[i].minFeeds == milkStages[i].maxFeeds ? '${milkStages[i].minFeeds}' : '${milkStages[i].minFeeds}–${milkStages[i].maxFeeds}'} cữ/ngày',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
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
