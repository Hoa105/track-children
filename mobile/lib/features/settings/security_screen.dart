import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/demo_store.dart';
import 'live_change_password_dialog.dart';
import '../auth/otp_status.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, this.onDeleted});
  final VoidCallback? onDeleted;
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  Map<String, dynamic>? _state;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool clearError = true}) async {
    try {
      final auth = AuthService.instance;
      if (!auth.demoMode) {
        final value = await auth.accountSecurity();
        if (mounted) {
          setState(() {
            _state = value;
            if (clearError) _error = null;
          });
        }
      } else {
        final parent = DemoStore.instance.parent;
        final demoState = <String, dynamic>{
          'email': parent['email'] ?? 'phuhuynh@example.com',
          'phone': parent['phone'] ?? '0912345678',
          'emailVerifiedAt': '2026-01-01T00:00:00Z',
          'phoneVerifiedAt': '2026-01-01T00:00:00Z',
          'hasPassword': true,
          'providers': <String>['google'],
          'requiresIdentifierVerification': false,
        };
        if (mounted) {
          setState(() {
            _state = demoState;
            if (clearError) _error = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<String?> _input(
    String title, {
    bool secret = false,
    bool otp = false,
  }) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SettingsColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            obscureText: secret,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: SettingsColors.textPrimary),
            keyboardType: otp
                ? TextInputType.number
                : secret
                ? TextInputType.visiblePassword
                : TextInputType.text,
            inputFormatters: otp
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ]
                : null,
            decoration: InputDecoration(
              hintText: otp
                  ? 'Nhập mã xác minh 6 số'
                  : secret
                  ? 'Nhập mật khẩu hiện tại'
                  : title.contains('Email')
                  ? 'tenban@example.com'
                  : '0912345678',
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
            validator: (value) => value == null || value.isEmpty
                ? 'Vui lòng nhập thông tin.'
                : otp && !RegExp(r'^\d{6}$').hasMatch(value)
                ? 'Nhập đủ 6 chữ số.'
                : null,
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _reauth(
    String action, {
    String? target,
    bool providerOnly = false,
  }) async {
    final providers = (_state?['providers'] as List? ?? []).cast<String>();
    final method = await showModalBottomSheet<String>(
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
                  'Xác minh danh tính',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              if (!providerOnly && _state?['hasPassword'] == true)
                ListTile(
                  leading: const Icon(
                    Icons.lock_outline_rounded,
                    color: SettingsColors.primary,
                  ),
                  title: const Text(
                    'Mật khẩu hiện tại',
                    style: TextStyle(
                      color: SettingsColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: SettingsColors.textSecondary,
                  ),
                  onTap: () => Navigator.pop(ctx, 'password'),
                ),
              for (final provider in providers)
                ListTile(
                  leading: Icon(
                    provider == 'apple' ? Icons.apple : Icons.g_mobiledata_rounded,
                    color: SettingsColors.primary,
                    size: 26,
                  ),
                  title: Text(
                    provider == 'apple' ? 'Xác minh qua Apple' : 'Xác minh qua Google',
                    style: const TextStyle(
                      color: SettingsColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: SettingsColors.textSecondary,
                  ),
                  onTap: () => Navigator.pop(ctx, provider),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: SettingsColors.textSecondary,
                ),
                child: const Text('Hủy'),
              ),
            ],
          ),
        ),
      ),
    );
    if (method == null || !mounted) return null;
    final password = method == 'password'
        ? await _input('Xác minh mật khẩu', secret: true)
        : null;
    if (method == 'password' && password == null) return null;
    return AuthService.instance.reauthenticate(
      action,
      target: target,
      password: password,
      provider: method == 'password' ? null : method,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load(clearError: false);
    } on AuthException catch (e) {
      if (mounted && e.code != 'SOCIAL_CANCELLED') {
        setState(() => _error = e.toString());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa hoàn tất yêu cầu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _identifier(String kind) => _run(() async {
    final target = await _input(
      kind == 'email' ? 'Email mới' : 'Số điện thoại mới',
    );
    if (target == null || !mounted) return;
    final auth = AuthService.instance;
    if (!auth.demoMode) {
      final grant = await _reauth('change_$kind', target: target.trim());
      if (grant == null || !mounted) return;
      final ticket = await AuthService.instance.startIdentifier(grant, kind);
      if (!mounted) return;
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _IdentifierOtp(kind: kind, ticket: ticket),
        ),
      );
      if (verified == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật và xác minh thông tin.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await DemoStore.instance.saveParent({kind: target.trim()});
      if (mounted) {
        setState(() {
          _state?[kind] = target.trim();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật $kind mới trong dữ liệu thử nghiệm.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  });

  Future<void> _password() => _run(() async {
    if (_state?['hasPassword'] == true) {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LiveChangePasswordDialog(),
      );
      return;
    }
    final grant = await _reauth('set_password', providerOnly: true);
    if (grant == null || !mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SetupPassword(grant: grant),
    );
  });

  Future<void> _provider(String provider, bool linked) => _run(() async {
    final auth = AuthService.instance;
    if (!auth.demoMode) {
      final grant = await _reauth('${linked ? 'unlink' : 'link'}_$provider');
      if (grant != null) {
        await AuthService.instance.changeProvider(grant, provider, link: !linked);
      }
    } else {
      final current =
          List<String>.from((_state?['providers'] as List? ?? []).cast<String>());
      if (linked) {
        current.remove(provider);
      } else {
        current.add(provider);
      }
      setState(() {
        _state?['providers'] = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            linked
                ? 'Đã hủy liên kết $provider.'
                : 'Đã liên kết $provider thành công.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });

  Widget _sectionHeading(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        color: SettingsColors.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: .7,
      ),
    ),
  );

  Widget _groupCard({required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: SettingsColors.border),
    ),
    child: Material(
      color: SettingsColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );

  Widget _tileDivider() => const Divider(
    height: 1,
    indent: 64,
    endIndent: 16,
    color: SettingsColors.border,
  );

  @override
  Widget build(BuildContext context) {
    final providers = _state?['providers'] as List? ?? [];
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: SettingsColors.background,
        appBar: AppBar(
          backgroundColor: SettingsColors.background,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
          title: const Text(
            'Bảo mật tài khoản',
            style: TextStyle(
              color: SettingsColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _state == null && _error == null
              ? const Center(
                  child: CircularProgressIndicator(
                    color: SettingsColors.primary,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (_error != null)
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
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB44545),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_state == null) ...[
                      Center(
                        child: FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                          style: FilledButton.styleFrom(
                            backgroundColor: SettingsColors.primary,
                          ),
                        ),
                      ),
                    ] else ...[
                      if (_state?['requiresIdentifierVerification'] == true)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: SettingsColors.primarySoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: SettingsColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: SettingsColors.textSecondary,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Hãy xác minh email hoặc số điện thoại trước khi thay đổi các cài đặt bảo mật.',
                                  style: TextStyle(
                                    color: SettingsColors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _sectionHeading('THÔNG TIN ĐĂNG NHẬP'),
                      _groupCard(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: SettingsColors.iconBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.mail_outline_rounded,
                                color: SettingsColors.textPrimary,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'Email',
                              style: TextStyle(
                                color: SettingsColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${_state?['email'] ?? 'Chưa thiết lập'}${_state?['emailVerifiedAt'] != null ? ' · Đã xác minh' : ' · Chưa xác minh'}',
                              style: TextStyle(
                                color: _state?['emailVerifiedAt'] != null
                                    ? SettingsColors.textSecondary
                                    : const Color(0xFFC07020),
                                fontSize: 13,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: SettingsColors.textSecondary,
                            ),
                            onTap: _busy ? null : () => _identifier('email'),
                          ),
                          _tileDivider(),
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: SettingsColors.iconBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.phone_outlined,
                                color: SettingsColors.textPrimary,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'Số điện thoại',
                              style: TextStyle(
                                color: SettingsColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${_state?['phone'] ?? 'Chưa thiết lập'}${_state?['phoneVerifiedAt'] != null ? ' · Đã xác minh' : ' · Chưa xác minh'}',
                              style: TextStyle(
                                color: _state?['phoneVerifiedAt'] != null
                                    ? SettingsColors.textSecondary
                                    : const Color(0xFFC07020),
                                fontSize: 13,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: SettingsColors.textSecondary,
                            ),
                            onTap: _busy ? null : () => _identifier('phone'),
                          ),
                        ],
                      ),
                      _sectionHeading('MẬT KHẨU'),
                      _groupCard(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: SettingsColors.iconBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: SettingsColors.textPrimary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _state?['hasPassword'] == true
                                  ? 'Đổi mật khẩu'
                                  : 'Thiết lập mật khẩu',
                              style: const TextStyle(
                                color: SettingsColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _state?['hasPassword'] == true
                                  ? 'Cập nhật mật khẩu tài khoản đang dùng'
                                  : 'Tạo mật khẩu để đăng nhập bằng email/SĐT',
                              style: const TextStyle(
                                color: SettingsColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: SettingsColors.textSecondary,
                            ),
                            onTap: _busy ? null : _password,
                          ),
                        ],
                      ),
                      _sectionHeading('LIÊN KẾT TÀI KHOẢN'),
                      _groupCard(
                        children: [
                          for (final provider in ['google', 'apple']) ...[
                            if (provider == 'apple') _tileDivider(),
                            ListTile(
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: SettingsColors.iconBackground,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  provider == 'google'
                                      ? Icons.g_mobiledata_rounded
                                      : Icons.apple,
                                  color: SettingsColors.textPrimary,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                provider == 'google' ? 'Google' : 'Apple',
                                style: const TextStyle(
                                  color: SettingsColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                providers.contains(provider)
                                    ? 'Đã liên kết tài khoản'
                                    : 'Chưa liên kết',
                                style: const TextStyle(
                                  color: SettingsColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _provider(
                                          provider,
                                          providers.contains(provider),
                                        ),
                                style: TextButton.styleFrom(
                                  foregroundColor: providers.contains(provider)
                                      ? const Color(0xFFB44545)
                                      : SettingsColors.primary,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(
                                  providers.contains(provider)
                                      ? 'Hủy liên kết'
                                      : 'Liên kết',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      _sectionHeading('BẢO MẬT SINH TRẮC HỌC'),
                      _groupCard(
                        children: [
                          SwitchListTile(
                            secondary: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: SettingsColors.iconBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                color: SettingsColors.textPrimary,
                                size: 22,
                              ),
                            ),
                            title: const Text(
                              'Mở khóa bằng vân tay / Face ID',
                              style: TextStyle(
                                color: SettingsColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: const Text(
                              'Yêu cầu xác thực sinh trắc học khi mở lại ứng dụng',
                              style: TextStyle(
                                color: SettingsColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            value: BiometricService.instance.isEnabled,
                            activeThumbColor: SettingsColors.primary,
                            activeTrackColor: SettingsColors.primarySoft,
                            onChanged: (val) async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await BiometricService.instance.setEnabled(val);
                              if (mounted) {
                                setState(() {});
                                if (!ok && val) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Thiết bị chưa hỗ trợ hoặc xác thực sinh trắc học không thành công.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class _IdentifierOtp extends StatefulWidget {
  const _IdentifierOtp({required this.kind, required this.ticket});
  final String kind;
  final Map<String, dynamic> ticket;
  @override
  State<_IdentifierOtp> createState() => _IdentifierOtpState();
}

class _IdentifierOtpState extends State<_IdentifierOtp> {
  late Map<String, dynamic> _ticket = widget.ticket;
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(bool resend) async {
    if (_busy) return;
    if (!resend && !OtpTiming(_ticket).canVerify(_code.text)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (resend) {
        final value = await AuthService.instance.resendIdentifier(
          _ticket,
          widget.kind,
        );
        if (mounted) {
          setState(() {
            _ticket = value;
            _code.clear();
          });
        }
      } else {
        await AuthService.instance.verifyIdentifier(
          _ticket,
          widget.kind,
          _code.text,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: SettingsColors.background,
      appBar: AppBar(
        backgroundColor: SettingsColors.background,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
        title: const Text(
          'Xác minh thông tin',
          style: TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SettingsColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SettingsColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mã xác minh đã được gửi đến ${_ticket['targetMasked'] ?? 'bạn'}.',
                    style: const TextStyle(
                      color: SettingsColors.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('security-otp'),
                    controller: _code,
                    onChanged: (_) => setState(() {}),
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(
                      color: SettingsColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Mã xác minh (6 số)',
                      labelStyle: const TextStyle(
                        color: SettingsColors.textSecondary,
                      ),
                      hintText: '• • • • • •',
                      hintStyle: const TextStyle(
                        color: SettingsColors.textSecondary,
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
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB44545),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy || !OtpTiming(_ticket).canVerify(_code.text)
                        ? null
                        : () => _run(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: SettingsColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Xác minh',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                  const SizedBox(height: 12),
                  OtpStatus(
                    ticket: _ticket,
                    busy: _busy,
                    onResend: () => _run(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SetupPassword extends StatefulWidget {
  const _SetupPassword({required this.grant});
  final Map<String, dynamic> grant;
  @override
  State<_SetupPassword> createState() => _SetupPasswordState();
}

class _SetupPasswordState extends State<_SetupPassword> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController(), _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      backgroundColor: SettingsColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Thiết lập mật khẩu',
        style: TextStyle(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: SettingsColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  helperText: '8–64 ký tự, không khoảng trắng.',
                  helperStyle: const TextStyle(
                    color: SettingsColors.textSecondary,
                  ),
                  labelStyle: const TextStyle(
                    color: SettingsColors.textSecondary,
                  ),
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
                validator: (value) =>
                    !RegExp(r'^[!-~]{8,64}$').hasMatch(value ?? '')
                    ? 'Mật khẩu chưa đúng yêu cầu.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: SettingsColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                  labelStyle: const TextStyle(
                    color: SettingsColors.textSecondary,
                  ),
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
                validator: (value) => value != _password.text
                    ? 'Mật khẩu chưa trùng khớp.'
                    : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB44545),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: SettingsColors.textSecondary,
          ),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    await AuthService.instance.setupPassword(
                      widget.grant,
                      _password.text,
                      _confirm.text,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (mounted) setState(() => _error = e.toString());
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: SettingsColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Lưu mật khẩu'),
        ),
      ],
    ),
  );
}
