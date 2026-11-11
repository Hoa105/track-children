import 'auth_service.dart';

/// Các mục dữ liệu theo từng bé được cấp quyền khi chia sẻ (khớp backend sharing/schemas.py).
const sharingScopes = <String>[
  'growth',
  'assessment',
  'vaccination',
  'teething',
  'diary',
  'activities',
];

/// Lời mời chia sẻ hồ sơ bé gửi tới tài khoản hiện tại.
class IncomingInvitation {
  IncomingInvitation({
    required this.id,
    required this.childId,
    required this.childName,
    required this.inviterName,
    required this.permissions,
    required this.expiresAt,
    this.relationship,
  });

  factory IncomingInvitation.fromApi(Map<String, dynamic> raw) =>
      IncomingInvitation(
        id: raw['id'].toString(),
        childId: raw['child_id'].toString(),
        childName: raw['child_name'] as String? ?? 'bé',
        inviterName: raw['inviter_name'] as String? ?? 'Chủ hồ sơ',
        relationship: raw['relationship'] as String?,
        permissions: Map<String, String>.from(
          raw['proposed_permissions'] as Map? ?? const {},
        ),
        expiresAt:
            DateTime.tryParse(raw['expires_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  final String id, childId, childName, inviterName;
  final String? relationship;
  final Map<String, String> permissions;
  final DateTime expiresAt;
}

/// Câu thông báo backend gửi kèm lỗi (vd. "Hồ sơ đã đủ 3 vị trí chia sẻ").
String sharingErrorMessage(Object error, String fallback) {
  if (error is AuthException) {
    final message = error.details['message'];
    if (message is String && message.isNotEmpty) return message;
    if (error.code == 'NETWORK_ERROR') return 'Không kết nối được máy chủ.';
  }
  return fallback;
}

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
    Map<String, String> permissions, {
    String relationship = 'other_guardian',
  }) => _auth.authorizedRequest(
    'POST',
    '/children/$childId/sharing/invitations',
    body: {
      if (contact.contains('@')) 'email': contact else 'phone': contact,
      'relationship': relationship,
      'permissions': permissions,
    },
  );

  /// Chủ hồ sơ huỷ lời mời đang chờ.
  Future<void> cancelInvitation(String childId, String invitationId) async {
    await _auth.authorizedRequest(
      'DELETE',
      '/children/$childId/sharing/invitations/$invitationId',
    );
  }

  /// Lời mời đang chờ gửi tới tài khoản hiện tại.
  Future<List<IncomingInvitation>> incoming() async {
    final result = await _auth.authorizedRequest('GET', '/sharing/invitations');
    return [
      for (final raw in result['invitations'] as List? ?? const [])
        IncomingInvitation.fromApi(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  Future<void> accept(String invitationId) async {
    await _auth.authorizedRequest(
      'POST',
      '/sharing/invitations/$invitationId/accept',
    );
  }

  Future<void> decline(String invitationId) async {
    await _auth.authorizedRequest(
      'POST',
      '/sharing/invitations/$invitationId/decline',
    );
  }

  /// Người được chia sẻ tự rời hồ sơ bé.
  Future<void> leave(String childId) async {
    await _auth.authorizedRequest('POST', '/children/$childId/sharing/leave');
  }
}
