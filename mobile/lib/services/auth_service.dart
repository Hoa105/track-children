import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  AuthException(this.code, this.details);
  final String code;
  final Map<String, dynamic> details;
  @override
  String toString() => switch (code) {
    'INVALID_CREDENTIALS' => 'Email hoặc mật khẩu chưa đúng.',
    'ACCOUNT_CONFLICT' =>
      'Email, số điện thoại hoặc tên người dùng đã được dùng.',
    'OTP_INVALID' => 'Mã OTP chưa đúng.',
    'OTP_EXPIRED' => 'Mã OTP đã hết hạn. Vui lòng gửi lại.',
    'RATE_LIMITED' || 'LOGIN_TEMPORARILY_LOCKED' =>
      'Bạn đã thử quá nhiều lần. Vui lòng chờ rồi thử lại.',
    'OTP_ATTEMPTS_EXCEEDED' => 'Đã hết lượt nhập mã. Vui lòng gửi lại OTP.',
    'REGISTRATION_CHALLENGE_INVALID' =>
      'Phiên xác thực đã hết hạn. Vui lòng đăng nhập lại.',
    'ACCOUNT_LOCKED' => 'Tài khoản đã bị khóa.',
    'NETWORK_ERROR' => 'Không kết nối được máy chủ. Vui lòng thử lại.',
    _ => 'Chưa thực hiện được yêu cầu ($code).',
  };
}

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();
  static AuthService instance = AuthService();
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  final http.Client _client;
  final FlutterSecureStorage _storage;
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
      final result = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        final error = result['error'] as Map<String, dynamic>? ?? {};
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
          error['code'] as String? ?? 'HTTP_${response.statusCode}',
          Map<String, dynamic>.from(error['details'] as Map? ?? {}),
        );
      }
      return result;
    } on AuthException {
      rethrow;
    } catch (_) {
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
    final data = await _request('/legal-documents?context=registration');
    return (data['documents'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) =>
      _request('/auth/register', body: data);
  Future<Map<String, dynamic>> resend(Map<String, dynamic> challenge) =>
      _request(
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
    String email,
    String password, {
    bool remember = true,
  }) async {
    final data = await _request(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
        'rememberMe': remember,
        'device': await device(),
      },
    );
    await _accept(data, remember);
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
    final result = await _request('/auth/me', authorized: true);
    user = result;
    return result;
  }

  Future<void> refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  Future<void> _doRefresh() async {
    final generation = _generation;
    if (_refresh == null) throw AuthException('SESSION_EXPIRED', {});
    try {
      final data = await _request(
        '/auth/refresh',
        body: {'refreshToken': _refresh},
      );
      if (generation != _generation) return;
      await _accept(data, _remember);
    } catch (_) {
      if (generation == _generation) await clear();
      rethrow;
    }
  }

  Future<bool> restore() async {
    _refresh = await _storage.read(key: 'auth.refresh');
    if (_refresh == null) return false;
    try {
      await refresh();
      user = await _request('/auth/me', authorized: true);
      return true;
    } on AuthException catch (e) {
      if (e.code != 'NETWORK_ERROR') await clear();
      return false;
    }
  }

  Future<bool> logout() async {
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
    await _storage.delete(key: 'auth.refresh');
  }
}
