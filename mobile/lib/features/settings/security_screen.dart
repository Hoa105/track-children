import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
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
      final value = await AuthService.instance.accountSecurity();
      if (mounted) {
        setState(() {
          _state = value;
          if (clearError) _error = null;
        });
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
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            obscureText: secret,
            autocorrect: false,
            enableSuggestions: false,
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
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    // Dialog route finishes its transition before releasing the controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Xác minh danh tính'),
            ),
            if (!providerOnly && _state?['hasPassword'] == true)
              ListTile(
                title: const Text('Mật khẩu hiện tại'),
                onTap: () => Navigator.pop(ctx, 'password'),
              ),
            for (final provider in providers)
              ListTile(
                title: Text(provider == 'apple' ? 'Apple' : 'Google'),
                onTap: () => Navigator.pop(ctx, provider),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
          ],
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
        const SnackBar(content: Text('Đã cập nhật và xác minh thông tin.')),
      );
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
    final grant = await _reauth('${linked ? 'unlink' : 'link'}_$provider');
    if (grant != null) {
      await AuthService.instance.changeProvider(grant, provider, link: !linked);
    }
  });
  Future<void> _delete() => _run(() async {
    if ((_state?['ownedChildren'] as int? ?? 0) > 0) {
      setState(
        () => _error = 'Hãy chuyển quyền hoặc xóa từng hồ sơ trẻ đang sở hữu trước khi xóa tài khoản.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: const Text(
          'Thông tin tài khoản sẽ được ẩn danh và các phiên đăng nhập bị thu hồi. Dữ liệu đã đóng góp cho hồ sơ trẻ của người khác được giữ cùng hồ sơ đó. Thao tác không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final grant = await _reauth('delete_account');
    if (grant == null) return;
    await AuthService.instance.deleteVerifiedAccount(
      grant,
      appleLinked: (_state?['providers'] as List? ?? []).contains('apple'),
    );
    if (mounted) {
      Navigator.pop(context);
      widget.onDeleted?.call();
    }
  });
  @override
  Widget build(BuildContext context) {
    final providers = _state?['providers'] as List? ?? [];
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bảo mật tài khoản')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_state == null) ...[
                if (_error == null)
                  const Center(child: CircularProgressIndicator())
                else
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
              ] else ...[
                if (_state?['requiresIdentifierVerification'] == true)
                  const Text(
                    'Hãy xác minh email hoặc số điện thoại trước khi thay đổi bảo mật.',
                  ),
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(
                    '${_state?['email'] ?? 'Chưa có'}${_state?['emailVerifiedAt'] != null ? ' · Đã xác minh' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _identifier('email'),
                ),
                ListTile(
                  title: const Text('Số điện thoại'),
                  subtitle: Text(
                    '${_state?['phone'] ?? 'Chưa có'}${_state?['phoneVerifiedAt'] != null ? ' · Đã xác minh' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _identifier('phone'),
                ),
                ListTile(
                  title: Text(
                    _state?['hasPassword'] == true
                        ? 'Đổi mật khẩu'
                        : 'Thiết lập mật khẩu',
                  ),
                  onTap: _busy ? null : _password,
                ),
                const Divider(),
                for (final provider in ['google', 'apple'])
                  ListTile(
                    title: Text(provider == 'google' ? 'Google' : 'Apple'),
                    subtitle: Text(
                      providers.contains(provider)
                          ? 'Đã liên kết'
                          : 'Chưa liên kết',
                    ),
                    trailing: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _provider(
                              provider,
                              providers.contains(provider),
                            ),
                      child: Text(
                        providers.contains(provider)
                            ? 'Hủy liên kết'
                            : 'Liên kết',
                      ),
                    ),
                  ),
                const Divider(),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  child: const Text('Xóa tài khoản'),
                ),
              ],
              if (_busy)
                const Text('Đang xử lý yêu cầu…', textAlign: TextAlign.center),
            ],
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
  late final Timer _timer;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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
      appBar: AppBar(title: const Text('Xác minh thông tin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Nhập mã đã gửi đến ${_ticket['targetMasked'] ?? 'bạn'}.'),
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
              decoration: const InputDecoration(
                labelText: 'Mã xác minh',
                hintText: 'Nhập mã 6 số',
              ),
            ),
            if (_error != null) Text(_error!),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || !OtpTiming(_ticket).canVerify(_code.text)
                  ? null
                  : () => _run(false),
              child: const Text('Xác minh'),
            ),
            OtpStatus(ticket: _ticket, busy: _busy, onResend: () => _run(true)),
            if (_busy) const Center(child: CircularProgressIndicator()),
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
      title: const Text('Thiết lập mật khẩu'),
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
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  helperText:
                      '8–64 ký tự, không dấu, không khoảng trắng hoặc emoji.',
                ),
                validator: (value) =>
                    !RegExp(r'^[!-~]{8,64}$').hasMatch(value ?? '')
                    ? 'Mật khẩu chưa đúng yêu cầu.'
                    : null,
              ),
              TextFormField(
                controller: _confirm,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                ),
                validator: (value) => value != _password.text
                    ? 'Mật khẩu chưa trùng khớp.'
                    : null,
              ),
              if (_error != null) Text(_error!),
              if (_busy) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
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
          child: const Text('Lưu mật khẩu'),
        ),
      ],
    ),
  );
}
