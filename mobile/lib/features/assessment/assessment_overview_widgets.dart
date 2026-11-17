import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'assessment_models.dart';
import 'assessment_widgets.dart';

class AssessmentTabs extends StatelessWidget {
  const AssessmentTabs({
    super.key,
    required this.history,
    required this.onChanged,
  });
  final bool history;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primarySoft,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (value, label) in [(false, 'Đánh giá'), (true, 'Lịch sử')])
            Expanded(
              child: Semantics(
                selected: history == value,
                button: true,
                child: Material(
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  color: history == value
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: history == value
                                    ? Colors.white
                                    : AppColors.primaryDark,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class AssessmentMilestones extends StatefulWidget {
  const AssessmentMilestones({
    super.key,
    required this.milestones,
    required this.today,
    required this.currentAge,
    required this.completed,
    required this.draftAge,
    required this.onHistory,
  });
  final List<Map<String, dynamic>> milestones;
  final DateTime today;
  final int? currentAge, draftAge;
  final Set<int> completed;
  final ValueChanged<int> onHistory;
  @override
  State<AssessmentMilestones> createState() => _AssessmentMilestonesState();
}

class _AssessmentMilestonesState extends State<AssessmentMilestones> {
  int? selected;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() => selected =
      widget.milestones.any((m) => m['age_months'] == widget.currentAge)
      ? widget.currentAge
      : widget.milestones.firstOrNull?['age_months'] as int?;
  @override
  void didUpdateWidget(AssessmentMilestones old) {
    super.didUpdateWidget(old);
    if (old.currentAge != widget.currentAge ||
        !widget.milestones.any((m) => m['age_months'] == selected)) {
      _reset();
    }
  }

  bool _future(Map<String, dynamic> m) =>
      widget.today.isBefore(DateTime.parse(m['opens_on'].toString()));
  bool _closed(Map<String, dynamic> m) =>
      !widget.today.isBefore(DateTime.parse(m['closes_on'].toString()));
  String _status(Map<String, dynamic> m) {
    final age = m['age_months'];
    return _future(m)
        ? 'Chưa đến'
        : widget.completed.contains(age)
        ? 'Đã hoàn thành'
        : widget.draftAge == age
        ? 'Đang làm'
        : _closed(m)
        ? 'Chưa đánh giá'
        : 'Chưa làm';
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.milestones
        .where((m) => m['age_months'] == selected)
        .firstOrNull;
    return AssessmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in widget.milestones)
                Semantics(
                  selected: selected == m['age_months'],
                  button: true,
                  label:
                      '${m['age_months']} tháng, ${_status(m)}${m['age_months'] == widget.currentAge ? ', mốc hiện tại' : ''}',
                  child: AssessmentPress(
                    child: Material(
                      color: selected == m['age_months']
                          ? AppColors.primary
                          : AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selected == m['age_months']
                              ? AppColors.primary
                              : m['age_months'] == widget.currentAge
                              ? AppColors.primary.withValues(alpha: .5)
                              : AppColors.border,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            setState(() => selected = m['age_months'] as int),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.completed.contains(
                                m['age_months'],
                              )) ...[
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 17,
                                  color: selected == m['age_months']
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                '${m['age_months']} tháng',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: selected == m['age_months']
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Mốc $selected tháng',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (selected == widget.currentAge) const AssessmentPill('Hiện tại'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_status(detail)} · Đến mốc ${assessmentDate(detail['opens_on'])}',
              style: assessmentMuted,
            ),
            if (widget.completed.contains(selected)) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => widget.onHistory(selected!),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Xem lịch sử'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class AssessmentAgeFilter extends StatelessWidget {
  const AssessmentAgeFilter({
    super.key,
    required this.age,
    required this.onChanged,
  });
  final int? age;
  final ValueChanged<int?> onChanged;
  Future<void> _open(BuildContext context) async {
    final choice = await showModalBottomSheet<({int? age})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (ctx) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lọc mốc tuổi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng bộ lọc',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: assessmentAges.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final value = index == 0
                        ? null
                        : assessmentAges[index - 1];
                    final selected = value == age;
                    return Material(
                      color: selected
                          ? AppColors.primarySoft
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        selected: selected,
                        selectedColor: AppColors.primaryDark,
                        title: Text(
                          value == null ? 'Tất cả mốc tuổi' : '$value tháng',
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        onTap: () => Navigator.pop(ctx, (age: value)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && context.mounted && choice.age != age) {
      onChanged(choice.age);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const AssessmentIconBadge(Icons.tune_rounded, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mốc tuổi', style: assessmentMuted),
                  const SizedBox(height: 2),
                  Text(
                    age == null ? 'Tất cả mốc tuổi' : '$age tháng',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}
