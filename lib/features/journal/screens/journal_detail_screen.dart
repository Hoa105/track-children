import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../models/assessment_domain.dart';
import '../../../models/journal_entry.dart';
import '../../../services/service_locator.dart';

/// Read-only view of a journal entry that flips into an inline editable
/// form when the app bar's edit icon is tapped — mirrors the field set and
/// widgets already used by [journal_add_screen.dart] (JournalAddScreen) so
/// editing an entry looks and behaves the same as creating one.
class JournalDetailScreen extends StatefulWidget {
  const JournalDetailScreen({super.key, required this.entryId});
  final String entryId;

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  JournalEntry? _entry;
  bool _editing = false;

  JournalMood _mood = JournalMood.happy;
  final Set<AssessmentDomain> _domains = {};
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await ServiceLocator.journalService.getEntries('c1');
    final entry = entries.firstWhere((e) => e.id == widget.entryId);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _mood = entry.mood;
      _domains
        ..clear()
        ..addAll(entry.domains);
      _noteCtrl.text = entry.note;
      _date = entry.date;
    });
  }

  Future<void> _save() async {
    final entry = _entry;
    if (entry == null) return;
    final updated = entry.copyWith(
      mood: _mood,
      domains: _domains.toList(),
      note: _noteCtrl.text,
      date: _date,
    );
    await ServiceLocator.journalService.updateEntry(updated);
    if (!mounted) return;
    setState(() {
      _entry = updated;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thay đổi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Sửa nhật ký' : 'Chi tiết nhật ký'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined),
            tooltip: _editing ? 'Lưu' : 'Sửa',
            onPressed: () {
              if (_editing) {
                _save();
              } else {
                setState(() => _editing = true);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.photoPath != null) ...[
                const IllustrationPlaceholder(label: 'ảnh đã chọn', height: 140),
                const SizedBox(height: AppSpacing.xl),
              ],
              Text('Cảm xúc của bé', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final mood in JournalMood.values)
                    AppChip(
                      label: mood.label,
                      selected: _mood == mood,
                      onTap: _editing ? () => setState(() => _mood = mood) : null,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Lĩnh vực liên quan', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final domain in AssessmentDomain.values)
                    AppChip(
                      label: domain.label,
                      selected: _domains.contains(domain),
                      color: domain.color,
                      onTap: _editing
                          ? () => setState(() {
                                if (_domains.contains(domain)) {
                                  _domains.remove(domain);
                                } else {
                                  _domains.add(domain);
                                }
                              })
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'Ghi chú',
                hint: 'Hôm nay bé đã làm gì?',
                controller: _noteCtrl,
                maxLines: 4,
                enabled: _editing,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Ngày', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 6),
              InkWell(
                onTap: !_editing
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _editing ? null : AppColors.background,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(_date), style: AppTextStyles.body),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
