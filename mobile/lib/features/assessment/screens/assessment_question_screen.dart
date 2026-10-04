import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../models/assessment_domain.dart';

/// One sample question per domain, verbatim from prototype_reference.md
/// (screens s7..s10 / ids 8a..8d). The real app would have many questions
/// per domain group; this app shows the prototype's single example per
/// domain and advances group→group exactly like the prototype's chain
/// 8a→8b→8c→8d.
class _QuestionData {
  final String question;
  final String? hint;
  final bool hasNotesField;
  const _QuestionData(this.question, {this.hint, this.hasNotesField = false});
}

const _questions = {
  AssessmentDomain.grossMotor:
      _QuestionData('Bé có tự leo lên bậc cầu thang khi được nắm một tay không?'),
  AssessmentDomain.fineMotor: _QuestionData(
    'Bé có xếp được tháp 3 khối gỗ mà không đổ không?',
    hint: 'Gợi ý quan sát: đưa bé 4–5 khối vuông, xem bé có tự xếp chồng lên nhau.',
  ),
  AssessmentDomain.language: _QuestionData(
    'Bé có nói được ít nhất 10 từ đơn mà người thân hiểu được không?',
    hasNotesField: true,
  ),
  AssessmentDomain.socialEmotional:
      _QuestionData('Bé có bắt chước việc nhà của người lớn (quét nhà, lau bàn) không?'),
};

const _domainOrder = [
  AssessmentDomain.grossMotor,
  AssessmentDomain.fineMotor,
  AssessmentDomain.language,
  AssessmentDomain.socialEmotional,
];

class AssessmentQuestionScreen extends StatefulWidget {
  const AssessmentQuestionScreen({super.key, required this.startDomain});
  final AssessmentDomain startDomain;

  @override
  State<AssessmentQuestionScreen> createState() => _AssessmentQuestionScreenState();
}

class _AssessmentQuestionScreenState extends State<AssessmentQuestionScreen> {
  late int _index;
  int? _selectedOption; // 0=Có, 1=Chưa, 2=Chưa chắc
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _index = _domainOrder.indexOf(widget.startDomain);
    if (_index < 0) _index = 0;
  }

  void _continue() {
    final isLast = _index == _domainOrder.length - 1;
    if (isLast) {
      context.push(AppRoutes.assessmentResult);
    } else {
      setState(() {
        _index++;
        _selectedOption = null;
        _notesCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final domain = _domainOrder[_index];
    final q = _questions[domain]!;
    final isLast = _index == _domainOrder.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text('Câu hỏi · ${domain.label}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppProgressBar(value: (_index + 1) / _domainOrder.length, color: AppColors.purple),
              const SizedBox(height: AppSpacing.md),
              Text('Nhóm ${_index + 1}/${_domainOrder.length}', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.lg),
              IllustrationPlaceholder(
                label: 'minh họa · ${domain.label}',
                color: AppColors.purpleSurface,
                icon: domain.icon,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(q.question, style: AppTextStyles.h3),
              if (q.hint != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(q.hint!, style: AppTextStyles.caption),
              ],
              const SizedBox(height: AppSpacing.lg),
              _option(0, 'Có, bé làm được'),
              const SizedBox(height: AppSpacing.sm),
              _option(1, 'Chưa'),
              const SizedBox(height: AppSpacing.sm),
              _option(2, 'Chưa chắc'),
              if (q.hasNotesField) ...[
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Ghi chú thêm cho bác sĩ (không bắt buộc)',
                  ),
                ),
              ],
              const Spacer(),
              if (isLast)
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Lưu tạm',
                        onPressed: () => context.go(AppRoutes.home),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Xem kết quả',
                        color: AppColors.purple,
                        onPressed: _selectedOption == null ? null : _continue,
                      ),
                    ),
                  ],
                )
              else
                PrimaryButton(
                  label: 'Tiếp tục',
                  color: AppColors.purple,
                  onPressed: _selectedOption == null ? null : _continue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(int value, String label) {
    final selected = _selectedOption == value;
    return InkWell(
      onTap: () => setState(() => _selectedOption = value),
      borderRadius: AppRadius.smallRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.purpleSurface : AppColors.surface,
          border: Border.all(color: selected ? AppColors.purple : AppColors.border),
          borderRadius: AppRadius.smallRadius,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? AppColors.purple : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}
