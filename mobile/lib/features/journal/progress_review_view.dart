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

/// The five parent-facing sections of a review: overview, progress over
/// time, strengths / support, signs to watch, care and practice plan.
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
        // 1. Tổng quan quá trình phát triển
        _NumberedSection(
          number: 1,
          icon: Icons.child_care_rounded,
          title: 'Tổng quan quá trình phát triển',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Stat('${review.insightIds.length}', 'video'),
                if (review.activities.isNotEmpty)
                  _Stat('${review.activities.length}', 'hoạt động'),
                if (review.skillsDone.isNotEmpty)
                  _Stat('${review.skillsDone.length}', 'kỹ năng đã làm được'),
              ],
            ),
            const SizedBox(height: 12),
            Text(review.summary, style: _body),
            _Sub('Kỹ năng bé đã làm được', items: review.skillsDone),
            _Sub('Kỹ năng đang được cải thiện', items: review.skillsImproving),
            _Sub('Giai đoạn hiện tại', text: review.stage),
          ],
        ),
        // 2. Theo dõi sự tiến bộ theo thời gian
        _NumberedSection(
          number: 2,
          icon: Icons.trending_up_rounded,
          title: 'Sự tiến bộ theo thời gian',
          children: [
            for (final trend in review.metrics)
              if (trend.points.length > 1) ...[
                _TrendCard(trend: trend),
                const SizedBox(height: 8),
              ],
            _Sub('Thay đổi qua các lần quay', items: review.progress),
            _Sub('Từ cần hỗ trợ đến tự thực hiện', text: review.independence),
            _Sub('Tốc độ tiến bộ', text: review.pace),
          ],
        ),
        // 3. Điểm mạnh và kỹ năng cần hỗ trợ
        _NumberedSection(
          number: 3,
          icon: Icons.star_outline_rounded,
          title: 'Điểm mạnh và kỹ năng cần hỗ trợ',
          children: [
            _Sub('Bé làm tốt', items: review.strengths),
            _Sub('Bé còn gặp khó khăn', items: review.challenges),
            _Sub('Kỹ năng cần luyện thêm', items: review.keepPracticing),
          ],
        ),
        // 4. Những dấu hiệu cần chú ý
        _NumberedSection(
          number: 4,
          icon: Icons.visibility_outlined,
          title: 'Những dấu hiệu cần chú ý',
          empty: 'Chưa thấy dấu hiệu nào cần đặc biệt lưu ý trong các video.',
          children: [
            _Sub('Lặp lại qua nhiều video', items: review.repeatedPatterns),
            _Sub('Chưa thấy trong các lần quan sát', items: review.notYetSeen),
            _Sub('Thay đổi trong hành vi', items: review.behaviorChanges),
            if (review.seeSpecialist && review.specialistNote.isNotEmpty)
              _Sub('Trao đổi với chuyên gia', text: review.specialistNote),
          ],
        ),
        // 5. Kế hoạch chăm sóc và luyện tập
        _NumberedSection(
          number: 5,
          icon: Icons.event_note_outlined,
          title: 'Kế hoạch chăm sóc và luyện tập',
          children: [
            _Sub('Hoạt động cho tuần tới', items: review.nextSteps),
            _Sub('Kỹ năng ưu tiên hỗ trợ', items: review.prioritySkills),
            _Sub('Cách ba mẹ tương tác với bé', items: review.parentTips),
            _Sub('Lần quay video tiếp theo', text: review.nextRecording),
          ],
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
                          // Cột chiếm phần chiều cao còn lại, nên chữ lớn không làm tràn khung
                          Expanded(
                            child: FractionallySizedBox(
                              alignment: Alignment.bottomCenter,
                              heightFactor: top == 0
                                  ? 0.02
                                  : (0.02 + 0.98 * p.value / top).clamp(
                                      0.02,
                                      1.0,
                                    ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: p == trend.points.last
                                      ? AppColors.primary
                                      : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
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

/// Numbered card; hidden when every [_Sub] inside is empty, unless [empty]
/// gives a sentence to show instead.
class _NumberedSection extends StatelessWidget {
  const _NumberedSection({
    required this.number,
    required this.icon,
    required this.title,
    required this.children,
    this.empty,
  });
  final int number;
  final IconData icon;
  final String title;
  final List<Widget> children;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final visible = children.where((w) => w is! _Sub || !w.isEmpty).toList();
    if (visible.isEmpty && empty == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('$number. $title', style: _title)),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty) Text(empty!, style: _caption) else ...visible,
          ],
        ),
      ),
    );
  }
}

/// Labelled bullet list or paragraph inside a [_NumberedSection].
class _Sub extends StatelessWidget {
  const _Sub(this.label, {this.items = const [], this.text = ''});
  final String label;
  final List<String> items;
  final String text;

  bool get isEmpty => items.isEmpty && text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (text.trim().isNotEmpty) Text(text.trim(), style: _body),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('•  $item', style: _body),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value ',
            style: _title.copyWith(color: AppColors.primary),
          ),
          TextSpan(text: label, style: _caption),
        ],
      ),
    ),
  );
}

/// One row of the review history.
class ProgressReviewTile extends StatelessWidget {
  const ProgressReviewTile({
    super.key,
    required this.review,
    required this.period,
    required this.onTap,
  });
  final ProgressReview review;
  final (DateTime, DateTime) period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
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
