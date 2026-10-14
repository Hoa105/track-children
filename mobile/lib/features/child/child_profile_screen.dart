import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
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
    _members = List.of(widget.members);
    _pending = List.generate(
      widget.pendingInvitations,
      (_) => 'Lời mời đang chờ',
    );
    final fields = widget.initialFields ?? {};
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

  @override
  Widget build(BuildContext context) {
    final editable = _editing && !_saving;
    final avatarUrl = widget.initialFields?['avatar_url'] as String?;
    return Scaffold(
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
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
                      if (!_editing &&
                          (widget.initialFields != null || _created))
                        _SharingCard(
                          members: _members,
                          pending: _pending.length,
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ChildSharingScreen(
                                  members: _members,
                                  pending: _pending,
                                ),
                              ),
                            );
                            if (mounted) setState(() {});
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
    child: Text(
      saving
          ? 'Đang lưu…'
          : editing
          ? 'Lưu'
          : '✎ Sửa',
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
            Text(
              '${members.isEmpty ? 'Chưa chia sẻ với ai · Mời bố hoặc người thân cùng xem' : members.map((m) => '${m.role} ${m.name}').join(', ')}${pending > 0 ? ' · $pending lời mời đang chờ' : ''}',
            ),
          ],
        ),
      ),
    ),
  );
}
