import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../models/child.dart';
import '../../../models/tooth.dart';
import '../../../services/service_locator.dart';
import '../widgets/tooth_actions.dart';
import '../widgets/vaccine_widgets.dart';

/// Erupted teeth of one child, newest first, each editable via the pencil icon.
class ToothListScreen extends StatefulWidget {
  const ToothListScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ToothListScreen> createState() => _ToothListScreenState();
}

class _ToothListScreenState extends State<ToothListScreen> {
  Child? _child;
  Map<String, ToothRecord>? _records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final child = _child ??
        (await ServiceLocator.childService.getChildren()).firstWhere((c) => c.id == widget.childId);
    final records = await ServiceLocator.teethingService.getRecords(child);
    if (!mounted) return;
    setState(() {
      _child = child;
      _records = records;
    });
  }

  Future<void> _edit(PrimaryTooth tooth) async {
    if (await showToothActions(context, child: _child!, tooth: tooth, record: _records?[tooth.id])) _load();
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final teeth = records == null
        ? const <PrimaryTooth>[]
        : (PrimaryTooth.all.where((t) => records.containsKey(t.id)).toList()
          ..sort((a, b) => records[b.id]!.eruptedDate.compareTo(records[a.id]!.eruptedDate)));

    return Scaffold(
      appBar: AppBar(title: Text(records == null ? 'Răng đã mọc' : 'Răng đã mọc (${teeth.length}/${PrimaryTooth.all.length})')),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : teeth.isEmpty
              ? Center(child: Text('Bé chưa mọc răng nào.', style: AppTextStyles.bodySecondary))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: teeth.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final t = teeth[i];
                    return CardContainer(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.label, style: AppTextStyles.body),
                                Text(
                                  'Mọc ngày ${vaccineDateFormat.format(records[t.id]!.eruptedDate)} · thường ${t.eruptionLabel}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                            tooltip: 'Sửa',
                            onPressed: () => _edit(t),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
