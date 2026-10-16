import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../../services/demo_store.dart';
import '../sharing/child_sharing_screen.dart';

/// UI boundary: the host uploads [avatar] and persists the database fields.
typedef SaveChildProfile = Future<void> Function(
  Map<String, Object?> fields,
  XFile? avatar,
);

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({
    super.key,
    this.initialFields,
    this.onSave,
    this.onOpenHomePreview,
    this.members = const [],
    this.pendingInvitations = 0,
  });

  final Map<String, Object?>? initialFields;
  final SaveChildProfile? onSave;
  final ValueChanged<String>? onOpenHomePreview;
  final List<SharingMember> members;
  final int pendingInvitations;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _weeks;
  late final TextEditingController _weight;
  late bool _editing;
  bool _saving = false;
  bool _attempted = false;
  bool _preview = false;
  bool _created = false;
  late bool _premature;
  String? _gender;
  DateTime? _birth;
  XFile? _avatar;
  Uint8List? _avatarBytes;
  late final List<SharingMember> _members;
  late final List<String> _pending;

  @override
  void initState() {
    super.initState();
    _members = widget.initialFields?['id'] != null
        ? demoSharingMembers(widget.initialFields!['id'] as String)
        : List.of(widget.members);
    _pending = List.generate(
      widget.pendingInvitations,
      (_) => 'Lời mời đang chờ',
    );
    if (widget.initialFields?['id'] != null) {
      _pending.clear();
      _pending.addAll(
        List<String>.from(
          DemoStore.instance.childById(
                    widget.initialFields!['id'] as String,
                  )?['pending']
                  as List? ??
              [],
        ),
      );
    }
    final fields = widget.initialFields ?? {};
    if (fields['avatar_base64'] != null) {
      _avatarBytes = base64Decode(fields['avatar_base64'] as String);
    }
    _editing = widget.initialFields == null;
    _name = TextEditingController(text: fields['full_name'] as String?);
    _weeks = TextEditingController(
      text: fields['gestational_weeks']?.toString(),
    );
    _weight = TextEditingController(
      text: fields['birth_weight_kg']?.toString(),
    );
    _gender = fields['gender'] as String?;
    _birth = DateTime.tryParse(fields['date_of_birth']?.toString() ?? '');
    _premature = (int.tryParse(_weeks.text) ?? 40) < 37;
  }

  @override
  void dispose() {
    _name.dispose();
    _weeks.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _avatar = file;
          _avatarBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Không thể mở ảnh. Vui lòng kiểm tra quyền truy cập và thử lại.',
        );
      }
    }
  }

  Future<void> _chooseDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate:
          _birth == null ||
              _birth!.isBefore(DateTime(2000)) ||
              _birth!.isAfter(today)
          ? today
          : _birth!,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'Chọn ngày sinh của bé',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (date != null && mounted) setState(() => _birth = date);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    if (!_form.currentState!.validate() || _birth == null || _gender == null) {
      return;
    }
    final fields = <String, Object?>{
      'full_name': _name.text.trim(),
      'gender': _gender,
      'date_of_birth':
          '${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}',
      'gestational_weeks': int.tryParse(_weeks.text),
      'birth_weight_kg': double.tryParse(_weight.text.replaceAll(',', '.')),
      'avatar_url': widget.initialFields?['avatar_url'],
      if (_avatarBytes != null) 'avatar_base64': base64Encode(_avatarBytes!),
    };
    if (widget.onSave == null) {
      setState(() => _preview = true);
      _message('Đây là bản xem trước. Hồ sơ bé chưa được lưu.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave!(fields, _avatar);
      if (mounted) {
        setState(() {
          _editing = false;
          _created = true;
        });
        _message('Đã lưu hồ sơ bé.');
      }
    } catch (_) {
      if (mounted) _message('Chưa lưu được hồ sơ. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _age {
    if (_birth == null) return 'Chọn ngày sinh để tính tuổi';
    final today = DateUtils.dateOnly(DateTime.now());
    var months = (today.year - _birth!.year) * 12 + today.month - _birth!.month;
    DateTime anchor(int count) {
      final first = DateTime(_birth!.year, _birth!.month + count);
      final lastDay = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(first.year, first.month, _birth!.day.clamp(1, lastDay));
    }

    if (anchor(months).isAfter(today)) months--;
    return '$months tháng ${today.difference(anchor(months)).inDays} ngày';
  }

  InputDecoration _decoration({
    String? hint,
    String? suffix,
    bool muted = false,
  }) => InputDecoration(
    hintText: hint,
    suffixText: suffix,
    filled: true,
    fillColor: muted ? AppColors.background : AppColors.surface,
    contentPadding: const EdgeInsets.all(AppLayout.pagePadding),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppLayout.smallGap),
        child,
      ],
    ),
  );

  Widget _profileOverview(String? avatarUrl) {
    final birth = _birth == null
        ? 'Chưa cập nhật'
        : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}';
    final missing =
        _birth == null || _gender == null || _name.text.trim().isEmpty;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 380),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primarySoft, AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.surface),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .07),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _AvatarPicker(bytes: _avatarBytes, url: avatarUrl),
                const SizedBox(height: 16),
                Text(
                  _name.text.trim().isEmpty ? 'Bé yêu' : _name.text.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _age,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                _detailRow(Icons.cake_outlined, 'Ngày sinh', birth),
                const Divider(height: 24),
                _detailRow(
                  Icons.child_care_outlined,
                  'Giới tính',
                  _gender == 'male'
                      ? 'Bé trai'
                      : _gender == 'female'
                      ? 'Bé gái'
                      : 'Chưa cập nhật',
                ),
              ],
            ),
          ),
          if (missing) ...[
            const SizedBox(height: 16),
            _notice(
              Icons.edit_note_rounded,
              'Hoàn thiện hồ sơ bé',
              'Bổ sung tên, ngày sinh và giới tính để theo dõi bé đầy đủ hơn.',
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Thông tin lúc sinh',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _detailRow(
                  Icons.monitor_weight_outlined,
                  'Cân nặng sơ sinh',
                  _weight.text.isEmpty
                      ? 'Chưa cập nhật'
                      : '${_weight.text.replaceAll('.', ',')} kg',
                ),
                const Divider(height: 28),
                _detailRow(
                  Icons.calendar_month_outlined,
                  'Tuổi thai khi sinh',
                  _weeks.text.isEmpty ? 'Chưa cập nhật' : '${_weeks.text} tuần',
                ),
              ],
            ),
          ),
          if (_premature) ...[
            const SizedBox(height: 12),
            _notice(
              Icons.auto_awesome_outlined,
              'Lưu ý tuổi hiệu chỉnh',
              'Bé sinh non được hiệu chỉnh tuổi khi đối chiếu mốc phát triển.',
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: AppColors.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _notice(IconData icon, String title, String description) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.purpleSurfaceLight,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.purpleText.withValues(alpha: .18)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.purpleText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purpleText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.purpleText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final editable = _editing && !_saving;
    final avatarUrl = widget.initialFields?['avatar_url'] as String?;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppLayout.smallGap),
              child: Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: Text(
                      widget.initialFields == null && !_created
                          ? 'Thêm hồ sơ bé mới'
                          : 'Hồ sơ bé',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _EditPill(
                    editing: _editing,
                    saving: _saving,
                    onPressed: _saving
                        ? null
                        : () {
                            if (_editing) {
                              _save();
                            } else {
                              setState(() => _editing = true);
                            }
                          },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppLayout.pagePadding),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_editing) _profileOverview(avatarUrl),
                      if (_editing) ...[
                        _AvatarPicker(
                          bytes: _avatarBytes,
                          url: avatarUrl,
                          onPick: editable ? _pickAvatar : null,
                        ),
                        const SizedBox(height: AppLayout.sectionGap),
                        _field(
                          'Tên bé',
                          TextFormField(
                            controller: _name,
                            readOnly: !editable,
                            maxLength: 150,
                            textCapitalization: TextCapitalization.words,
                            decoration: _decoration(hint: 'Nhập tên bé')
                                .copyWith(counterText: ''),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Vui lòng nhập tên bé.'
                                : null,
                          ),
                        ),
                        _field(
                          'Giới tính',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  for (final item in [
                                    ('male', 'Bé trai', Icons.male),
                                    ('female', 'Bé gái', Icons.female),
                                  ]) ...[
                                    if (item.$1 == 'female')
                                      const SizedBox(width: AppLayout.smallGap),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: editable
                                            ? () => setState(
                                                () => _gender = item.$1,
                                              )
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(
                                            0,
                                            AppLayout.minimumTouchTarget,
                                          ),
                                          backgroundColor: _gender == item.$1
                                              ? AppColors.primarySoft
                                              : AppColors.surface,
                                          foregroundColor: AppColors.primary,
                                          disabledForegroundColor:
                                              _gender == item.$1
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          side: BorderSide(
                                            color: _gender == item.$1
                                                ? AppColors.primary
                                                : AppColors.border,
                                          ),
                                        ),
                                        icon: Icon(
                                          _gender == item.$1
                                              ? Icons.check_circle_outline
                                              : item.$3,
                                        ),
                                        label: Text(item.$2),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (_attempted && _gender == null)
                                Text(
                                  'Vui lòng chọn giới tính.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _field(
                          'Ngày sinh',
                          InkWell(
                            onTap: editable ? _chooseDate : null,
                            borderRadius: BorderRadius.circular(
                              AppLayout.homeCareRadius,
                            ),
                            child: InputDecorator(
                              decoration: _decoration().copyWith(
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                errorText: _attempted && _birth == null
                                    ? 'Vui lòng chọn ngày sinh.'
                                    : null,
                              ),
                              child: Text(
                                _birth == null
                                    ? 'Chọn ngày sinh'
                                    : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}',
                              ),
                            ),
                          ),
                        ),
                        _field(
                          'Tuổi hiện tại',
                          InputDecorator(
                            decoration: _decoration(muted: true),
                            child: Text(_age),
                          ),
                        ),
                        _PrematureSwitchRow(
                          value: _premature,
                          onChanged: editable
                              ? (value) => setState(() {
                                  _premature = value;
                                  _weeks.text = value ? '36' : '40';
                                })
                              : null,
                        ),
                        if (_premature)
                          Container(
                            margin: const EdgeInsets.only(
                              top: AppLayout.smallGap,
                            ),
                            padding: const EdgeInsets.all(AppLayout.mediumGap),
                            decoration: BoxDecoration(
                              color: AppColors.purpleSurfaceLight,
                              borderRadius: BorderRadius.circular(
                                AppLayout.homeCareRadius,
                              ),
                            ),
                            child: const Text(
                              'Bé sinh non được hiệu chỉnh tuổi khi đối chiếu mốc phát triển.',
                              style: TextStyle(color: AppColors.purpleText),
                            ),
                          ),
                        const SizedBox(height: AppLayout.sectionGap),
                        _field(
                          'Tuổi thai khi sinh',
                          TextFormField(
                            controller: _weeks,
                            readOnly: !editable,
                            keyboardType: TextInputType.number,
                            decoration: _decoration(
                              hint: 'Ví dụ: 36',
                              suffix: 'tuần',
                            ),
                            onChanged: (text) {
                              final weeks = int.tryParse(text);
                              if (weeks != null) {
                                setState(() => _premature = weeks < 37);
                              }
                            },
                            validator: (text) {
                              if (text == null || text.isEmpty) {
                                return _premature
                                    ? 'Nhập tuổi thai khi sinh.'
                                    : null;
                              }
                              final weeks = int.tryParse(text);
                              return weeks == null || weeks < 22 || weeks > 45
                                  ? 'Tuổi thai từ 22 đến 45 tuần.'
                                  : null;
                            },
                          ),
                        ),
                        _field(
                          'Cân nặng sơ sinh',
                          TextFormField(
                            controller: _weight,
                            readOnly: !editable,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _decoration(
                              hint: 'Ví dụ: 2,8',
                              suffix: 'kg',
                            ),
                            validator: (text) {
                              if (text == null || text.isEmpty) return null;
                              final weight = double.tryParse(
                                text.replaceAll(',', '.'),
                              );
                              return weight == null ||
                                      !weight.isFinite ||
                                      weight <= 0 ||
                                      weight > 99.99 ||
                                      !RegExp(r'^\d+([.,]\d{1,2})?$')
                                          .hasMatch(text)
                                  ? 'Nhập cân nặng hợp lệ, tối đa 2 số thập phân.'
                                  : null;
                            },
                          ),
                        ),
                      ],
                      if (!_editing &&
                          (widget.initialFields != null || _created))
                        _SharingCard(
                          members: _members,
                          pending: _pending.length,
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ChildSharingScreen(
                                  childId:
                                      widget.initialFields?['id'] as String?,
                                  members: _members,
                                  pending: _pending,
                                ),
                              ),
                            );
                            if (mounted) {
                              setState(() {
                                final id =
                                    widget.initialFields?['id'] as String?;
                                if (id != null) {
                                  _members
                                    ..clear()
                                    ..addAll(demoSharingMembers(id));
                                  _pending
                                    ..clear()
                                    ..addAll(
                                      List<String>.from(
                                        DemoStore.instance.childById(
                                                  id,
                                                )?['pending']
                                                as List? ??
                                            [],
                                      ),
                                    );
                                }
                              });
                            }
                          },
                        ),
                      if (_preview && widget.onOpenHomePreview != null)
                        TextButton.icon(
                          onPressed: () =>
                              widget.onOpenHomePreview!(_name.text.trim()),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Xem trang chủ'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPill extends StatelessWidget {
  const _EditPill({
    required this.editing,
    required this.saving,
    required this.onPressed,
  });
  final bool editing;
  final bool saving;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(44, 42),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(editing ? Icons.check_rounded : Icons.edit_outlined, size: 21),
        const SizedBox(width: 5),
        Text(
          saving
              ? 'Đang lưu…'
              : editing
              ? 'Lưu'
              : 'Sửa',
        ),
      ],
    ),
  );
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({this.bytes, this.url, this.onPick});
  final Uint8List? bytes;
  final String? url;
  final VoidCallback? onPick;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: 'Ảnh đại diện của bé',
        child: ClipOval(
          child: SizedBox.square(
            dimension: AppLayout.childAvatarSize,
            child: ColoredBox(
              color: AppColors.primarySoft,
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : url != null && url!.isNotEmpty
                  ? Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => const Icon(
                        Icons.child_care,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.child_care,
                      size: AppLayout.minimumTouchTarget,
                      color: AppColors.primary,
                    ),
            ),
          ),
        ),
      ),
      if (onPick != null)
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Ảnh +'),
        ),
    ],
  );
}

class _PrematureSwitchRow extends StatelessWidget {
  const _PrematureSwitchRow({required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: const Text('Sinh non'),
    value: value,
    activeTrackColor: AppColors.primary,
    onChanged: onChanged,
  );
}

class _SharingCard extends StatelessWidget {
  const _SharingCard({
    required this.members,
    required this.pending,
    required this.onTap,
  });
  final List<SharingMember> members;
  final int pending;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.primarySoft,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppLayout.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (members.isNotEmpty)
              SizedBox(
                height: AppLayout.minimumTouchTarget,
                width:
                    AppLayout.minimumTouchTarget +
                    (members.take(3).length - 1) * AppLayout.sectionGap,
                child: Stack(
                  children: [
                    for (var i = 0; i < members.take(3).length; i++)
                      Positioned(
                        left: i * AppLayout.sectionGap,
                        child: CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          foregroundColor: AppColors.primary,
                          child: Text(members[i].avatar),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Người cùng theo dõi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: AppLayout.smallGap),
            if (pending > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Chip(
                  avatar: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 18,
                  ),
                  label: Text('$pending lời mời đang chờ'),
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                ),
              ),
            Text(
              '${members.isEmpty ? 'Chưa chia sẻ với ai · Mời bố hoặc người thân cùng xem' : members.map((m) => '${m.role} ${m.name}').join(', ')}${pending > 0 ? ' · $pending lời mời đang chờ' : ''}',
            ),
          ],
        ),
      ),
    ),
  );
}
