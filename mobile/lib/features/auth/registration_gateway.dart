import '../../services/auth_service.dart';

/// OTP-first contract. The legacy API creates a user before OTP, so it cannot
/// implement this interface safely. Inject a real adapter once that contract is
/// deployed; tests inject a fake without enabling a production auth bypass.
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
