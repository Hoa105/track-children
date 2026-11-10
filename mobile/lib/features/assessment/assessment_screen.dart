import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'assessment_models.dart';
import 'assessment_repository.dart';
import 'assessment_widgets.dart';
import 'assessment_overview_widgets.dart';
import 'assessment_question_screen.dart';
import 'assessment_result_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({
    super.key,
    required this.childId,
    this.initialHistory = false,
    this.repository,
  });
  final String childId;
  final bool initialHistory;
  final AssessmentRepository? repository;
  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  late final repo = widget.repository ?? assessmentRepository();
  late bool historyTab = widget.initialHistory;
  Map<String, dynamic>? state;
  List<Map<String, dynamic>> records = [];
  String? error;
  int? filter;
  bool busy = true, more = false, loadingMore = false, guidance = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        repo.overview(widget.childId),
        repo.history(widget.childId, age: filter),
      ]);
      if (!mounted || token != generation) return;
      setState(() {
        state = values[0];
        records = (values[1]['items'] as List).map(assessmentMap).toList();
        more = values[1]['has_more'] == true;
        busy = false;
      });
    } catch (e) {
      if (mounted && token == generation) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  Future<void> _more() async {
    if (loadingMore) return;
    setState(() => loadingMore = true);
    final token = generation;
    try {
      final page = await repo.history(
        widget.childId,
        age: filter,
        offset: records.length,
      );
      if (mounted && token == generation) {
        setState(() {
          records.addAll((page['items'] as List).map(assessmentMap));
          more = page['has_more'] == true;
        });
      }
    } catch (e) {
      if (mounted) assessmentMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _open(String id) async {
    try {
      final a = await repo.load(widget.childId, id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => a.completed
              ? AssessmentResultScreen(
                  childId: widget.childId,
                  attempt: a,
                  isDemo: repo.isDemo,
                )
              : a.editable && state?['can_edit'] == true
              ? AssessmentQuestionScreen(
                  childId: widget.childId,
                  attempt: a,
                  repository: repo,
                )
              : AssessmentAnswersScreen(attempt: a, isDemo: repo.isDemo),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) assessmentMessage(context, e.toString());
    }
  }

  Future<void> _start() async {
    final a = state?['age_months'];
    if (a == null) return;
    final yes = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: AssessmentIconBadge(Icons.play_lesson_outlined, size: 56),
            ),
            const SizedBox(height: 16),
            Text(
              'Đánh giá mốc $a tháng',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${state!['set']['count']} câu hỏi · 5 lĩnh vực phát triển',
              style: assessmentMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn đáp án phù hợp với khả năng hiện tại của bé. Bạn có thể đọc hướng dẫn, xem ảnh/video và lưu để làm tiếp.',
              style: assessmentBody,
            ),
            const SizedBox(height: 16),
            ...assessmentAnswers.values.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $v', style: assessmentBody),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chưa quan sát nghĩa là chưa có đủ thông tin để biết bé đã làm được hay chưa.',
              style: assessmentMuted,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bắt đầu đánh giá'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau'),
            ),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      final a = await repo.start(
        widget.childId,
        assessmentId(),
        guidance: guidance,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AssessmentQuestionScreen(
            childId: widget.childId,
            attempt: a,
            repository: repo,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AssessmentScaffold(
    backgroundColor: AppColors.background,
    appBar: assessmentAppBar('Đánh giá phát triển'),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                if (repo.isDemo) const AssessmentDemoNote(),
                AssessmentTabs(
                  history: historyTab,
                  onChanged: (value) => setState(() => historyTab = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AssessmentError(message: error!, retry: _load),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: AssessmentReveal(
                      key: ValueKey(historyTab),
                      child: historyTab ? _history() : _overview(),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _overview() {
    final data = state!, a = data['age_months'], draft = data['draft'];
    final completed =
        (data['completed_milestones'] as List? ??
                records.map((r) => r['age_months']).toList())
            .cast<int>()
            .toSet();
    final latest = data['latest_completed'] as Map?;
    final isDone = latest != null || records.any((r) => r['age_months'] == a);
    final id =
        latest?['id'] ??
        records.where((r) => r['age_months'] == a).firstOrNull?['id'];
    final edit = data['can_edit'] == true, unavailable = data['set'] == null;
    final now = DateTime.parse(data['today'].toString());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        AssessmentCard(
          featured: true,
          title: a == null ? 'Mốc đánh giá của bé' : 'Mốc $a tháng',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (a == null) ...[
                const Text(
                  'Chưa có mốc phù hợp để bắt đầu bài mới.',
                  style: assessmentBody,
                ),
                const SizedBox(height: 8),
                Text(
                  now.isBefore(
                        DateTime.parse(
                          data['milestones'][0]['opens_on'].toString(),
                        ),
                      )
                      ? 'Mốc đầu tiên: ${assessmentDate(data['milestones'][0]['opens_on'])}'
                      : 'Bạn vẫn có thể xem lại các bài đã hoàn thành trong Lịch sử.',
                  style: assessmentMuted,
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AssessmentPill(
                      draft != null
                          ? 'Đang làm'
                          : isDone
                          ? 'Đã hoàn thành'
                          : 'Chưa làm',
                    ),
                    if (!unavailable)
                      AssessmentPill('${data['set']['count']} câu hỏi', neutral: true),
                  ],
                ),
                const SizedBox(height: 12),
                const AssessmentDomainTrail(),
                const SizedBox(height: 16),
                if (draft != null) ...[
                  AssessmentProgress(
                    value:
                        (draft['answers'] as Map).length /
                        (draft['questions'] as List).length,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  draft != null
                      ? 'Đã trả lời ${(draft['answers'] as Map).length}/${(draft['questions'] as List).length} câu. Tiếp tục khi bạn sẵn sàng.'
                      : isDone
                      ? 'Kết quả gần nhất đã được lưu. Bạn có thể xem lại hoặc đánh giá lại trong mốc này.'
                      : 'Cùng xem bé đang làm được những kỹ năng nào. Không cần làm bù các mốc đã qua.',
                  style: assessmentBody,
                ),
                const SizedBox(height: 16),
                if (draft != null && edit)
                  FilledButton(
                    onPressed: () => _open(draft['id'] as String),
                    child: const Text('Tiếp tục đánh giá'),
                  )
                else if (isDone)
                  FilledButton(
                    onPressed: () => _open(id as String),
                    child: const Text('Xem kết quả'),
                  )
                else if (edit && !unavailable)
                  FilledButton(
                    onPressed: data['guidance_required'] == true && !guidance
                        ? null
                        : _start,
                    child: const Text('Bắt đầu đánh giá'),
                  ),
                if (isDone && draft == null && edit && !unavailable)
                  TextButton(
                    onPressed: data['guidance_required'] == true && !guidance
                        ? null
                        : _start,
                    child: const Text('Đánh giá lại'),
                  ),
                if (unavailable && draft == null)
                  const Text(
                    'Chưa có bộ câu hỏi đang xuất bản cho mốc này.',
                    style: assessmentMuted,
                  ),
                if (!edit)
                  const Text(
                    'Bạn có quyền xem. Người có quyền chỉnh sửa có thể bắt đầu bài.',
                    style: assessmentMuted,
                  ),
                if (data['guidance_required'] == true && draft == null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Bé sinh non: hãy trao đổi với nhân viên y tế về cách dùng tuổi trước khi chọn bài. App không tự tính tuổi hiệu chỉnh.',
                    style: assessmentBody,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: guidance,
                    onChanged: (v) => setState(() => guidance = v ?? false),
                    title: const Text(
                      'Đã được hướng dẫn dùng tuổi theo ngày sinh cho bài này.',
                      style: assessmentMuted,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            AssessmentIconBadge(Icons.route_outlined, size: 36),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Các mốc phát triển',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Chọn mốc để xem thông tin.',
          style: assessmentMuted,
        ),
        const SizedBox(height: 12),
        AssessmentMilestones(
          milestones: (data['milestones'] as List).map(assessmentMap).toList(),
          today: now,
          currentAge: a as int?,
          completed: completed,
          draftAge: draft?['age_months'] as int?,
          onHistory: (age) {
            setState(() {
              historyTab = true;
              filter = age;
            });
            _load();
          },
        ),
        const SizedBox(height: 16),
        if ((data['past_drafts'] as List? ?? []).isNotEmpty)
          AssessmentCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Bài dở ở mốc cũ', style: assessmentBody),
              leading: const Icon(
                Icons.bookmark_border_rounded,
                color: AppColors.primary,
              ),
              subtitle: const Text(
                'Giữ để xem, không cần làm bù.',
                style: assessmentMuted,
              ),
              children: [
                for (final d in data['past_drafts'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Mốc ${d['age_months']} tháng'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(d['id'] as String),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _history() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
    children: [
      AssessmentAgeFilter(
        age: filter,
        onChanged: (age) {
          setState(() => filter = age);
          _load();
        },
      ),
      const SizedBox(height: 16),
      if (records.isEmpty)
        AssessmentCard(
          icon: Icons.history_rounded,
          title: 'Chưa có bài đánh giá',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                filter == null
                    ? 'Các bài đã hoàn thành sẽ được lưu tại đây.'
                    : 'Chưa có bài hoàn thành ở mốc $filter tháng.',
                style: assessmentBody,
              ),
              TextButton(
                onPressed: () => setState(() => historyTab = false),
                child: const Text('Về mốc hiện tại'),
              ),
            ],
          ),
        )
      else
        ...records.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AssessmentCard(
              icon: Icons.event_available_rounded,
              title: 'Mốc ${r['age_months']} tháng',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lần ${r['attempt_number']} · ${assessmentDate(r['completed_at'], time: true)}',
                    style: assessmentMuted,
                  ),
                  const SizedBox(height: 12),
                  AssessmentCounts(summary: assessmentMap(r['summary'])),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _open(r['id'] as String),
                    child: const Text('Xem kết quả'),
                  ),
                ],
              ),
            ),
          ),
        ),
      if (more)
        TextButton(
          onPressed: loadingMore ? null : _more,
          child: Text(loadingMore ? 'Đang tải…' : 'Xem thêm bài'),
        ),
    ],
  );
}
