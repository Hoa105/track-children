import 'dart:math' as math;

import '../models/child.dart';
import '../models/child_share.dart';
import '../models/parent_role.dart';

/// Sharing a child's profile with other caregivers (F23). Owner-side calls
/// take a childId; invitee-side calls work on [SharedChildAccess] ids.
abstract class SharingService {
  /// People (joined + pending) a child's profile can be shared with.
  static const maxMembersPerChild = 3;

  Future<List<ChildShare>> getShares(String childId);

  /// Pass [contact] (email/SĐT) to send the invite, or leave it null to only
  /// generate a code the owner hands over themselves.
  Future<ChildShare> invite({
    required String childId,
    String? contact,
    required ParentRole role,
    required SharePermissions permissions,
  });
  Future<void> updatePermissions(String shareId, SharePermissions permissions);
  Future<ChildShare> resendInvite(String shareId);

  /// Revokes a joined member or cancels a pending invite.
  Future<void> revoke(String shareId);

  /// Offers a joined member ownership of the profile (F23.11). Only one
  /// offer per child can be open at a time.
  Future<void> requestOwnershipTransfer(String shareId);
  Future<void> cancelOwnershipTransfer(String shareId);

  Future<List<SharedChildAccess>> getSharedWithMe();
  Future<SharedChildAccess?> findInviteByCode(String code);
  Future<void> respondToInvite(String accessId, {required bool accept});
  Future<void> leave(String accessId);

  /// Invitee answers an ownership offer. On accept the child becomes one of
  /// the current user's own children (returned) and the previous owner stays
  /// on as a member with full access.
  Future<Child?> respondToOwnershipOffer(String accessId, {required bool accept});
}

class MockSharingService implements SharingService {
  final _random = math.Random();

  final List<ChildShare> _shares = [
    ChildShare(
      id: 's1',
      childId: 'c1',
      inviteeName: 'Nguyễn Văn Nam',
      contact: 'nam.nguyen@gmail.com',
      role: ParentRole.father,
      permissions: SharePermissions.viewOnly,
      status: ShareStatus.accepted,
      invitedAt: DateTime.now().subtract(const Duration(days: 40)),
      inviteCode: 'BLK-N4M2Q',
    ),
    ChildShare(
      id: 's2',
      childId: 'c1',
      contact: '0912345678',
      role: ParentRole.guardian,
      permissions: const SharePermissions({
        ShareSection.growth: AccessLevel.edit,
        ShareSection.assessment: AccessLevel.view,
        ShareSection.vaccination: AccessLevel.edit,
        ShareSection.journal: AccessLevel.none,
        ShareSection.activities: AccessLevel.edit,
      }),
      status: ShareStatus.pending,
      invitedAt: DateTime.now().subtract(const Duration(days: 2)),
      inviteCode: 'BLK-7RK3P',
    ),
  ];

  final List<SharedChildAccess> _sharedWithMe = [
    SharedChildAccess(
      id: 'a1',
      child: Child(
        id: 'sc1',
        name: 'Trần Gia Hân',
        gender: ChildGender.girl,
        dob: DateTime.now().subtract(const Duration(days: 30 * 30 + 4)),
      ),
      ownerName: 'Trần Thu Hà',
      ownerRole: ParentRole.mother,
      myRole: ParentRole.guardian,
      permissions: const SharePermissions({
        ShareSection.growth: AccessLevel.view,
        ShareSection.assessment: AccessLevel.view,
        ShareSection.vaccination: AccessLevel.view,
        ShareSection.journal: AccessLevel.none,
        ShareSection.activities: AccessLevel.view,
      }),
      status: ShareStatus.accepted,
      invitedAt: DateTime.now().subtract(const Duration(days: 60)),
      inviteCode: 'BLK-H4N6T',
      ownershipOffered: true,
    ),
    SharedChildAccess(
      id: 'a2',
      child: Child(
        id: 'sc2',
        name: 'Trần Gia Huy',
        gender: ChildGender.boy,
        dob: DateTime.now().subtract(const Duration(days: 9 * 30 + 10)),
      ),
      ownerName: 'Trần Thu Hà',
      ownerRole: ParentRole.mother,
      myRole: ParentRole.guardian,
      permissions: SharePermissions.coCare,
      status: ShareStatus.pending,
      invitedAt: DateTime.now().subtract(const Duration(days: 1)),
      inviteCode: 'BLK-8Q2MX',
    ),
  ];

  String _newCode() {
    // No 0/O/1/I so the code is easy to read out loud.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'BLK-${List.generate(5, (_) => chars[_random.nextInt(chars.length)]).join()}';
  }

  int _indexOf(String shareId) => _shares.indexWhere((s) => s.id == shareId);

  @override
  Future<List<ChildShare>> getShares(String childId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _shares.where((s) => s.childId == childId).toList();
  }

  @override
  Future<ChildShare> invite({
    required String childId,
    String? contact,
    required ParentRole role,
    required SharePermissions permissions,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final share = ChildShare(
      id: 's${DateTime.now().microsecondsSinceEpoch}',
      childId: childId,
      contact: contact,
      role: role,
      permissions: permissions,
      status: ShareStatus.pending,
      invitedAt: DateTime.now(),
      inviteCode: _newCode(),
    );
    _shares.add(share);
    return share;
  }

  @override
  Future<void> updatePermissions(String shareId, SharePermissions permissions) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final i = _indexOf(shareId);
    if (i >= 0) _shares[i] = _shares[i].copyWith(permissions: permissions);
  }

  @override
  Future<ChildShare> resendInvite(String shareId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _indexOf(shareId);
    _shares[i] = _shares[i].copyWith(invitedAt: DateTime.now());
    return _shares[i];
  }

  @override
  Future<void> revoke(String shareId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _shares.removeWhere((s) => s.id == shareId);
  }

  @override
  Future<void> requestOwnershipTransfer(String shareId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _indexOf(shareId);
    _shares[i] = _shares[i].copyWith(transferPending: true);
  }

  @override
  Future<void> cancelOwnershipTransfer(String shareId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final i = _indexOf(shareId);
    if (i >= 0) _shares[i] = _shares[i].copyWith(transferPending: false);
  }

  @override
  Future<Child?> respondToOwnershipOffer(String accessId, {required bool accept}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _sharedWithMe.indexWhere((a) => a.id == accessId);
    if (i < 0) return null;
    final access = _sharedWithMe[i];
    if (!accept) {
      _sharedWithMe[i] = access.copyWith(ownershipOffered: false);
      return null;
    }
    _sharedWithMe.removeAt(i);
    _shares.add(ChildShare(
      id: 's${DateTime.now().microsecondsSinceEpoch}',
      childId: access.child.id,
      inviteeName: access.ownerName,
      role: access.ownerRole,
      permissions: SharePermissions.coCare,
      status: ShareStatus.accepted,
      invitedAt: DateTime.now(),
      inviteCode: _newCode(),
    ));
    return access.child;
  }

  @override
  Future<List<SharedChildAccess>> getSharedWithMe() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_sharedWithMe);
  }

  @override
  Future<SharedChildAccess?> findInviteByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalized = code.trim().toUpperCase();
    return _sharedWithMe
        .where((a) => a.status == ShareStatus.pending && a.inviteCode == normalized)
        .firstOrNull;
  }

  @override
  Future<void> respondToInvite(String accessId, {required bool accept}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _sharedWithMe.indexWhere((a) => a.id == accessId);
    if (i < 0) return;
    if (accept) {
      _sharedWithMe[i] = _sharedWithMe[i].copyWith(status: ShareStatus.accepted);
    } else {
      _sharedWithMe.removeAt(i);
    }
  }

  @override
  Future<void> leave(String accessId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _sharedWithMe.removeWhere((a) => a.id == accessId);
  }
}
