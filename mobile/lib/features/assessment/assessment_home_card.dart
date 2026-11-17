import 'package:flutter/material.dart';

import '../../app_colors.dart';

import 'assessment_repository.dart';
import 'assessment_screen.dart';
import 'assessment_widgets.dart';

class AssessmentHomeCard extends StatefulWidget {
  const AssessmentHomeCard({
    super.key,
    required this.childId,
    this.reminderOnly = false,
    this.repository,
  });
  final String childId;
  final bool reminderOnly;
  final AssessmentRepository? repository;
  @override
  State<AssessmentHomeCard> createState() => _AssessmentHomeCardState();
}

class _AssessmentHomeCardState extends State<AssessmentHomeCard> {
  Map<String, dynamic>? state;
  int token = 0;
  late final repo = widget.repository ?? assessmentRepository();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AssessmentHomeCard old) {
    super.didUpdateWidget(old);
    if (old.childId != widget.childId) _load();
  }

  Future<void> _load() async {
    final current = ++token;
    state = null;
    try {
      final value = await repo.overview(widget.childId);
      if (mounted && current == token) setState(() => state = value);
    } catch (_) {
      if (mounted && current == token) setState(() => state = null);
    }
  }

  Future<void> _open({bool history = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AssessmentScreen(
          childId: widget.childId,
          initialHistory: history,
          repository: repo,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final age = state?['age_months'];
    if (widget.reminderOnly) {
      if (age == null ||
          state?['set'] == null ||
          state?['latest_completed'] != null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Material(
          key: const ValueKey('home-assessment-reminder'),
          color: HomeColors.reminderBackground,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Image.asset(
                    'assets/photobooth/stickers/belonkhon/mascot/take_test.png',
                    width: 62,
                    height: 80,
                    // Fill the existing slot by cropping transparent side margins.
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đến lịch đánh giá phát triển',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: HomeColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Giúp ba mẹ sớm nhận biết những kỹ năng bé cần hỗ trợ.',
                          style: TextStyle(fontSize: 12, color: HomeColors.ink),
                        ),
                        TextButton(
                          onPressed: _open,
                          style: TextButton.styleFrom(
                            foregroundColor: HomeColors.reminderCta,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size(48, 48),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state?['draft'] != null
                                    ? 'Tiếp tục đánh giá'
                                    : 'Đánh giá ngay',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (state?['draft'] == null) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return AssessmentCard(
      title: 'Đánh giá phát triển',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            age == null
                ? 'Theo dõi kỹ năng của bé theo từng mốc tuổi.'
                : 'Mốc $age tháng · ${state?['draft'] == null ? 'Cùng nhìn lại kỹ năng của bé' : 'Đã trả lời ${(state!['draft']['answers'] as Map).length}/${(state!['draft']['questions'] as List).length} câu'}',
            style: assessmentBody,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _open,
            child: Text(
              state?['draft'] != null
                  ? 'Tiếp tục đánh giá'
                  : state?['latest_completed'] != null
                  ? 'Xem kết quả'
                  : 'Xem mốc đánh giá',
            ),
          ),
          TextButton(
            onPressed: () => _open(history: true),
            child: const Text('Lịch sử đánh giá'),
          ),
        ],
      ),
    );
  }
}
