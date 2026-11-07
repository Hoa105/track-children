import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/progress_review.dart';

const _title = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
);
const _body = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: AppColors.textPrimary,
);
const _caption = TextStyle(
  fontSize: 12,
  height: 1.5,
  color: AppColors.textSecondary,
);
const _warningSurface = Color(0xFFFFF4E0);
const _warningText = Color(0xFF7A4B00);
String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _number(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Summary, metric trends, progress, practice and next steps of a review.
class ProgressReviewView extends StatelessWidget {
  const ProgressReviewView({super.key, required this.review, this.period});
  final ProgressReview review;

  /// Ngày quay video đầu / cuối; mặc định ngày server nhận video.
  final (DateTime, DateTime)? period;

  @override
  Widget build(BuildContext context) {
    final (from, to) = period ?? (review.periodFrom, review.periodTo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${review.insightIds.length} video quay ${dateLabel(from)} – '
          '${dateLabel(to)} · đánh giá ngày ${dateLabel(review.createdAt)}',
          style: _caption,
        ),
        const SizedBox(height: 12),
        if (review.seeSpecialist && review.specialistNote.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _warningSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.health_and_safety_outlined,
                  color: _warningText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    review.specialistNote,
                    style: _body.copyWith(color: _warningText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _Card(child: Text(review.summary, style: _body)),
        for (final trend in review.metrics)
          if (trend.points.length > 1) ...[
            const SizedBox(height: 12),
            _TrendCard(trend: trend),
          ],
        _Section(
          icon: Icons.trending_up_rounded,
          title: 'Thay đổi qua các lần quay',
          items: review.progress,
        ),
        _Section(
          icon: Icons.replay_rounded,
          title: 'Tiếp tục luyện cùng bé',
          items: review.keepPracticing,
        ),
        _Section(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Gợi ý tiếp theo',
          items: review.nextSteps,
        ),
        const SizedBox(height: 16),
        const Text(
          'Tổng hợp do AI viết từ các nhận xét video trước đó, chỉ mang tính '
          'tham khảo và không thay thế đánh giá của chuyên gia.',
          style: _caption,
        ),
      ],
    );
  }
}

/// Bar per video (oldest → newest) for one automatic measurement.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});
  final MetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final top = trend.points
        .map((p) => p.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final change = trend.change;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trend.label, style: _title),
          if (change != null)
            Text(
              change == 0
                  ? 'Như lần đầu (theo số đo tự động)'
                  : '${change > 0 ? '+' : ''}${_number(change)} ${trend.unit} '
                        'so với lần đầu (theo số đo tự động)',
              style: _caption,
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in trend.points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(_number(p.value), style: _caption),
                          const SizedBox(height: 4),
                          Container(
                            height: top == 0 ? 2 : 2 + 70 * p.value / top,
                            decoration: BoxDecoration(
                              color: p == trend.points.last
                                  ? AppColors.primary
                                  : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.at.day}/${p.at.month}',
                            style: _caption,
                            maxLines: 1,
                          ),
                        ],
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.items,
  });
  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: _title)),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('•  $item', style: _body),
            ),
        ],
      ),
    );
  }
}

/// One row of the review history; [selected] = the review shown above.
class ProgressReviewTile extends StatelessWidget {
  const ProgressReviewTile({
    super.key,
    required this.review,
    required this.period,
    required this.selected,
    required this.onTap,
  });
  final ProgressReview review;
  final (DateTime, DateTime) period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primarySoft : AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${review.activityTitle} · đánh giá ${dateLabel(review.createdAt)}',
              style: _caption,
            ),
            Text(
              '${review.insightIds.length} video quay '
              '${dateLabel(period.$1)} – ${dateLabel(period.$2)}',
              style: _caption,
            ),
            Text(
              review.summary,
              style: _body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
