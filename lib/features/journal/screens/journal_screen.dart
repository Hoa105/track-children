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
import '../../../models/journal_entry.dart';
import '../../../services/service_locator.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<JournalEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ServiceLocator.journalService.getEntries('c1');
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return AppShellScaffold(
      tab: AppTab.journal,
      appBar: AppBar(title: const Text('Nhật ký phát triển')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await context.push(AppRoutes.journalAdd);
          _load();
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? Center(child: Text('Chưa có nhật ký nào.', style: AppTextStyles.bodySecondary))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    return CardContainer(
                      onTap: () async {
                        await context.push('${AppRoutes.journalDetail}/${entry.id}');
                        _load();
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 56,
                            height: 56,
                            child: IllustrationPlaceholder(label: 'ảnh', height: 56, icon: Icons.photo_camera_outlined),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('dd/MM/yyyy').format(entry.date), style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text(entry.note, style: AppTextStyles.body),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    for (final d in entry.domains)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: d.color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(d.label, style: AppTextStyles.caption.copyWith(color: d.color)),
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
    );
  }
}
