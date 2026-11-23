import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const String _prefKey = 'security_biometrics_enabled';
  final LocalAuthentication _auth = LocalAuthentication();

  bool _initialized = false;
  bool _enabled = false;
  bool _isLocked = false;
  DateTime? _backgroundTime;

  bool get isEnabled => _enabled;
  bool get isLocked => _isLocked;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? false;
      if (_enabled) {
        _isLocked = true;
      }
    } catch (_) {
      _enabled = false;
    }
    _initialized = true;
  }

  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> authenticate({
    String reason = 'Xác thực vân tay để truy cập ứng dụng Bé Lớn Khôn',
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        _isLocked = false;
        _backgroundTime = null;
      }
      return authenticated;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setEnabled(bool enable) async {
    if (enable) {
      final success = await authenticate(
        reason: 'Xác thực để kích hoạt tính năng mở khóa bằng vân tay',
      );
      if (!success) return false;
    }
    _enabled = enable;
    if (!enable) {
      _isLocked = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enable);
    } catch (_) {}
    return true;
  }

  void onAppPaused() {
    if (_enabled) {
      _backgroundTime = DateTime.now();
    }
  }

  bool onAppResumed() {
    if (!_enabled) return false;
    if (_backgroundTime != null) {
      final elapsed = DateTime.now().difference(_backgroundTime!);
      // Khóa lại nếu app rời foreground quá 30 giây
      if (elapsed.inSeconds >= 30) {
        _isLocked = true;
        return true;
      }
    }
    return _isLocked;
  }

  void markUnlocked() {
    _isLocked = false;
    _backgroundTime = null;
  }
}
