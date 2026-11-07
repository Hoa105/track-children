import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../../models/video_insight.dart';
import '../../services/demo_store.dart';
import 'journal_screen.dart';
import '../../models/progress_review.dart';
import 'progress_review_view.dart';

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);
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
const _errorText = Color(0xFF7A4B00);
const _caption = TextStyle(
  fontSize: 12,
  height: 1.5,
  color: AppColors.textSecondary,
);
String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Video nhật ký AI nhận xét được (đã xong, đủ rõ) — dùng cho đánh giá tổng hợp.
bool usableInsight(VideoInsight insight) =>
    insight.status == 'done' && (insight.result?.canAssess ?? false);

/// Analysed diary videos + one AI review over all of them.
///
/// The time range picker sits on top: "Đánh giá tổng hợp" summarises every
/// analysed video (all activities) filmed in that range into one review.
/// Below: the latest review, review history, and the videos in the range.
class AiVideosScreen extends StatefulWidget {
  const AiVideosScreen({super.key, required this.childId});
  final String childId;
  @override
  State<AiVideosScreen> createState() => _AiVideosScreenState();
}

/// Số video tối đa trong một lần đánh giá (backend NewProgressReview).
const maxReviewVideos = 60;

class _AiVideosScreenState extends State<AiVideosScreen> {
  /// Null = từ video đầu tiên đến video mới nhất (tự mở rộng khi có video mới).
  DateTimeRange? _picked;
  List<ProgressReview> _history = [];
  ProgressReview? _shown;
  String? _error;
  bool _loadingHistory = true;
  bool _reviewing = false;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _entryDay(Map<String, dynamic> entry) =>
      _day(DateTime.parse(entry['date'] as String));

  @override
  void initState() {
    super.initState();
    _refreshPending();
    _loadHistory();
  }

  /// Nhận xét còn đang chạy: hỏi lại server một lần khi mở màn hình.
  Future<void> _refreshPending() async {
    final store = DemoStore.instance;
    for (final entry in store.analysedJournalEntries(widget.childId)) {
      final insight = VideoInsight.fromJson(
        Map<String, dynamic>.from(entry['insight'] as Map),
      );
      if (insight.finished) continue;
      try {
        await store.refreshJournalInsight(
          widget.childId,
          entry['id'] as String,
        );
      } on Exception {
        return; // mất mạng: giữ trạng thái đã lưu
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _error = null;
    });
    try {
      final history = await DemoStore.instance.progressReviews(widget.childId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _shown = history.firstOrNull;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  DateTimeRange _fullRange(List<Map<String, dynamic>> entries) {
    final days = entries.map(_entryDay).toList()..sort();
    final today = _day(DateTime.now());
    return days.isEmpty
        ? DateTimeRange(start: today, end: today)
        : DateTimeRange(start: days.first, end: days.last);
  }

  Future<void> _pickRange(DateTimeRange full, DateTimeRange current) async {
    final today = _day(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: full.start,
      lastDate: full.end.isAfter(today) ? full.end : today,
      initialDateRange: current,
      helpText: 'Chọn khoảng thời gian quay video',
      saveText: 'Áp dụng',
    );
    if (picked != null && mounted) {
      setState(
        () => _picked = DateTimeRange(
          start: _day(picked.start),
          end: _day(picked.end),
        ),
      );
    }
  }

  Future<void> _review(List<String> insightIds) async {
    setState(() {
      _reviewing = true;
      _error = null;
    });
    try {
      final review = await DemoStore.instance.createProgressReview(
        widget.childId,
        insightIds,
      );
      if (!mounted) return;
      setState(() {
        // Cùng tập video: server trả lại lần đánh giá cũ → không thêm trùng
        _history = [review, ..._history.where((r) => r.id != review.id)];
        _shown = review;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final all = DemoStore.instance.analysedJournalEntries(widget.childId);
      final full = _fullRange(all);
      final range = _picked ?? full;
      final inRange = [
        for (final e in all)
          if (!_entryDay(e).isBefore(range.start) &&
              !_entryDay(e).isAfter(range.end))
            e,
      ];
      final groups = _ActivityVideos.group(inRange);
      // Ngày nhật ký (ngày quay thực tế) của từng video, mới nhất trước
      final dates = <String, DateTime>{
        for (final e in all)
          (e['insight'] as Map)['id'] as String: _entryDay(e),
      };
      final usable = [
        for (final g in groups)
          for (final (entry, insight) in g.entries)
            if (usableInsight(insight)) (insight.id, _entryDay(entry)),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      final reviewIds = [
        for (final (id, _) in usable.take(maxReviewVideos)) id,
      ];
      final activities = {
        for (final g in groups)
          if (g.usableIds.isNotEmpty) g.name,
      }.length;
      (DateTime, DateTime) period(ProgressReview r) {
        final days = [for (final id in r.insightIds) ?dates[id]]..sort();
        return days.isEmpty
            ? (r.periodFrom, r.periodTo)
            : (days.first, days.last);
      }

      final shown = _shown;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Video đã phân tích AI', style: _heading),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.pagePadding,
            8,
            AppLayout.pagePadding,
            32,
          ),
          children: [
            if (all.isEmpty)
              const _Panel(
                child: Column(
                  children: [
                    Icon(
                      Icons.smart_display_outlined,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Chưa có video nào được AI nhận xét',
                      style: _title,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Quay video khi cùng bé làm một hoạt động rồi chọn '
                      '"Nhờ AI nhận xét" để theo dõi bé qua thời gian.',
                      style: _body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Đánh giá tổng hợp', style: _title),
                    const SizedBox(height: 4),
                    const Text(
                      'AI gộp tất cả video đã nhận xét trong khoảng thời gian '
                      'này thành một đánh giá.',
                      style: _caption,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _reviewing
                                ? null
                                : () => _pickRange(full, range),
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              '${_dateLabel(range.start)} – '
                              '${_dateLabel(range.end)}',
                            ),
                          ),
                        ),
                        if (_picked != null)
                          TextButton(
                            onPressed: _reviewing
                                ? null
                                : () => setState(() => _picked = null),
                            child: const Text('Tất cả'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      usable.length >= 2
                          ? '${usable.length} video AI đã nhận xét · '
                                '$activities hoạt động trong khoảng này'
                          : '${usable.length} video AI đã nhận xét trong khoảng '
                                'này — cần ít nhất 2 video để tổng hợp',
                      style: _caption,
                    ),
                    if (usable.length > maxReviewVideos)
                      const Text(
                        'Khoảng này có nhiều video, AI sẽ tổng hợp '
                        '$maxReviewVideos video gần nhất.',
                        style: _caption,
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: usable.length >= 2 && !_reviewing
                          ? () => _review(reviewIds)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: _reviewing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.insights_rounded),
                      label: Text(
                        _reviewing
                            ? 'AI đang tổng hợp các video…'
                            : 'Đánh giá tổng hợp',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: _body.copyWith(color: _errorText)),
                      if (!_loadingHistory && _history.isEmpty)
                        TextButton(
                          onPressed: _loadHistory,
                          child: const Text('Tải lại lịch sử'),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                shown != null && shown.id != _history.firstOrNull?.id
                    ? 'Kết quả đánh giá ngày ${_dateLabel(shown.createdAt)}'
                    : 'Kết quả gần nhất',
                style: _title,
              ),
              const SizedBox(height: 8),
              if (_loadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (shown == null)
                const _Panel(
                  child: Text(
                    'Chưa có lần đánh giá nào. Chọn khoảng thời gian rồi bấm '
                    '"Đánh giá tổng hợp".',
                    style: _body,
                  ),
                )
              else
                ProgressReviewView(review: shown, period: period(shown)),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Lịch sử đánh giá (${_history.length})', style: _title),
                const SizedBox(height: 8),
                for (final r in _history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ProgressReviewTile(
                      review: r,
                      period: period(r),
                      selected: r.id == shown?.id,
                      onTap: () => setState(() => _shown = r),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text('Video trong khoảng này (${inRange.length})', style: _title),
              const SizedBox(height: 8),
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityPanel(childId: widget.childId, group: group),
                ),
            ],
          ],
        ),
      );
    },
  );
}

/// One activity's analysed journal entries, newest first.
class _ActivityVideos {
  _ActivityVideos(this.activityId, this.name);
  final String? activityId;
  final String name;
  final entries = <(Map<String, dynamic>, VideoInsight)>[];

  List<String> get usableIds => [
    for (final (_, insight) in entries)
      if (usableInsight(insight)) insight.id,
  ];

  static List<_ActivityVideos> group(List<Map<String, dynamic>> entries) {
    final groups = <String, _ActivityVideos>{};
    for (final entry in entries) {
      final id = entry['activityId'] as String?;
      final group = groups.putIfAbsent(
        id ?? '',
        () => _ActivityVideos(
          id,
          entry['activityName'] as String? ?? 'Hoạt động khác',
        ),
      );
      group.entries.add((
        entry,
        VideoInsight.fromJson(
          Map<String, dynamic>.from(entry['insight'] as Map),
        ),
      ));
    }
    for (final g in groups.values) {
      g.entries.sort(
        (a, b) => (b.$1['date'] as String).compareTo(a.$1['date'] as String),
      );
    }
    // Hoạt động có video mới nhất lên đầu
    return groups.values.toList()..sort(
      (a, b) => (b.entries.first.$1['date'] as String).compareTo(
        a.entries.first.$1['date'] as String,
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.childId, required this.group});
  final String childId;
  final _ActivityVideos group;

  @override
  Widget build(BuildContext context) {
    final usable = group.usableIds.length;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(group.name, style: _title),
          const SizedBox(height: 4),
          Text(
            '${group.entries.length} video · $usable video AI đã nhận xét',
            style: _caption,
          ),
          const SizedBox(height: 8),
          for (final (entry, insight) in group.entries)
            _VideoRow(
              entry: entry,
              insight: insight,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      JournalEditorScreen(childId: childId, entry: entry),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({
    required this.entry,
    required this.insight,
    required this.onTap,
  });
  final Map<String, dynamic> entry;
  final VideoInsight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (insight) {
      _ when !insight.finished => (
        Icons.hourglass_top_rounded,
        AppColors.textSecondary,
        'AI đang xem video…',
      ),
      _ when usableInsight(insight) => (
        Icons.check_circle_outline_rounded,
        AppColors.primary,
        insight.result!.comment.isNotEmpty
            ? insight.result!.comment
            : insight.result!.observations.firstOrNull ?? 'Đã có nhận xét',
      ),
      _ => (
        Icons.videocam_off_outlined,
        AppColors.textSecondary,
        insight.message ??
            (insight.result?.videoIssue.isNotEmpty ?? false
                ? insight.result!.videoIssue
                : 'AI chưa nhận xét được video này'),
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(DateTime.parse(entry['date'] as String)),
                    style: _caption,
                  ),
                  Text(
                    text,
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
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
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
