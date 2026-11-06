import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'assessment_models.dart';
import 'assessment_widgets.dart';

class AssessmentResultScreen extends StatefulWidget {
  const AssessmentResultScreen({
    super.key,
    required this.childId,
    required this.attempt,
    required this.isDemo,
  });
  final String childId;
  final AssessmentAttempt attempt;
  final bool isDemo;
  @override
  State<AssessmentResultScreen> createState() =>
      _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.attempt,
        sections = assessmentMap(a.result!['sections']),
        skills = assessmentMap(sections['skills_to_note']),
        comment = assessmentMap(sections['overall_comment']),
        next = assessmentMap(sections['next_steps']),
        all = (skills['all'] as List).map(assessmentMap).toList(),
        shown = expanded ? all : all.take(3).toList();
    final plan = assessmentMap(next['action_plan']);
    return AssessmentScaffold(
      backgroundColor: AppColors.background,
      appBar: assessmentAppBar('Kết quả đánh giá'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AssessmentChildHeader(childId: widget.childId),
            if (widget.isDemo) const AssessmentDemoNote(),
            const SizedBox(height: 16),
            AssessmentReveal(
              child: AssessmentCard(
                featured: true,
                icon: Icons.assignment_turned_in_outlined,
                title: 'Mốc ${a.age} tháng',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AssessmentPill('Đã hoàn thành'),
                    const SizedBox(height: 10),
                    Text(
                      'Hoàn thành ${assessmentDate(a.data['completed_at'], time: true)}',
                      style: assessmentMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            AssessmentCard(
              title: 'Tổng quan',
              icon: Icons.donut_small_rounded,
              child: AssessmentCounts(summary: assessmentMap(sections['overview'])),
            ),
            const SizedBox(height: 16),
            AssessmentCard(
              title: 'Kỹ năng cần chú ý',
              icon: Icons.visibility_outlined,
              accent: const Color(0xFF91621F),
              child: all.isEmpty
                  ? const Text(
                      'Không có kỹ năng chưa làm được hoặc chưa quan sát trong bài này.',
                      style: assessmentBody,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final status in ['not_yet', 'not_observed'])
                          if (shown.any((x) => x['status'] == status)) ...[
                            Text(
                              assessmentAnswers[status]!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...shown
                                .where((x) => x['status'] == status)
                                .map(
                                  (x) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          x['skill_name'] as String,
                                          style: assessmentBody,
                                        ),
                                        const SizedBox(height: 6),
                                        AssessmentDomainLabel(x['domain'] as String?),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        if (all.length > 3)
                          TextButton(
                            onPressed: () =>
                                setState(() => expanded = !expanded),
                            child: Text(
                              expanded
                                  ? 'Thu gọn'
                                  : 'Xem tất cả ${all.length} kỹ năng',
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            AssessmentCard(
              title: 'Nhận xét chung',
              icon: Icons.notes_rounded,
              accent: const Color(0xFF655080),
              tint: const Color(0xFFFAF7FD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in comment['paragraphs'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(p['text'] as String, style: assessmentBody),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AssessmentCard(
              title: 'Hướng dẫn tiếp theo',
              icon: Icons.route_outlined,
              accent: const Color(0xFF326D9B),
              tint: const Color(0xFFF4F8FB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final action in plan['actions']) ...[
                    if (action['id'] == 'prepare')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Khi gặp bác sĩ, bạn nên chuẩn bị:',
                          style: assessmentBody,
                        ),
                      ),
                    if ((action['body'] as String? ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(action['body'] as String, style: assessmentBody),
                      ),
                    for (final item in action['items'] as List? ?? [])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: assessmentBody),
                            Expanded(
                              child: Text(item as String, style: assessmentBody),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if ((plan['observation_timing'] as String? ?? '').isNotEmpty)
                    Text(plan['observation_timing'] as String, style: assessmentBody),
                ],
              ),
            ),
            if ((comment['sources'] as List? ?? []).isNotEmpty) ...[
              const SizedBox(height: 16),
              AssessmentCard(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Nguồn tham khảo', style: assessmentBody),
                  leading: const Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.primary,
                  ),
                  children: [
                    for (final s in comment['sources'])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s['organization'] as String,
                          style: assessmentBody,
                        ),
                        subtitle: Text(s['title'] as String, style: assessmentMuted),
                        trailing: const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                        ),
                        onTap: () => assessmentOpenLink(context, s['url'] as String),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AssessmentAnswersScreen(
                    attempt: a,
                    isDemo: widget.isDemo,
                  ),
                ),
              ),
              child: const Text('Xem lại đáp án'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Về đánh giá'),
            ),
          ],
        ),
      ),
    );
  }
}

class AssessmentAnswersScreen extends StatelessWidget {
  const AssessmentAnswersScreen({
    super.key,
    required this.attempt,
    required this.isDemo,
  });
  final AssessmentAttempt attempt;
  final bool isDemo;
  @override
  Widget build(BuildContext context) => AssessmentScaffold(
    backgroundColor: AppColors.background,
    appBar: assessmentAppBar('Đáp án · ${attempt.age} tháng'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (isDemo) const AssessmentDemoNote(),
          AssessmentCard(
            featured: true,
            icon: Icons.lock_outline_rounded,
            child: Text(
              attempt.completed ? 'Đáp án và nội dung tại thời điểm làm bài.' : 'Bài dở ở mốc cũ được giữ để xem. Không cần làm bù; hãy làm bài ở mốc hiện tại.',
              style: assessmentMuted,
            ),
          ),
          const SizedBox(height: 16),
          for (final q in attempt.questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AssessmentCard(
                title:
                    q['payload']['question_vi'] ??
                    q['payload']['prompt'] ??
                    'Câu hỏi',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AssessmentDomainLabel(q['domain'] as String?),
                    const SizedBox(height: 10),
                    AssessmentPill(
                      assessmentAnswers[attempt.answers[q['code']]] ??
                          'Chưa trả lời',
                      neutral: !attempt.answers.containsKey(q['code']),
                    ),
                    const SizedBox(height: 12),
                    Text(q['payload']['instruction_vi'] ?? '', style: assessmentBody),
                    ...assessmentMedia(assessmentMap(q['payload'])),
                  ],
                ),
              ),
            ),
          AssessmentCard(
            title: 'Thông tin bổ sung',
            icon: Icons.chat_bubble_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mất kỹ năng: ${switch (attempt.regression) {
                    'yes' => 'Có',
                    'no' => 'Không',
                    'unsure' => 'Chưa chắc',
                    _ => 'Chưa trả lời',
                  }}',
                  style: assessmentBody,
                ),
                Text(
                  'Lo ngại về phát triển: ${switch (attempt.concern) {
                    'yes' => 'Có',
                    'no' => 'Không',
                    _ => 'Chưa trả lời',
                  }}',
                  style: assessmentBody,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
