import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// HTTP client for the child APIs: adds the signed-in parent's access token,
/// which the backend requires (backend/app/features/auth/dependencies.py).
class AuthorizedClient extends http.BaseClient {
  AuthorizedClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await AuthService.instance.accessToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
