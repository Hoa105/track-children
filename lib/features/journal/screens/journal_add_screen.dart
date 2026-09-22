import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/assessment_domain.dart';
import '../../../models/journal_entry.dart';
import '../../../services/service_locator.dart';

class JournalAddScreen extends StatefulWidget {
  const JournalAddScreen({super.key});

  @override
  State<JournalAddScreen> createState() => _JournalAddScreenState();
}

class _JournalAddScreenState extends State<JournalAddScreen> {
  bool _hasPhoto = false;
  JournalMood _mood = JournalMood.happy;
  final Set<AssessmentDomain> _domains = {};
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  Future<void> _save() async {
    await ServiceLocator.journalService.addEntry(JournalEntry(
      id: 'j${DateTime.now().microsecondsSinceEpoch}',
      childId: 'c1',
      date: _date,
      mood: _mood,
      domains: _domains.toList(),
      note: _noteCtrl.text,
    ));
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm nhật ký'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Hủy')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasPhoto)
                Stack(
                  children: [
                    const IllustrationPlaceholder(label: 'ảnh đã chọn', height: 140),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _hasPhoto = false),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.surface,
                          child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _hasPhoto = true),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Chụp ảnh'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _hasPhoto = true),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Thư viện'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              Text('Cảm xúc của bé', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final mood in JournalMood.values)
                    AppChip(label: mood.label, selected: _mood == mood, onTap: () => setState(() => _mood = mood)),
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
                      onTap: () => setState(() {
                        if (_domains.contains(domain)) {
                          _domains.remove(domain);
                        } else {
                          _domains.add(domain);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(label: 'Ghi chú', hint: 'Hôm nay bé đã làm gì?', controller: _noteCtrl, maxLines: 4),
              const SizedBox(height: AppSpacing.lg),
              Text('Ngày', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
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
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(label: 'Lưu nhật ký', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
