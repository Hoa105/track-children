import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../app_date_picker.dart';
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _weeks;
  late final TextEditingController _weight;
  late bool _editing;
  bool _saving = false;
  bool _attempted = false;
  bool _created = false;
  late bool _premature;
  String? _gender;
  DateTime? _birth;
  XFile? _avatarFile;
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
    if (fields['avatar_base64'] != null &&
        (fields['avatar_base64'] as String).isNotEmpty) {
      try {
        _avatarBytes = base64Decode(fields['avatar_base64'] as String);
      } catch (_) {}
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

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: SettingsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SettingsColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Ảnh đại diện cho bé',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SettingsColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: SettingsColors.textPrimary,
                  ),
                ),
                title: const Text(
                  'Chọn từ thư viện ảnh',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SettingsColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: SettingsColors.textPrimary,
                  ),
                ),
                title: const Text(
                  'Chụp ảnh mới',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (_avatarBytes != null)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFB44545),
                    ),
                  ),
                  title: const Text(
                    'Xóa ảnh đại diện',
                    style: TextStyle(
                      color: Color(0xFFB44545),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarBytes = null;
                      _avatarFile = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _avatarFile = file;
          _avatarBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        _toast('Không thể mở ảnh. Vui lòng kiểm tra quyền truy cập.');
      }
    }
  }

  Future<void> _chooseDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showAppDatePicker(
      context,
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
    if (!_formKey.currentState!.validate() ||
        _birth == null ||
        _gender == null) {
      _toast('Vui lòng điền đủ thông tin tên, ngày sinh và giới tính.');
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
      'avatar_base64':
          _avatarBytes != null ? base64Encode(_avatarBytes!) : null,
    };

    setState(() => _saving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(fields, _avatarFile);
      } else {
        final childId = await DemoStore.instance.saveChild(
          widget.initialFields?['id'] as String?,
          fields,
        );
        if (childId.isNotEmpty) {
          DemoStore.instance.selectChild(childId);
        }
      }
      if (!mounted) return;
      setState(() {
        _editing = false;
        _created = true;
      });
      _toast(
        widget.initialFields == null
            ? 'Đã tạo hồ sơ bé thành công.'
            : 'Đã lưu thay đổi hồ sơ bé.',
      );

      if (widget.initialFields == null && widget.onOpenHomePreview != null) {
        widget.onOpenHomePreview!(_name.text.trim());
      }
    } catch (_) {
      if (mounted) _toast('Chưa lưu được hồ sơ. Vui lòng thử lại.');
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
    final days = today.difference(anchor(months)).inDays;
    if (months < 0) return 'Vừa mới sinh';
    if (months == 0) return '$days ngày tuổi';
    return '$months tháng $days ngày';
  }

  Widget _profileOverview(String? avatarUrl) {
    final birth = _birth == null
        ? 'Chưa cập nhật'
        : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ Hero hiển thị thông tin bé
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: SettingsColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: SettingsColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C29451E),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _AvatarViewer(bytes: _avatarBytes, url: avatarUrl),
              const SizedBox(height: 14),
              Text(
                _name.text.trim().isEmpty ? 'Bé yêu' : _name.text.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SettingsColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: SettingsColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _age,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: SettingsColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: SettingsColors.border),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _infoBlock(
                      icon: Icons.cake_outlined,
                      label: 'Ngày sinh',
                      value: birth,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: SettingsColors.border,
                  ),
                  Expanded(
                    child: _infoBlock(
                      icon: _gender == 'male' ? Icons.male : Icons.female,
                      label: 'Giới tính',
                      value: _gender == 'male'
                          ? 'Bé trai'
                          : _gender == 'female'
                          ? 'Bé gái'
                          : 'Chưa cập nhật',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Thẻ thông tin lúc sinh
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'THÔNG TIN LÚC SINH',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SettingsColors.textSecondary,
              letterSpacing: .6,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: SettingsColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: SettingsColors.border),
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
              const Divider(height: 22, color: SettingsColors.border),
              _detailRow(
                Icons.calendar_month_outlined,
                'Tuổi thai khi sinh',
                _weeks.text.isEmpty ? 'Chưa cập nhật' : '${_weeks.text} tuần',
              ),
              if (_premature) ...[
                const Divider(height: 22, color: SettingsColors.border),
                _detailRow(
                  Icons.auto_awesome_rounded,
                  'Tình trạng sinh',
                  'Sinh non (Dưới 37 tuần)',
                  isAccent: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _infoBlock({
    required IconData icon,
    required String label,
    required String value,
  }) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: SettingsColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: SettingsColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: SettingsColors.textPrimary,
        ),
      ),
    ],
  );

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool isAccent = false,
  }) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isAccent
              ? SettingsColors.accent.withValues(alpha: .35)
              : SettingsColors.iconBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isAccent
              ? SettingsColors.primaryDark
              : SettingsColors.textPrimary,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: SettingsColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isAccent
              ? SettingsColors.primaryDark
              : SettingsColors.textPrimary,
        ),
      ),
    ],
  );

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: SettingsColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isNewChild = widget.initialFields == null && !_created;
    final avatarUrl = widget.initialFields?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: SettingsColors.background,
      appBar: AppBar(
        backgroundColor: SettingsColors.background,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
        title: Text(
          isNewChild ? 'Thêm bé mới' : 'Hồ sơ bé',
          style: const TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_editing)
            IconButton(
              tooltip: 'Chỉnh sửa hồ sơ',
              icon: const Icon(Icons.edit_outlined, color: SettingsColors.primary),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_editing) _profileOverview(avatarUrl),
                    if (_editing) ...[
                      // Avatar tương tác
                      Center(
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SettingsColors.iconBackground,
                                  border: Border.all(
                                    color: SettingsColors.surface,
                                    width: 3.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1229451E),
                                      blurRadius: 14,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _avatarBytes != null
                                    ? Image.memory(
                                        _avatarBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.child_care_rounded,
                                          size: 44,
                                          color: SettingsColors.textPrimary,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.child_care_rounded,
                                        size: 44,
                                        color: SettingsColors.textPrimary,
                                      ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: SettingsColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: SettingsColors.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Chạm vào ảnh để chọn ảnh đại diện của bé',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SettingsColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Card 1: Thông tin cơ bản của bé
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: SettingsColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: SettingsColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field(
                              'Họ và tên của bé *',
                              TextFormField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 100,
                                style: const TextStyle(
                                  color: SettingsColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ví dụ: Nguyễn Minh An',
                                  hintStyle: const TextStyle(
                                    color: SettingsColors.textSecondary,
                                  ),
                                  counterText: '',
                                  prefixIcon: const Icon(
                                    Icons.face_retouching_natural_rounded,
                                    color: SettingsColors.primary,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: SettingsColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Vui lòng nhập tên bé.'
                                    : null,
                              ),
                            ),
                            _field(
                              'Giới tính *',
                              Row(
                                children: [
                                  for (final item in [
                                    ('male', 'Bé trai', Icons.male_rounded),
                                    ('female', 'Bé gái', Icons.female_rounded),
                                  ]) ...[
                                    if (item.$1 == 'female')
                                      const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => setState(
                                          () => _gender = item.$1,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                          backgroundColor: _gender == item.$1
                                              ? SettingsColors.accent
                                              : SettingsColors.background,
                                          foregroundColor:
                                              SettingsColors.textPrimary,
                                          side: BorderSide(
                                            color: _gender == item.$1
                                                ? SettingsColors.primary
                                                : SettingsColors.border,
                                            width: _gender == item.$1 ? 1.5 : 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: Icon(
                                          _gender == item.$1
                                              ? Icons.check_circle_rounded
                                              : item.$3,
                                          size: 20,
                                          color: SettingsColors.textPrimary,
                                        ),
                                        label: Text(
                                          item.$2,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_attempted && _gender == null)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Vui lòng chọn giới tính của bé.',
                                  style: TextStyle(
                                    color: Color(0xFFB44545),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            _field(
                              'Ngày sinh *',
                              InkWell(
                                onTap: _chooseDate,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SettingsColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _attempted && _birth == null
                                          ? const Color(0xFFB44545)
                                          : SettingsColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        color: SettingsColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _birth == null
                                              ? 'Chọn ngày sinh của bé'
                                              : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}',
                                          style: TextStyle(
                                            color: _birth == null
                                                ? SettingsColors.textSecondary
                                                : SettingsColors.textPrimary,
                                            fontWeight: _birth == null
                                                ? FontWeight.normal
                                                : FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_drop_down_rounded,
                                        color: SettingsColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_birth != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: SettingsColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 16,
                                      color: SettingsColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tuổi hiện tại: $_age',
                                      style: const TextStyle(
                                        color: SettingsColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 2: Thông tin lúc sinh
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: SettingsColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: SettingsColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Bé sinh non (dưới 37 tuần)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: SettingsColors.textPrimary,
                                ),
                              ),
                              value: _premature,
                              activeTrackColor: SettingsColors.primary,
                              onChanged: (val) => setState(() {
                                _premature = val;
                                _weeks.text = val ? '35' : '40';
                              }),
                            ),
                            const SizedBox(height: 12),
                            _field(
                              'Tuổi thai khi sinh',
                              TextFormField(
                                controller: _weeks,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: SettingsColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ví dụ: 38',
                                  suffixText: 'tuần',
                                  prefixIcon: const Icon(
                                    Icons.pregnant_woman_rounded,
                                    color: SettingsColors.primary,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (text) {
                                  final w = int.tryParse(text);
                                  if (w != null) {
                                    setState(() => _premature = w < 37);
                                  }
                                },
                              ),
                            ),
                            _field(
                              'Cân nặng lúc sinh',
                              TextFormField(
                                controller: _weight,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: const TextStyle(
                                  color: SettingsColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ví dụ: 3.2 kg',
                                  suffixText: 'kg',
                                  prefixIcon: const Icon(
                                    Icons.monitor_weight_outlined,
                                    color: SettingsColors.primary,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: SettingsColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!_editing && (widget.initialFields != null || _created))
                      _SharingCard(
                        members: _members,
                        pending: _pending.length,
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => ChildSharingScreen(
                                childId: widget.initialFields?['id'] as String?,
                                members: _members,
                                pending: _pending,
                              ),
                            ),
                          );
                          if (mounted) {
                            final id = widget.initialFields?['id'] as String?;
                            if (id != null) {
                              setState(() {
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
                              });
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: SettingsColors.surface,
            border: Border(top: BorderSide(color: SettingsColors.border)),
          ),
          child: !_editing
              ? SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text(
                      'Chỉnh sửa hồ sơ bé',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: SettingsColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    if (!isNewChild) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _editing = false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: SettingsColors.textSecondary,
                            side: const BorderSide(color: SettingsColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: isNewChild ? 1 : 2,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          _saving
                              ? 'Đang lưu…'
                              : isNewChild
                              ? 'Lưu hồ sơ bé'
                              : 'Lưu thay đổi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: SettingsColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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

class _AvatarViewer extends StatelessWidget {
  const _AvatarViewer({this.bytes, this.url});
  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    height: 92,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: SettingsColors.iconBackground,
      border: Border.all(color: SettingsColors.border, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1029451E),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover)
        : url != null && url!.isNotEmpty
        ? Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.child_care_rounded,
              size: 44,
              color: SettingsColors.textPrimary,
            ),
          )
        : const Icon(
            Icons.child_care_rounded,
            size: 44,
            color: SettingsColors.textPrimary,
          ),
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SettingsColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: SettingsColors.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SettingsColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: SettingsColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Người cùng chăm sóc bé',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: SettingsColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: SettingsColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pending > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SettingsColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 16,
                      color: SettingsColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$pending lời mời đang chờ phản hồi',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: SettingsColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              members.isEmpty
                  ? 'Chưa chia sẻ với ai · Chạm để mời bố hoặc người thân cùng theo dõi'
                  : members.map((m) => '${m.role}: ${m.name}').join(', '),
              style: const TextStyle(
                color: SettingsColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
