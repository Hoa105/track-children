import 'auth_service.dart';

class SharingApi {
  SharingApi({AuthService? auth}) : _auth = auth ?? AuthService.instance;
  final AuthService _auth;

  Future<Map<String, dynamic>> fetch(String childId) =>
      _auth.authorizedRequest('GET', '/children/$childId/sharing');

  Future<void> updateMember(
    String childId,
    String memberId,
    Map<String, String> permissions,
  ) async {
    await _auth.authorizedRequest(
      'PUT',
      '/children/$childId/sharing/members/$memberId',
      body: {'permissions': permissions},
    );
  }

  Future<void> revokeMember(String childId, String memberId) async {
    await _auth.authorizedRequest(
      'DELETE',
      '/children/$childId/sharing/members/$memberId',
    );
  }

  Future<Map<String, dynamic>> invite(
    String childId,
    String contact,
    Map<String, String> permissions,
  ) => _auth.authorizedRequest(
    'POST',
    '/children/$childId/sharing/invitations',
    body: {
      if (contact.contains('@')) 'email': contact else 'phone': contact,
      'relationship': 'other_guardian',
      'permissions': permissions,
    },
  );
}

