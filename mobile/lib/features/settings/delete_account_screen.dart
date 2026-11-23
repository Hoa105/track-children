import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/demo_store.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({this.onDeleted, super.key});

  final VoidCallback? onDeleted;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _ownedChildren = [];
  final Set<String> _confirmedChildren = {};
  Map<String, dynamic>? _securityState;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final auth = AuthService.instance;
      if (auth.signedIn && !auth.demoMode) {
        final sec = await auth.accountSecurity();
        final childrenRes = await auth.authorizedRequest('GET', '/children');
        final all = (childrenRes['children'] as List? ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();

        // Chỉ lọc các bé thuộc sở hữu tài khoản (role == 'owner')
        final owned = all.where((c) => c['role'] == 'owner').toList();

        if (mounted) {
          setState(() {
            _securityState = sec;
            _ownedChildren = owned;
            _loading = false;
          });
        }
      } else {
        // Chế độ demo / khách
        final demoChildren = DemoStore.instance.children
            .map((c) => Map<String, dynamic>.from(c))
            .toList();

        if (mounted) {
          setState(() {
            _ownedChildren = demoChildren;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tải danh sách hồ sơ: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteSingleChild(Map<String, dynamic> child) async {
    final childId = child['id']?.toString() ?? '';
    final childName = (child['fullName'] ?? child['full_name'] ?? 'Bé') as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SettingsColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB44545),
              size: 26,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Xóa hồ sơ $childName?',
                style: const TextStyle(
                  color: Color(0xFFB44545),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Toàn bộ dữ liệu tăng trưởng, lịch tiêm chủng, nhật ký và mốc phát triển của $childName sẽ bị xóa vĩnh viễn cùng tài khoản. Bạn có chắc chắn muốn xác nhận xóa hồ sơ bé này?',
          style: const TextStyle(color: SettingsColors.textPrimary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: SettingsColors.textSecondary,
            ),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB44545),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa bé'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _confirmedChildren.add(childId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xác nhận xóa hồ sơ bé $childName.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _inputPassword() async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SettingsColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Nhập mật khẩu xác thực',
          style: TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Để đảm bảo an toàn, vui lòng nhập mật khẩu hiện tại trước khi xóa tài khoản.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: SettingsColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                autocorrect: false,
                style: const TextStyle(color: SettingsColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Nhập mật khẩu hiện tại',
                  hintStyle: const TextStyle(color: SettingsColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SettingsColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: SettingsColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Vui lòng nhập mật khẩu.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: SettingsColors.textSecondary,
            ),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, controller.text);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: SettingsColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    controller.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _reauth() async {
    final hasPassword = _securityState?['hasPassword'] == true;
    final providers = (_securityState?['providers'] as List? ?? []).cast<String>();

    String? method;
    if (hasPassword && providers.isEmpty) {
      method = 'password';
    } else {
      method = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: SettingsColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                    'Xác minh trước khi xóa tài khoản',
                    style: TextStyle(
                      color: SettingsColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (hasPassword)
                  ListTile(
                    leading: const Icon(
                      Icons.lock_outline_rounded,
                      color: SettingsColors.primary,
                    ),
                    title: const Text('Mật khẩu tài khoản'),
                    onTap: () => Navigator.pop(ctx, 'password'),
                  ),
                for (final p in providers)
                  ListTile(
                    leading: Icon(
                      p == 'google' ? Icons.g_mobiledata_rounded : Icons.apple,
                      color: SettingsColors.primary,
                      size: 24,
                    ),
                    title: Text(
                      'Xác thực qua ${p == 'google' ? 'Google' : 'Apple'}',
                    ),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (method == null) return null;

    if (method == 'password') {
      final pass = await _inputPassword();
      if (pass == null) return null;
      return AuthService.instance.reauthenticate(
        'delete_account',
        password: pass,
      );
    } else {
      return AuthService.instance.reauthenticate(
        'delete_account',
        provider: method,
      );
    }
  }

  Future<void> _continue() async {
    // Kiểm tra tất cả các bé sở hữu đã được xác nhận xóa thủ công chưa
    if (_confirmedChildren.length < _ownedChildren.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng xác nhận xóa thủ công từng bé bạn đang sở hữu trước khi tiếp tục.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SettingsColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Xác nhận xóa tài khoản vĩnh viễn?',
          style: TextStyle(
            color: Color(0xFFB44545),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Khi hoàn tất, tài khoản của bạn sẽ được ẩn danh, các hồ sơ trẻ đã xác nhận sẽ bị xóa hoàn toàn và mọi phiên đăng nhập sẽ bị thu hồi. Thao tác này KHÔNG THỂ HOÀN TÁC.',
          style: TextStyle(color: SettingsColors.textPrimary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: SettingsColors.textSecondary,
            ),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB44545),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);

    try {
      final auth = AuthService.instance;
      if (auth.signedIn && !auth.demoMode) {
        // 1. Re-authenticate
        final grant = await _reauth();
        if (grant == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }

        // 2. Xóa từng bé đã được người dùng xác nhận
        for (final child in _ownedChildren) {
          final cid = child['id']?.toString();
          if (cid != null && _confirmedChildren.contains(cid)) {
            try {
              await auth.authorizedRequest('DELETE', '/children/$cid');
            } catch (_) {}
          }
        }

        // 3. Xóa tài khoản
        final providers = (_securityState?['providers'] as List? ?? []).cast<String>();
        await auth.deleteVerifiedAccount(
          grant,
          appleLinked: providers.contains('apple'),
        );
      } else {
        // Demo mode
        await DemoStore.instance.clearAuthenticatedCache();
        await DemoStore.instance.logout();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản và toàn bộ dữ liệu đã được xóa hoàn tất.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onDeleted?.call();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi khi xóa tài khoản: $e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allConfirmed =
        _ownedChildren.isEmpty || _confirmedChildren.length == _ownedChildren.length;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: SettingsColors.background,
        appBar: AppBar(
          backgroundColor: SettingsColors.background,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
          title: const Text(
            'Xóa tài khoản và dữ liệu',
            style: TextStyle(
              color: SettingsColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: SettingsColors.primary,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8E8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF9A8A8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFB44545),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB44545),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5ED),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFD8BF)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFAA5A3B),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Trước khi xóa tài khoản, bạn bắt buộc phải xác nhận xóa thủ công từng hồ sơ trẻ bạn đang sở hữu.',
                              style: TextStyle(
                                height: 1.45,
                                color: Color(0xFF9E4018),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'HỒ SƠ TRẺ BẠN ĐANG SỞ HỮU (${_confirmedChildren.length}/${_ownedChildren.length})',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: SettingsColors.textSecondary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6,
                            ),
                      ),
                    ),
                    if (_ownedChildren.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: SettingsColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SettingsColors.border),
                        ),
                        child: const Text(
                          'Tài khoản của bạn hiện không sở hữu hồ sơ trẻ nào. Bạn có thể tiếp tục xóa tài khoản ngay lập tức.',
                          style: TextStyle(
                            color: SettingsColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      for (final child in _ownedChildren) ...[
                        _ChildDeleteCard(
                          child: child,
                          isConfirmed: _confirmedChildren.contains(
                            child['id']?.toString() ?? '',
                          ),
                          onConfirm: () => _confirmDeleteSingleChild(child),
                          onCancelConfirm: () {
                            setState(() {
                              _confirmedChildren.remove(
                                child['id']?.toString() ?? '',
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                            allConfirmed && !_busy ? _continue : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB44545),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: SettingsColors.border,
                          disabledForegroundColor: SettingsColors.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Tiếp tục xóa tài khoản',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bạn vẫn có thể hủy thao tác bất kỳ lúc nào trước khi xác nhận lần cuối.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SettingsColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ChildDeleteCard extends StatelessWidget {
  const _ChildDeleteCard({
    required this.child,
    required this.isConfirmed,
    required this.onConfirm,
    required this.onCancelConfirm,
  });

  final Map<String, dynamic> child;
  final bool isConfirmed;
  final VoidCallback onConfirm;
  final VoidCallback onCancelConfirm;

  @override
  Widget build(BuildContext context) {
    final name = (child['fullName'] ?? child['full_name'] ?? 'Bé') as String;
    final dob = (child['dateOfBirth'] ?? child['date_of_birth'] ?? '') as String;
    final gender = child['gender'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConfirmed ? const Color(0xFFFFF0F0) : SettingsColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConfirmed ? const Color(0xFFF9A8A8) : SettingsColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConfirmed
                      ? const Color(0xFFFDE8E8)
                      : SettingsColors.iconBackground,
                ),
                child: Icon(
                  isConfirmed
                      ? Icons.delete_outline_rounded
                      : Icons.child_care_rounded,
                  color: isConfirmed
                      ? const Color(0xFFB44545)
                      : SettingsColors.textPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isConfirmed
                            ? const Color(0xFFB44545)
                            : SettingsColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    if (dob.isNotEmpty)
                      Text(
                        'Ngày sinh: $dob${gender != null ? ' · ${gender == 'male' ? 'Bé trai' : 'Bé gái'}' : ''}',
                        style: const TextStyle(
                          color: SettingsColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (isConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF9A8A8)),
                  ),
                  child: const Text(
                    'Đã xác nhận xóa',
                    style: TextStyle(
                      color: Color(0xFFB44545),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isConfirmed)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onCancelConfirm,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Hủy xác nhận'),
                  style: TextButton.styleFrom(
                    foregroundColor: SettingsColors.textSecondary,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Xác nhận xóa hồ sơ bé này'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB44545),
                  side: const BorderSide(color: Color(0xFFD57C7C)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
