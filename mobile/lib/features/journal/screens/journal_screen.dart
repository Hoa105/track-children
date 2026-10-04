import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../models/assessment_domain.dart';
import '../../../models/child_share.dart';
import '../../../models/journal_entry.dart';
import '../../../services/active_child.dart';
import '../../../services/service_locator.dart';
import '../../sharing/widgets/sharing_widgets.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final ActiveChildController _active = ServiceLocator.activeChild;
  List<JournalEntry>? _entries;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _active.addListener(_onActiveChanged);
    _load();
  }

  @override
  void dispose() {
    _active.removeListener(_onActiveChanged);
    super.dispose();
  }

  void _onActiveChanged() {
    setState(() => _entries = null);
    _load();
  }

  Future<void> _load() async {
    final active = await _active.ensure();
    if (active == null || !active.canView(ShareSection.journal)) {
      if (mounted) setState(() => _entries = const []);
      return;
    }
    final entries = await ServiceLocator.journalService.getEntries(
      active.child.id,
    );
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  List<JournalEntry> _applyRange(List<JournalEntry> entries) {
    final range = _range;
    if (range == null) return entries;
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    return entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = _entries;
    final entries = allEntries == null ? null : _applyRange(allEntries);
    final active = _active.value;
    final canView = active?.canView(ShareSection.journal) ?? false;
    final canEdit = active?.canEdit(ShareSection.journal) ?? false;
    return AppShellScaffold(
      tab: AppTab.journal,
      appBar: AppBar(
        title: Text(
          active == null
              ? 'Nhật ký phát triển'
              : 'Nhật ký của ${active.shortName}',
        ),
        actions: [
          if (_range != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: 'Bỏ lọc thời gian',
              onPressed: () => setState(() => _range = null),
            ),
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: 'Tra cứu theo thời gian',
            onPressed: _pickRange,
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () async {
                await context.push(AppRoutes.journalAdd);
                _load();
              },
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : !canView
          ? NoAccessView(
              message:
                  'Bạn không có quyền xem nhật ký của ${active?.shortName ?? 'bé'}.',
            )
          : Column(
              children: [
                if (_range != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.surfaceGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_outlined,
                          size: 16,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd/MM/yyyy').format(_range!.start)} - ${DateFormat('dd/MM/yyyy').format(_range!.end)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            _range == null ? 'Chưa có nhật ký nào.' : 'Không có nhật ký nào trong khoảng thời gian đã chọn.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySecondary,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, i) {
                            final entry = entries[i];
                            return CardContainer(
                              onTap: () async {
                                await context.push(
                                  '${AppRoutes.journalDetail}/${entry.id}',
                                );
                                _load();
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: IllustrationPlaceholder(
                                      label: 'ảnh',
                                      height: 56,
                                      icon: Icons.photo_camera_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(entry.date),
                                          style: AppTextStyles.caption,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.note,
                                          style: AppTextStyles.body,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          children: [
                                            for (final d in entry.domains)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: d.color.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  d.label,
                                                  style: AppTextStyles.caption
                                                      .copyWith(color: d.color),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
