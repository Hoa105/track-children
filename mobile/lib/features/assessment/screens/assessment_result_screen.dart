import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/domain_progress_row.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../models/assessment_result.dart';
import '../../../services/service_locator.dart';

class AssessmentResultScreen extends StatefulWidget {
  const AssessmentResultScreen({super.key});

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  AssessmentResult? _result;

  @override
  void initState() {
    super.initState();
    ServiceLocator.assessmentService.getLatestResult('c1').then((r) => setState(() => _result = r));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AppShellScaffold(
      tab: AppTab.home,
      appBar: AppBar(title: const Text('Kết quả đánh giá')),
      body: result == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGreenLighter,
                      borderRadius: AppRadius.largeRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 48),
                        const SizedBox(height: AppSpacing.md),
                        Text('Bé đang phát triển tốt', style: AppTextStyles.h2, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Đạt ${result.totalAchieved}/${result.totalPossible} mốc · 17/08/2026',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const MedicalDisclaimerBanner(text: MedicalDisclaimerBanner.resultsText),
                  const SizedBox(height: AppSpacing.lg),
                  CardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chi tiết theo lĩnh vực', style: AppTextStyles.h3),
                        const SizedBox(height: AppSpacing.sm),
                        for (final entry in result.domainScores.entries)
                          DomainProgressRow(
                            domain: entry.key,
                            achieved: entry.value.achieved,
                            total: entry.value.total,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CardContainer(
                    color: AppColors.amberSurfaceLight,
                    borderColor: AppColors.amberBorder,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vì sao có kết luận này?',
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.amberHeadline)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Nhóm Ngôn ngữ đạt 4/6 mốc và giảm nhẹ so với lần trước → hệ thống khuyến nghị theo dõi thêm trong 4 tuần.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.amberHeadline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Gợi ý hoạt động phù hợp',
                    onPressed: () => context.push(AppRoutes.activityGroups),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Xem lịch sử đánh giá',
                    onPressed: () => context.push(AppRoutes.history),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }
}
