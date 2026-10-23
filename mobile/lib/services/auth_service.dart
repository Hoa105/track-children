import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'demo_store.dart';
import 'social_identity.dart';

class AuthException implements Exception {
  AuthException(this.code, this.details);
  final String code;
  final Map<String, dynamic> details;
  @override
  String toString() => switch (code) {
    'VALIDATION_ERROR' =>
      'Thông tin chưa hợp lệ. Vui lòng kiểm tra: ${((details['fields'] as Map?)?.keys ?? ['thông tin đã nhập']).map((field) => switch (field.toString().split('.').first) {
        'password' => 'mật khẩu (8–64 ký tự)',
        'email' => 'email',
        'phone' => 'số điện thoại',
        'username' => 'tên người dùng',
        'fullName' || 'displayName' => 'tên hiển thị',
        'acceptedTerms' => 'điều khoản',
        'consents' => 'điều khoản',
        'code' => 'mã OTP',
        _ => field.toString(),
      }).join(', ')}.',
    'INVALID_CREDENTIALS' => 'Email, số điện thoại hoặc mật khẩu chưa đúng.',
    'ACCOUNT_CONFLICT' => 'Email hoặc số điện thoại đã được dùng.',
    'OTP_DELIVERY_UNAVAILABLE' =>
      'Kênh gửi mã xác minh chưa sẵn sàng. Vui lòng thử lại sau.',
    'LEGAL_DOCUMENTS_UNAVAILABLE' =>
      'Chưa tải được điều khoản. Vui lòng thử lại sau.',
    'LEGAL_CONSENT_REQUIRED' => 'Vui lòng đồng ý với điều khoản và chính sách.',
    'OTP_INVALID' => 'Mã OTP chưa đúng.',
    'OTP_EXPIRED' => 'Mã OTP đã hết hạn. Vui lòng gửi lại.',
    'RATE_LIMITED' || 'LOGIN_TEMPORARILY_LOCKED' =>
      'Bạn đã thử quá nhiều lần. Vui lòng chờ rồi thử lại.',
    'OTP_ATTEMPTS_EXCEEDED' => 'Đã hết lượt nhập mã. Vui lòng gửi lại OTP.',
    'REGISTRATION_CHALLENGE_INVALID' =>
      'Phiên xác thực đã hết hạn. Vui lòng đăng nhập lại.',
    'ACCOUNT_LOCKED' => 'Tài khoản đã bị khóa.',
    'SOCIAL_AUTH_NOT_CONFIGURED' => 'Đăng nhập Google/Apple chưa được cấu hình. Vui lòng liên hệ nhóm phát triển.',
    'SOCIAL_PLATFORM_UNSUPPORTED' =>
      'Phương thức này chưa được hỗ trợ trên nền tảng đang dùng.',
    'SOCIAL_CANCELLED' => 'Chưa đăng nhập được. Kiểm tra mạng và thử lại.',
    'SOCIAL_SIGN_IN_FAILED' || 'SOCIAL_TOKEN_INVALID' =>
      'Không xác minh được Google/Apple. Vui lòng thử lại.',
    'SOCIAL_PROVIDER_UNAVAILABLE' =>
      'Chưa kết nối được Google/Apple. Vui lòng thử lại sau.',
    'SOCIAL_EMAIL_NOT_VERIFIED' =>
      'Nhà cung cấp chưa xác nhận email của tài khoản này.',
    'SOCIAL_ACCOUNT_CONFLICT' =>
      'Email đã có tài khoản. Vui lòng đăng nhập bằng phương thức đã đăng ký.',
    'NETWORK_ERROR' => 'Không thể kết nối. Kiểm tra mạng và thử lại.',
    'SERVER_RESPONSE_INVALID' => 'Máy chủ phản hồi lỗi. Vui lòng thử lại.',
    'RATE_LIMIT_UNAVAILABLE' ||
    'DATABASE_UNAVAILABLE' => 'Máy chủ tạm thời bận. Vui lòng thử lại.',
    _ when code.startsWith('HTTP_5') =>
      'Máy chủ tạm thời lỗi. Vui lòng thử lại.',
    _ => 'Chưa thực hiện được yêu cầu ($code).',
  };
}

class AuthService {
  AuthService({
    http.Client? client,
    FlutterSecureStorage? storage,
    Future<Map<String, dynamic>> Function(String, String?)?
    socialIdentityProvider,
    this.demoMode = false,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _socialIdentityProvider =
           socialIdentityProvider ??
           ((provider, nonce) =>
               SocialIdentity.authenticate(provider, nonce: nonce));
  static const demoEnabled = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );
  static AuthService instance = AuthService(demoMode: demoEnabled);
  final bool demoMode;
  Map<String, dynamic>? _pendingRegistration;
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb
        ? 'http://localhost:8000/api/v1'
        : 'http://10.0.2.2:8000/api/v1',
  );
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final Future<Map<String, dynamic>> Function(String, String?)
  _socialIdentityProvider;
  String? _access;
  String? _refresh;
  bool _remember = true;
  Future<void>? _refreshing;
  int _generation = 0;
  Map<String, dynamic>? user;
  bool get signedIn => user != null;

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    bool authorized = false,
    bool retry = true,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (authorized && _access != null) 'Authorization': 'Bearer $_access',
      };
      final uri = Uri.parse('$baseUrl$path');
      final response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 20));
      var result = <String, dynamic>{};
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) throw const FormatException();
          result = decoded;
        } on FormatException {
          throw AuthException(
            response.statusCode >= 400
                ? 'HTTP_${response.statusCode}'
                : 'SERVER_RESPONSE_INVALID',
            {},
          );
        }
      }
      if (response.statusCode >= 400) {
        final rawError = result['error'];
        final error = rawError is Map<String, dynamic>
            ? rawError
            : <String, dynamic>{};
        if (authorized && retry && error['code'] == 'ACCESS_TOKEN_EXPIRED') {
          await refresh();
          return await _request(
            path,
            body: body,
            authorized: true,
            retry: false,
          );
        }
        throw AuthException(
          error['code'] is String
              ? error['code'] as String
              : 'HTTP_${response.statusCode}',
          {
            if (error['details'] is Map)
              ...Map<String, dynamic>.from(error['details'] as Map),
            if (error['fields'] is Map) 'fields': error['fields'],
          },
        );
      }
      return result;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw AuthException('NETWORK_ERROR', {});
    } on http.ClientException {
      throw AuthException('NETWORK_ERROR', {});
    }
  }

  Future<Map<String, dynamic>> device() async {
    var id = await _storage.read(key: 'auth.device');
    if (id == null) {
      final rng = Random.secure();
      id = List.generate(
        24,
        (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _storage.write(key: 'auth.device', value: id);
    }
    return {
      'deviceId': id,
      'platform': kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
    };
  }

  Future<List<Map<String, dynamic>>> documents() async {
    if (demoMode) {
      return [
        {
          'id': 'demo-terms',
          'docType': 'Điều khoản mẫu',
          'version': 'demo',
          'content': 'Chế độ dữ liệu mẫu, thông tin chỉ lưu trên thiết bị.',
          'isRequired': true,
        },
      ];
    }
    final data = await _request('/legal-documents?context=registration');
    return (data['documents'] as List).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _demoChallenge() => {
    'verificationId': 'demo-registration',
    'registrationToken': 'demo',
    'targetMasked': 'thiết bị này (OTP mẫu: 123456)',
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
    'resendAvailableAt': DateTime.now().toIso8601String(),
  };

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    if (demoMode) {
      _pendingRegistration = Map<String, dynamic>.from(data);
      return _demoChallenge();
    }
    final result = await _request('/auth/register', body: data);
    return result;
  }

  Future<bool> socialRegister(
    String provider, {
    required bool acceptedTerms,
    String relationship = 'mother',
    bool remember = true,
  }) async {
    if (!acceptedTerms) throw AuthException('LEGAL_CONSENT_REQUIRED', {});
    Map<String, dynamic>? challenge;
    if (provider == 'apple') {
      challenge = await _request('/auth/social/apple/challenge', body: {});
    }
    try {
      final credential = await _socialIdentityProvider(
        provider,
        challenge?['nonce'] as String?,
      );
      final result = await _request(
        '/auth/social',
        body: {
          'provider': provider,
          ...credential,
          if (challenge != null) 'challenge': challenge['challenge'],
          'defaultRelationship': relationship,
          'acceptedTerms': true,
          'device': await device(),
          'rememberMe': remember,
        },
      );
      await _accept(result, remember);
      return result['isNewUser'] == true;
    } on SocialIdentityException catch (e) {
      throw AuthException(e.code, {});
    }
  }

  Future<Map<String, dynamic>> resend(Map<String, dynamic> challenge) async =>
      demoMode
      ? _demoChallenge()
      : _request(
          '/auth/register/resend',
          body: {
            'verificationId': challenge['verificationId'],
            'registrationToken': challenge['registrationToken'],
          },
        );
  Future<void> verify(
    Map<String, dynamic> challenge,
    String code, {
    bool remember = true,
  }) async {
    if (demoMode) {
      if (_pendingRegistration == null) {
        throw AuthException('REGISTRATION_CHALLENGE_INVALID', {});
      }
      if (DateTime.parse(challenge['expiresAt'] as String)
          .isBefore(DateTime.now())) {
        throw AuthException('OTP_EXPIRED', {});
      }
      if (code != '123456') throw AuthException('OTP_INVALID', {});
      final fields = Map<String, Object?>.from(_pendingRegistration!);
      fields['role'] =
          fields.remove('defaultRelationship') ??
          fields.remove('relationship') ??
          'other_guardian';
      fields['fullName'] = fields.remove('displayName') ?? fields['fullName'];
      fields.remove('acceptedTerms');
      fields.remove('consents');
      await DemoStore.instance.register(fields);
      _setDemoUser();
      _pendingRegistration = null;
      return;
    }
    final data = await _request(
      '/auth/register/verify',
      body: {
        'verificationId': challenge['verificationId'],
        'registrationToken': challenge['registrationToken'],
        'code': code,
        'rememberMe': remember,
        'device': await device(),
      },
    );
    await _accept(data, remember);
  }

  Future<void> login(
    String account,
    String password, {
    bool remember = true,
  }) async {
    if (demoMode) {
      if (!await DemoStore.instance.login(account, password)) {
        throw AuthException('INVALID_CREDENTIALS', {});
      }
      _setDemoUser();
      return;
    }
    final data = await _request(
      '/auth/login',
      body: {
        if (account.contains('@'))
          'email': account.trim()
        else
          'phone': account.trim(),
        'password': password,
        'rememberMe': remember,
        'device': await device(),
      },
    );
    await _accept(data, remember);
  }

  void _setDemoUser() {
    user = DemoStore.instance.parent..remove('password');
    user!['relationship'] = user!['role'];
  }

  Future<void> _accept(Map<String, dynamic> data, bool remember) async {
    if (remember) {
      await _storage.write(
        key: 'auth.refresh',
        value: data['refreshToken'] as String,
      );
    } else {
      await _storage.delete(key: 'auth.refresh');
    }
    _access = data['accessToken'] as String;
    _refresh = data['refreshToken'] as String;
    _remember = remember;
    user = data['user'] as Map<String, dynamic>? ?? user;
  }

  Future<Map<String, dynamic>> currentUser() async {
    if (demoMode) {
      if (!signedIn) throw AuthException('SESSION_EXPIRED', {});
      _setDemoUser();
      return user!;
    }
    final result = await _request('/auth/me', authorized: true);
    user = result;
    return result;
  }

  Future<void> refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  bool _invalidSession(String code) => const {
    'REFRESH_TOKEN_INVALID',
    'REFRESH_TOKEN_REUSED',
    'SESSION_REVOKED',
    'SESSION_EXPIRED',
    'ACCOUNT_UNAVAILABLE',
    'ACCOUNT_LOCKED',
    'ACCESS_TOKEN_INVALID',
    'ACCESS_TOKEN_EXPIRED',
  }.contains(code);
  Future<void> _doRefresh() async {
    if (demoMode) {
      await currentUser();
      return;
    }
    final generation = _generation;
    if (_refresh == null) throw AuthException('SESSION_EXPIRED', {});
    try {
      final data = await _request(
        '/auth/refresh',
        body: {'refreshToken': _refresh},
      );
      if (generation != _generation) return;
      await _accept(data, _remember);
    } on AuthException catch (e) {
      if (generation == _generation && _invalidSession(e.code)) await clear();
      rethrow;
    }
  }

  Future<bool> restore() async {
    if (demoMode) return false;
    _refresh = await _storage.read(key: 'auth.refresh');
    if (_refresh == null) return false;
    try {
      await refresh();
      user = await _request('/auth/me', authorized: true);
      return true;
    } on AuthException catch (e) {
      if (_invalidSession(e.code)) await clear();
      return false;
    }
  }

  Future<bool> logout() async {
    if (demoMode) {
      await clear();
      return true;
    }
    // Invalidate memory immediately; an old token can revoke its rotated session.
    final pending = _refreshing;
    final token = _refresh;
    await clear();
    try {
      await pending;
    } catch (_) {
      /* Session may already be invalid. */
    }
    if (token == null) return true;
    try {
      await _request('/auth/logout', body: {'refreshToken': token});
      return true;
    } on AuthException {
      return false;
    }
  }

  Future<void> clear() async {
    _generation++;
    _access = null;
    _refresh = null;
    user = null;
    if (demoMode) {
      _pendingRegistration = null;
      await DemoStore.instance.logout();
      return;
    }
    await _storage.delete(key: 'auth.refresh');
  }
}
