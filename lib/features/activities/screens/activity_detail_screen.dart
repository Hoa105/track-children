import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/activity.dart';
import '../../../models/activity_group.dart';
import '../../../services/service_locator.dart';

/// Single detail screen that branches on [Activity.kind] instead of 3
/// separate screen files (move / music / story from the prototype's
/// screens 12b/13/13b) — the layouts share ~80% of their structure (hero,
/// back+favorite icons, title, tags, favorite/done buttons), so branching
/// keeps the shared chrome in one place instead of duplicating it 3 times.
class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});
  final String activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  Activity? _activity;
  ActivityGroup? _group;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    ServiceLocator.activityService.getGroups().then((groups) {
      for (final g in groups) {
        for (final a in g.items) {
          if (a.id == widget.activityId) {
            setState(() {
              _activity = a;
              _group = g;
              _isFavorite = a.isFavorite;
            });
            return;
          }
        }
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final activity = _activity;
    final group = _group;
    if (activity == null || group == null) return;
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    await ServiceLocator.activityService.toggleFavorite(group.id, activity.id, next);
  }

  Future<void> _markDone() async {
    final activity = _activity;
    final group = _group;
    if (activity == null || group == null) return;
    await ServiceLocator.activityService.markDone(group.id, activity.id, true);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đánh dấu hoạt động hoàn thành')),
    );
    // Changed from the prototype's original shortcut (jumping to "Thêm
    // nhật ký"): now returns to whichever screen pushed this detail (the
    // activity list, or Home's activity-of-the-day card) per product
    // decision — logging to the journal is a separate, deliberate action.
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final group = _group;
    if (activity == null || group == null) {
      return const AppShellScaffold(
        tab: AppTab.activities,
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppShellScaffold(
      tab: AppTab.activities,
      appBar: null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  IllustrationPlaceholder(
                    label: activity.name,
                    height: 160,
                    color: group.tint,
                    icon: switch (activity.kind) {
                      ActivityKind.move => Icons.sports_gymnastics_rounded,
                      ActivityKind.music => Icons.music_note_rounded,
                      ActivityKind.story => Icons.menu_book_rounded,
                    },
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _iconButton(Icons.arrow_back_rounded, () => context.pop()),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _iconButton(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      _toggleFavorite,
                      color: _isFavorite ? AppColors.danger : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(activity.name, style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _tag(activity.ageRangeLabel),
                  _tag(activity.durationLabel),
                  if (activity.tagsNote != null) _tag(activity.tagsNote!),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              ..._buildKindSpecificSections(activity),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleFavorite,
                      icon: Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                      label: Text(_isFavorite ? 'Đã yêu thích' : 'Yêu thích'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(label: 'Đánh dấu đã thực hiện', onPressed: _markDone),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildKindSpecificSections(Activity activity) {
    switch (activity.kind) {
      case ActivityKind.move:
        return [
          if (activity.goal != null) _section('Mục tiêu', activity.goal!),
          if (activity.materials.isNotEmpty) _bulletSection('Cần chuẩn bị', activity.materials),
          if (activity.steps.isNotEmpty) _numberedSection('Các bước thực hiện', activity.steps),
          if (activity.safetyNote != null) _warningNote(activity.safetyNote!),
        ];
      case ActivityKind.music:
        return [
          if (activity.lyrics != null) _audioBar(),
          if (activity.lyrics != null) _section('Lời bài hát', activity.lyrics!),
          if (activity.movementTip != null) _tipNote(activity.movementTip!),
        ];
      case ActivityKind.story:
        return [
          for (var i = 0; i < activity.storyParagraphs.length; i++)
            _section('Đoạn ${i + 1}', activity.storyParagraphs[i]),
          if (activity.questionsToAsk != null) _tipNote(activity.questionsToAsk!, title: 'Hỏi bé sau khi kể'),
        ];
    }
  }

  Widget _audioBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surfaceGreenLighter, borderRadius: AppRadius.smallRadius),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryDark, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(value: 0.3, minHeight: 6, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('0:12 / 0:40', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(body, style: AppTextStyles.bodyRegular),
        ],
      ),
    );
  }

  Widget _bulletSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item, style: AppTextStyles.bodyRegular)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _numberedSection(String title, List<String> steps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ', style: AppTextStyles.body),
                  Expanded(child: Text(steps[i], style: AppTextStyles.bodyRegular)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _warningNote(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerSurfaceLight,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: AppColors.dangerSurface),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Lưu ý an toàn: $text', style: AppTextStyles.caption.copyWith(color: AppColors.dangerDark))),
        ],
      ),
    );
  }

  Widget _tipNote(String text, {String title = 'Gợi ý cho mẹ'}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.purpleSurfaceLight,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: AppColors.purpleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.captionBold.copyWith(color: AppColors.purpleHeading)),
          const SizedBox(height: 4),
          Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.purpleBody)),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: AppRadius.smallRadius),
      child: Text(text, style: AppTextStyles.caption),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {Color color = AppColors.textSecondary}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
