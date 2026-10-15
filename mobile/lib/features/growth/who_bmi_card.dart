import '../../services/demo_store.dart';

import 'package:flutter/material.dart';

import '../child/child_profile_screen.dart';

import '../../app_colors.dart';
import '../../services/who_bmi_reference.dart';

class WhoBmiCard extends StatefulWidget {
  const WhoBmiCard({
    this.previewAnchor,
    this.measurementLabel,
    this.childId,
    this.compact = false,
    this.onProfileChanged,
    required this.childName,
    required this.preview,
    required this.measured,
    required this.bmi,
    super.key,
  });
  final String childName;
  final String? measurementLabel;
  final DateTime? previewAnchor;
  final String? childId;
  final bool compact;
  final VoidCallback? onProfileChanged;
  final bool preview;
  final DateTime? measured;
  final double? bmi;
  @override
  State<WhoBmiCard> createState() => _WhoBmiCardState();
}

class _WhoBmiCardState extends State<WhoBmiCard> {
  WhoBmiReference? _reference;
  String? _sex;
  DateTime? _birth;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _readProfile();
    DemoStore.instance.addListener(_profileChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant WhoBmiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) _readProfile();
  }

  @override
  void dispose() {
    DemoStore.instance.removeListener(_profileChanged);
    super.dispose();
  }

  void _readProfile() {
    final child = widget.childId == null
        ? null
        : DemoStore.instance.childById(widget.childId!);
    _sex = switch (child?['gender']) {
      'male' => 'boys',
      'female' => 'girls',
      _ => null,
    };
    _birth = DateTime.tryParse(child?['date_of_birth']?.toString() ?? '');
    if (_birth != null && _birth!.isAfter(DateTime.now())) _birth = null;
  }

  void _profileChanged() {
    if (mounted) setState(_readProfile);
  }

  Future<void> _load() async {
    try {
      final reference = await WhoBmiReference.load();
      if (mounted) setState(() => _reference = reference);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openProfile() async {
    final child = widget.childId == null
        ? null
        : DemoStore.instance.childById(widget.childId!);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChildProfileScreen(
          initialFields: child,
          onSave: child == null
              ? null
              : (fields, avatar) => DemoStore.instance
                    .saveChild(child['id'] as String, fields)
                    .then((_) {}),
        ),
      ),
    );
    if (!mounted) return;
    setState(_readProfile);
    widget.onProfileChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Preview always uses a separate, explicit example rather than real metadata.
    final sex = widget.preview ? 'boys' : _sex;
    final anchor = widget.previewAnchor;
    final previewBirth = anchor == null
        ? null
        : DateTime(
            anchor.year,
            anchor.month - 8,
            anchor.day.clamp(1, DateTime(anchor.year, anchor.month - 7, 0).day),
          );
    final months = widget.preview
        ? previewBirth == null || widget.measured == null
              ? 8
              : WhoBmiReference.ageMonths(previewBirth, widget.measured!)
        : _birth == null || widget.measured == null
        ? null
        : WhoBmiReference.ageMonths(_birth!, widget.measured!);
    final row = sex == null || months == null
        ? null
        : _reference?.row(sex, months);
    final missingProfile = !widget.preview && (_sex == null || _birth == null);
    final summary =
        '${widget.preview ? 'Ví dụ mẫu · ' : ''}Chuẩn WHO'
        '${sex == null ? '' : ' · ${sex == 'boys' ? 'Bé trai' : 'Bé gái'}'}'
        '${months == null ? '' : ' · $months tháng tại ngày đo'}';
    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (missingProfile)
            TextButton.icon(
              onPressed: _openProfile,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
              label: const Text('Bổ sung hồ sơ'),
            ),
        ],
      );
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFECEEE8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đối chiếu BMI',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summary,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (_failed)
              const Text('Chưa tải được bảng chuẩn WHO. Hãy mở lại màn hình.')
            else if (_reference == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              )
            else if (row == null)
              Text(
                months == null || sex == null
                    ? 'Chưa có khoảng tham chiếu'
                    : 'Tuổi tại ngày đo nằm ngoài bảng 0–60 tháng.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              )
            else ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BMI của bé',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.bmi?.toStringAsFixed(1) ?? '—'} kg/m²',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trung vị tham chiếu',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${row[7].toStringAsFixed(1)} kg/m²',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBB7435),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.measurementLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.measurementLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  expansionAnimationStyle:
                      MediaQuery.disableAnimationsOf(context)
                      ? AnimationStyle.noAnimation
                      : null,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text(
                    'Xem các mốc tham chiếu',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    for (var i = 4; i <= 10; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              i == 7
                                  ? 'Trung vị'
                                  : '${i - 7 > 0 ? '+' : ''}${i - 7} SD',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${row[i].toStringAsFixed(1)} kg/m²',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nguồn: WHO Child Growth Standards · BMI-for-age, 0–5 tuổi. Các mốc tham chiếu không thay thế đánh giá của nhân viên y tế.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (missingProfile)
              TextButton.icon(
                onPressed: _openProfile,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text(
                  'Bổ sung hồ sơ',
                  style: TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
