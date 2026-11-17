import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/video_insight.dart';

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

/// AI comments on a diary video: observations, comment, positives, next steps.
class VideoInsightView extends StatelessWidget {
  const VideoInsightView({super.key, required this.insight});
  final VideoInsight insight;

  @override
  Widget build(BuildContext context) {
    if (!insight.finished) {
      return const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI đang xem video của bé, thường mất khoảng 1 phút…',
              style: _body,
            ),
          ),
        ],
      );
    }
    final result = insight.result;
    if (insight.status != 'done' || result == null) {
      final notice = _Notice(
        icon: Icons.videocam_off_outlined,
        title: insight.status == 'rejected'
            ? 'Video chưa phù hợp để phân tích'
            : 'Chưa phân tích được video',
        text: insight.message ?? 'Ba mẹ thử gửi lại sau ít phút nhé.',
      );
      // "failed" là lỗi máy chủ, không phải do cách quay: chỉ hướng dẫn khi video bị từ chối.
      return insight.status == 'rejected'
          ? _RecordAgain(notice: notice, guide: _defaultGuide)
          : notice;
    }
    if (!result.canAssess) {
      return _RecordAgain(
        notice: _Notice(
          icon: Icons.videocam_off_outlined,
          title: 'AI chưa nhận xét được video này',
          text: result.videoIssue.isEmpty
              ? 'Ba mẹ thử quay lại, thấy rõ toàn thân bé và đủ sáng nhé.'
              : result.videoIssue,
        ),
        // Bài K-DST: máy chủ gửi hướng dẫn riêng của bài trong nextSteps.
        guide: result.nextSteps.isEmpty ? _defaultGuide : result.nextSteps,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.seeSpecialist && result.specialistNote.isNotEmpty) ...[
          _Notice(
            icon: Icons.health_and_safety_outlined,
            title: 'Ba mẹ lưu ý',
            text: result.specialistNote,
          ),
          const SizedBox(height: 16),
        ],
        _Section(
          icon: Icons.visibility_outlined,
          title: 'Quan sát',
          items: result.observations,
        ),
        if (result.comment.isNotEmpty)
          _Section(
            icon: Icons.chat_outlined,
            title: 'Nhận xét',
            text: result.comment,
          ),
        _Section(
          icon: Icons.star_outline_rounded,
          title: 'Điểm tích cực',
          items: result.positives,
        ),
        _Section(
          icon: Icons.flag_outlined,
          title: 'Dấu hiệu cần chú ý',
          items: result.watchSigns,
          text: result.watchSigns.isEmpty && !result.seeSpecialist
              ? 'Chưa thấy dấu hiệu nào cần lưu ý trong video này.'
              : null,
        ),
        _Section(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Gợi ý tiếp theo',
          items: result.nextSteps,
        ),
        if (insight.evidence.isNotEmpty)
          _Section(
            icon: Icons.straighten_rounded,
            title: 'Số đo tự động từ video',
            items: [
              for (final m in insight.evidence)
                '${m.label}: ${m.valueLabel} ${m.unit}',
            ],
            footnote:
                'Số đo ước lượng từ khung xương trong video, có thể lệch '
                'khi bé bị che khuất hoặc máy quay di chuyển.',
          ),
        const Text(
          'Nhận xét do AI tạo từ một số khung hình của video, chỉ mang tính '
          'tham khảo và không thay thế đánh giá của chuyên gia.',
          style: _caption,
        ),
      ],
    );
  }
}

/// Cách quay chung khi máy chủ không gửi hướng dẫn riêng của bài.
const _defaultGuide = [
  'Kê hoặc dựng điện thoại cố định ngang tầm bé, không cầm máy đi theo bé.',
  'Thấy trọn người bé từ đầu tới bàn chân trong suốt video, đủ sáng, không có người hay vật che.',
  'Mỗi video chỉ có một bé và một lần thực hiện hoạt động, dài khoảng 8–15 giây.',
];

/// Lý do chưa nhận xét được + hướng dẫn quay lại ngay bên dưới.
class _RecordAgain extends StatelessWidget {
  const _RecordAgain({required this.notice, required this.guide});
  final Widget notice;
  final List<String> guide;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      notice,
      const SizedBox(height: 16),
      _Section(
        icon: Icons.videocam_outlined,
        title: 'Hướng dẫn quay lại',
        items: guide,
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    this.items = const [],
    this.text,
    this.footnote,
  });
  final IconData icon;
  final String title;
  final List<String> items;
  final String? text;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && (text == null || text!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          if (text != null) Text(text!, style: _body),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: _body),
                  Expanded(child: Text(item, style: _body)),
                ],
              ),
            ),
          if (footnote != null) Text(footnote!, style: _caption),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title, text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _warningSurface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _warningText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _title.copyWith(color: _warningText)),
              const SizedBox(height: 4),
              Text(text, style: _body.copyWith(color: _warningText)),
            ],
          ),
        ),
      ],
    ),
  );
}
