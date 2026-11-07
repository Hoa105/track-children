import 'package:flutter/material.dart';

import 'assessment_repository.dart';
import 'assessment_screen.dart';
import 'assessment_widgets.dart';

class AssessmentHomeCard extends StatefulWidget {
  const AssessmentHomeCard({super.key, required this.childId});
  final String childId;
  @override
  State<AssessmentHomeCard> createState() => _AssessmentHomeCardState();
}

class _AssessmentHomeCardState extends State<AssessmentHomeCard> {
  Map<String, dynamic>? state;
  int token = 0;
  late final repo = assessmentRepository();
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
