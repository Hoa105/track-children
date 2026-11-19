import '../../services/auth_service.dart';

/// OTP-first contract. The legacy API creates a user before OTP, so it cannot
/// implement this interface safely. The API adapter uses auth v2 and never
/// falls back to legacy registration; tests can inject a fake independently.
abstract class RegistrationGateway {
  Future<Map<String, dynamic>> start(String phone);
  Future<Map<String, dynamic>> resend(Map<String, dynamic> challenge);
  Future<Map<String, dynamic>> verify(
    Map<String, dynamic> challenge,
    String code,
  );
  Future<void> complete(
    Map<String, dynamic> grant,
    Map<String, dynamic> profile,
  );
}

class UnavailableRegistrationGateway implements RegistrationGateway {
  Never _unavailable() => throw AuthException('OTP_FIRST_UNAVAILABLE', {});
  @override
  Future<Map<String, dynamic>> start(String phone) async => _unavailable();
  @override
  Future<Map<String, dynamic>> resend(Map<String, dynamic> challenge) async =>
      _unavailable();
  @override
  Future<Map<String, dynamic>> verify(
    Map<String, dynamic> challenge,
    String code,
  ) async => _unavailable();
  @override
  Future<void> complete(
    Map<String, dynamic> grant,
    Map<String, dynamic> profile,
  ) async => _unavailable();
}

abstract class RevocableRegistrationGateway implements RegistrationGateway {
  Future<void> invalidate(Map<String, dynamic> challenge);
}

class ApiRegistrationGateway implements RevocableRegistrationGateway {
  @override
  Future<void> invalidate(Map<String, dynamic> challenge) =>
      AuthService.instance.invalidatePhoneSignup(challenge);
  @override
  Future<Map<String, dynamic>> start(String phone) =>
      AuthService.instance.startPhoneSignup(phone);
  @override
  Future<Map<String, dynamic>> resend(Map<String, dynamic> challenge) =>
      AuthService.instance.resendPhoneSignup(challenge);
  @override
  Future<Map<String, dynamic>> verify(
    Map<String, dynamic> challenge,
    String code,
  ) => AuthService.instance.verifyPhoneSignup(challenge, code);
  @override
  Future<void> complete(
    Map<String, dynamic> grant,
    Map<String, dynamic> profile,
  ) => AuthService.instance.completePhoneSignup(grant, profile);
}
