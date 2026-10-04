import 'child.dart';
import 'parent_role.dart';

/// The parts of a child's profile the owner grants access to one by one
/// (F23.2). The child's basic info isn't listed: invitees can always view
/// it and never edit it.
enum ShareSection { growth, assessment, vaccination, journal, activities }

extension ShareSectionX on ShareSection {
  String get label => switch (this) {
        ShareSection.growth => 'Tăng trưởng',
        ShareSection.assessment => 'Đánh giá phát triển',
        ShareSection.vaccination => 'Tiêm chủng & mọc răng',
        ShareSection.journal => 'Nhật ký',
        ShareSection.activities => 'Hoạt động của bé',
      };

  /// What "Xem & sửa" allows in this section.
  String get editDescription => switch (this) {
        ShareSection.growth => 'ghi nhận số đo',
        ShareSection.assessment => 'làm bài đánh giá',
        ShareSection.vaccination => 'cập nhật mũi tiêm, răng mọc',
        ShareSection.journal => 'viết, sửa nhật ký',
        ShareSection.activities => 'đánh dấu hoạt động đã làm',
      };
}

enum AccessLevel { none, view, edit }

extension AccessLevelX on AccessLevel {
  String get label => switch (this) {
        AccessLevel.none => 'Không xem',
        AccessLevel.view => 'Xem',
        AccessLevel.edit => 'Xem & sửa',
      };
}

/// Per-section access an owner grants an invitee. [viewOnly] is the default
/// for a new invite.
/// No combination lets the invitee edit basic info, delete the profile or
/// invite more people — those stay with the owner.
class SharePermissions {
  const SharePermissions(this.levels);

  final Map<ShareSection, AccessLevel> levels;

  static const viewOnly = SharePermissions({
    ShareSection.growth: AccessLevel.view,
    ShareSection.assessment: AccessLevel.view,
    ShareSection.vaccination: AccessLevel.view,
    ShareSection.journal: AccessLevel.view,
    ShareSection.activities: AccessLevel.view,
  });

  static const coCare = SharePermissions({
    ShareSection.growth: AccessLevel.edit,
    ShareSection.assessment: AccessLevel.edit,
    ShareSection.vaccination: AccessLevel.edit,
    ShareSection.journal: AccessLevel.edit,
    ShareSection.activities: AccessLevel.edit,
  });

  AccessLevel of(ShareSection section) => levels[section] ?? AccessLevel.none;

  bool canView(ShareSection section) => of(section) != AccessLevel.none;

  bool canEdit(ShareSection section) => of(section) == AccessLevel.edit;

  /// An invite that grants nothing beyond basic info isn't worth sending.
  bool get hasAnyAccess => ShareSection.values.any(canView);

  SharePermissions withLevel(ShareSection section, AccessLevel level) =>
      SharePermissions({...levels, section: level});

  /// Short summary for pills/lists, e.g. "Xem tất cả", "Sửa 2/4 mục".
  String get label {
    final total = ShareSection.values.length;
    final editable = ShareSection.values.where(canEdit).length;
    final viewable = ShareSection.values.where(canView).length;
    if (editable == total) return 'Xem & sửa tất cả';
    if (editable > 0) return 'Sửa $editable/$total mục';
    if (viewable == total) return 'Xem tất cả';
    return 'Xem $viewable/$total mục';
  }

  /// One line per section, e.g. "Tăng trưởng: Xem & sửa (ghi nhận số đo)".
  List<String> get summaryLines => [
        for (final s in ShareSection.values)
          switch (of(s)) {
            AccessLevel.none => '${s.label}: Không xem',
            AccessLevel.view => '${s.label}: Xem',
            AccessLevel.edit => '${s.label}: Xem & sửa (${s.editDescription})',
          },
      ];

  @override
  bool operator ==(Object other) =>
      other is SharePermissions && ShareSection.values.every((s) => of(s) == other.of(s));

  @override
  int get hashCode => Object.hashAll(ShareSection.values.map(of));
}

enum ShareStatus { pending, accepted }

/// Invitations stay valid for this long (F23.3).
const shareInviteValidity = Duration(days: 7);

/// Owner-side record: one person the current user has shared (or is
/// sharing) a child's profile with (F23.1, F23.4, F23.5).
class ChildShare {
  final String id;
  final String childId;

  /// Null when the invite was sent as a bare code — the owner doesn't know
  /// who will redeem it until it's accepted.
  final String? inviteeName;
  final String? contact;
  final ParentRole role;
  final SharePermissions permissions;
  final ShareStatus status;
  final DateTime invitedAt;
  final String inviteCode;

  /// The owner asked this member to take over the profile (F23.11) and is
  /// waiting for them to accept.
  final bool transferPending;

  const ChildShare({
    required this.id,
    required this.childId,
    this.inviteeName,
    this.contact,
    required this.role,
    required this.permissions,
    required this.status,
    required this.invitedAt,
    required this.inviteCode,
    this.transferPending = false,
  });

  String get displayName => inviteeName ?? contact ?? 'Người nhận mã $inviteCode';

  DateTime get expiresAt => invitedAt.add(shareInviteValidity);

  bool isExpired(DateTime now) => status == ShareStatus.pending && now.isAfter(expiresAt);

  ChildShare copyWith({
    SharePermissions? permissions,
    ShareStatus? status,
    DateTime? invitedAt,
    bool? transferPending,
  }) =>
      ChildShare(
        id: id,
        childId: childId,
        inviteeName: inviteeName,
        contact: contact,
        role: role,
        permissions: permissions ?? this.permissions,
        status: status ?? this.status,
        invitedAt: invitedAt ?? this.invitedAt,
        inviteCode: inviteCode,
        transferPending: transferPending ?? this.transferPending,
      );
}

/// Invitee-side record: a child's profile someone else shared with the
/// current user, either still awaiting a response or already joined
/// (F23.3, F23.6, F23.7).
class SharedChildAccess {
  final String id;
  final Child child;
  final String ownerName;
  final ParentRole ownerRole;
  final ParentRole myRole;
  final SharePermissions permissions;
  final ShareStatus status;
  final DateTime invitedAt;
  final String inviteCode;

  /// The owner offered to hand the profile over to the current user (F23.11).
  final bool ownershipOffered;

  const SharedChildAccess({
    required this.id,
    required this.child,
    required this.ownerName,
    required this.ownerRole,
    required this.myRole,
    required this.permissions,
    required this.status,
    required this.invitedAt,
    required this.inviteCode,
    this.ownershipOffered = false,
  });

  /// e.g. "Trần Thu Hà (Mẹ)".
  String get ownerLabel => '$ownerName (${ownerRole.label})';

  DateTime get expiresAt => invitedAt.add(shareInviteValidity);

  SharedChildAccess copyWith({ShareStatus? status, bool? ownershipOffered}) => SharedChildAccess(
        id: id,
        child: child,
        ownerName: ownerName,
        ownerRole: ownerRole,
        myRole: myRole,
        permissions: permissions,
        status: status ?? this.status,
        invitedAt: invitedAt,
        inviteCode: inviteCode,
        ownershipOffered: ownershipOffered ?? this.ownershipOffered,
      );
}

/// "Hết hạn sau 5 ngày" / "Đã hết hạn" for a pending invite.
String inviteExpiryText(DateTime expiresAt, DateTime now) {
  final days = expiresAt.difference(now).inHours / 24;
  if (days <= 0) return 'Đã hết hạn';
  if (days < 1) return 'Hết hạn trong hôm nay';
  return 'Hết hạn sau ${days.ceil()} ngày';
}
