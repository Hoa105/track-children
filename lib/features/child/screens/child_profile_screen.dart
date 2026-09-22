import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../models/child.dart';
import '../../../services/service_locator.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key, this.isNew = false});

  /// When true, this shows a blank "Thêm hồ sơ bé mới" form (opened in edit
  /// mode immediately, saving calls [ChildService.addChild]) instead of
  /// loading and viewing the first existing child.
  final bool isNew;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  Child? _child;
  bool _editing = false;
  bool _loading = true;

  late TextEditingController _nameCtrl;
  late TextEditingController _weeksCtrl;
  late TextEditingController _weightCtrl;
  ChildGender _gender = ChildGender.boy;
  DateTime _dob = DateTime.now().subtract(const Duration(days: 30));
  bool _premature = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _weeksCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    if (widget.isNew) {
      // Blank profile, already in edit mode — nothing to fetch.
      setState(() {
        _editing = true;
        _loading = false;
      });
    } else {
      ServiceLocator.childService.getChildren().then((children) {
        if (children.isNotEmpty && mounted) {
          _loadChild(children.first);
        }
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  void _loadChild(Child child) {
    setState(() {
      _child = child;
      _nameCtrl.text = child.name;
      _gender = child.gender;
      _dob = child.dob;
      _premature = child.isPremature;
      _weeksCtrl.text = child.gestationalWeeks?.toString() ?? '';
      _weightCtrl.text = child.birthWeightKg?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weeksCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  /// A throwaway [Child] wrapping the in-progress form's dob, only used to
  /// compute "Tuổi hiện tại" while adding a new child (no real [Child]
  /// object exists yet).
  Child _blankChildForAgeLabel() {
    return Child(id: '', name: '', gender: _gender, dob: _dob);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên bé')),
      );
      return;
    }

    if (widget.isNew) {
      await ServiceLocator.childService.addChild(
        Child(
          id: '',
          name: _nameCtrl.text.trim(),
          gender: _gender,
          dob: _dob,
          isPremature: _premature,
          gestationalWeeks: int.tryParse(_weeksCtrl.text),
          birthWeightKg: double.tryParse(_weightCtrl.text),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm hồ sơ bé mới')),
      );
      context.pop(true);
      return;
    }

    final child = _child;
    if (child == null) return;
    final updated = child.copyWith(
      name: _nameCtrl.text,
      gender: _gender,
      dob: _dob,
      isPremature: _premature,
      gestationalWeeks: int.tryParse(_weeksCtrl.text),
      birthWeightKg: double.tryParse(_weightCtrl.text),
    );
    await ServiceLocator.childService.updateChild(updated);
    if (!mounted) return;
    setState(() {
      _child = updated;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    return AppShellScaffold(
      tab: AppTab.home,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.isNew ? 'Thêm hồ sơ bé mới' : 'Hồ sơ bé', style: AppTextStyles.h3),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: _EditPill(
                editing: _editing,
                onTap: () {
                  if (_editing) {
                    _save();
                  } else {
                    setState(() => _editing = true);
                  }
                },
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _AvatarPicker(name: _nameCtrl.text, editable: _editing),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel('Tên bé'),
                  const SizedBox(height: 6),
                  _EditableBox(
                    editing: _editing,
                    controller: _nameCtrl,
                    displayText: child?.name ?? '',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel('Giới tính'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _GenderOption(
                          label: 'Bé trai',
                          selected: _gender == ChildGender.boy,
                          enabled: _editing,
                          onTap: () => setState(() => _gender = ChildGender.boy),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _GenderOption(
                          label: 'Bé gái',
                          selected: _gender == ChildGender.girl,
                          enabled: _editing,
                          onTap: () => setState(() => _gender = ChildGender.girl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Ngày sinh'),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _editing ? _pickDob : null,
                              child: _StaticBox(
                                text:
                                    '${_dob.day.toString().padLeft(2, '0')}/${_dob.month.toString().padLeft(2, '0')}/${_dob.year}',
                                trailingIcon: _editing ? Icons.calendar_today_outlined : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Tuổi hiện tại'),
                            const SizedBox(height: 6),
                            _StaticBox(
                              text: (child ?? _blankChildForAgeLabel()).ageLabel(DateTime.now()),
                              muted: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PrematureSwitchRow(
                    value: _premature,
                    enabled: _editing,
                    onChanged: (v) => setState(() => _premature = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Tuổi thai khi sinh'),
                            const SizedBox(height: 6),
                            _EditableBox(
                              editing: _editing,
                              controller: _weeksCtrl,
                              displayText:
                                  '${child?.gestationalWeeks ?? '—'} tuần',
                              keyboardType: TextInputType.number,
                              suffix: _editing ? 'tuần' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Cân nặng sơ sinh'),
                            const SizedBox(height: 6),
                            _EditableBox(
                              editing: _editing,
                              controller: _weightCtrl,
                              displayText:
                                  '${child?.birthWeightKg ?? '—'} kg',
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              suffix: _editing ? 'kg' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_premature) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.purpleSurfaceLight,
                        border: Border.all(color: AppColors.purpleBorder),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        'Bé sinh non được hiệu chỉnh tuổi khi đối chiếu mốc phát triển.',
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: AppColors.purpleBody,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.bodySecondary);
  }
}

class _EditPill extends StatelessWidget {
  const _EditPill({required this.editing, required this.onTap});

  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          editing ? 'Lưu' : '✎ Sửa',
          style: AppTextStyles.body.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.name, required this.editable});

  final String name;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.surfaceGreen, shape: BoxShape.circle),
      child: Text(
        'Ảnh +',
        style: AppTextStyles.body.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StaticBox extends StatelessWidget {
  const _StaticBox({required this.text, this.trailingIcon, this.muted = false});

  final String text;
  final IconData? trailingIcon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: muted ? AppColors.background : AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(color: muted ? AppColors.textSecondary : AppColors.textPrimary),
            ),
          ),
          if (trailingIcon != null) Icon(trailingIcon, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _EditableBox extends StatelessWidget {
  const _EditableBox({
    required this.editing,
    required this.controller,
    required this.displayText,
    this.keyboardType,
    this.suffix,
  });

  final bool editing;
  final TextEditingController controller;
  final String displayText;
  final TextInputType? keyboardType;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: editing ? 2 : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: editing
          ? TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                suffixText: suffix,
              ),
            )
          : Text(displayText, style: AppTextStyles.body),
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: selected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PrematureSwitchRow extends StatelessWidget {
  const _PrematureSwitchRow({required this.value, required this.enabled, required this.onChanged});

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Sinh non', style: AppTextStyles.body)),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
