import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import '../../services/sharing_api.dart';
import 'shared_with_me_screen.dart';

enum AccessLevel { none, view, edit }

Map<String, dynamic>? _demoSharingChild(String? id) =>
    id == null ? DemoStore.instance.child : DemoStore.instance.childById(id);
String _demoSharingCode(String? id) =>
    id == null ? 'AN-4K9P-72' : 'DEMO-${id.toUpperCase()}';

List<SharingMember> demoSharingMembers(String id) => [
  for (final m in DemoStore.instance.childById(id)?['members'] as List? ?? [])
    SharingMember(
      id: m['id'] as String?,
      name: m['name'] as String,
      role: m['role'] as String,
      contact: m['contact'] as String,
      avatar: m['avatar'] as String,
      permissions: (m['permissions'] as Map).map(
        (k, v) => MapEntry(k as String, AccessLevel.values.byName(v as String)),
      ),
    ),
];

class SharingMember {
  SharingMember({
    this.id,
    required this.name,
    required this.role,
    required this.contact,
    required this.avatar,
    Map<String, AccessLevel>? permissions,
  }) : permissions = permissions ?? _defaultPermissions();

  final String name;
  final String? id;
  final String role;
  final String contact;
  final String avatar;
  final Map<String, AccessLevel> permissions;
  bool get isOwner => role == 'Chủ sở hữu';

  static Map<String, AccessLevel> _defaultPermissions() => {
    for (final module in _modules) module: AccessLevel.none,
  };
}

const _modules = <String>[
  'Tăng trưởng',
  'Đánh giá',
  'Tiêm chủng',
  'Mọc răng',
  'Nhật ký',
  'Hoạt động',
];

const _scopeForModule = <String, String>{
  'Tăng trưởng': 'growth',
  'Đánh giá': 'assessment',
  'Tiêm chủng': 'vaccination',
  'Mọc răng': 'teething',
  'Nhật ký': 'diary',
  'Hoạt động': 'activities',
};

class ChildSharingScreen extends StatefulWidget {
  const ChildSharingScreen({
    super.key,
    this.members,
    this.pending,
    this.childId,
  });
  final String? childId;

  final List<SharingMember>? members;
  final List<String>? pending;

  @override
  State<ChildSharingScreen> createState() => _ChildSharingScreenState();
}

class _ChildSharingScreenState extends State<ChildSharingScreen> {
  final _sharingApi = SharingApi();
  bool _loading = false;
  late final String? _childId =
      widget.childId ?? DemoStore.instance.child?['id'] as String?;
  late final _members =
      (_childId != null ? demoSharingMembers(_childId) : widget.members) ??
      <SharingMember>[
        SharingMember(
          name: 'Bà Nguyễn Thị Mai',
          role: 'Bà ngoại',
          contact: 'mainguyen@example.com',
          avatar: 'M',
        ),
        SharingMember(
          name: 'Trần Minh Anh',
          role: 'Người chăm sóc',
          contact: '••• •• 4821',
          avatar: 'A',
          permissions: {
            for (final module in _modules)
              module: module == 'Tăng trưởng' || module == 'Nhật ký'
                  ? AccessLevel.edit
                  : AccessLevel.view,
          },
        ),
      ];

  late final _pending = _childId != null
      ? List<String>.from(
          DemoStore.instance.childById(_childId)?['pending'] as List? ?? [],
        )
      : widget.pending ?? <String>[];

  /// Nhãn lời mời đang chờ → id lời mời trên máy chủ (để huỷ).
  final _pendingIds = <String, String>{};

  /// Đăng nhập tài khoản thật: mọi thao tác chia sẻ đi qua máy chủ, kể cả bé
  /// tạo trên máy (được đăng ký lên máy chủ trước). Chế độ demo: chỉ lưu cục bộ.
  bool get _usesServer =>
      _childId != null &&
      (DemoStore.instance.childById(_childId)?['server'] == true ||
          DemoStore.instance.canShareOnServer);

  String? _remoteChildId;

  /// Id của bé trên máy chủ (bé tạo trên máy được đăng ký ở lần gọi đầu).
  Future<String> _serverChildId() async =>
      _remoteChildId ??= await DemoStore.instance.sharingChildId(_childId!);

  @override
  void initState() {
    super.initState();
    if (_usesServer) unawaited(_loadSharing());
  }

  Future<void> _loadSharing() async {
    setState(() => _loading = true);
    try {
      final result = await _sharingApi.fetch(await _serverChildId());
      final loaded = <SharingMember>[
        for (final raw in result['members'] as List)
          _memberFromApi(Map<String, dynamic>.from(raw as Map)),
      ];
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(loaded);
        _pending.clear();
        _pendingIds.clear();
        for (final raw in result['invitations'] as List) {
          final label =
              'Lời mời · ${raw['invitee_email'] ?? raw['invitee_phone'] ?? ''}';
          _pending.add(label);
          _pendingIds[label] = raw['id'].toString();
        }
      });
    } catch (error) {
      if (mounted) _toast('Chưa tải được quyền chia sẻ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  SharingMember _memberFromApi(Map<String, dynamic> raw) {
    final scopes = Map<String, dynamic>.from(raw['permissions'] as Map? ?? {});
    final name = raw['display_name'] as String? ?? 'Người chăm sóc';
    return SharingMember(
      id: raw['id'].toString(),
      name: name,
      role: relationshipLabel(raw['relationship'] as String?),
      contact: (raw['email'] ?? raw['phone'] ?? '') as String,
      avatar: name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      permissions: {
        for (final module in _modules)
          module: AccessLevel.values.byName(
            scopes[_scopeForModule[module]] as String? ?? 'none',
          ),
      },
    );
  }

  Map<String, String> _apiPermissions(SharingMember member) => {
    for (final entry in member.permissions.entries)
      _scopeForModule[entry.key]!: entry.value.name,
  };

  Future<void> _persist() async {
    if (_childId == null) return;
    try {
      if (_usesServer) {
        await Future.wait([
          for (final member in _members)
            if (member.id != null)
              _sharingApi.updateMember(
                await _serverChildId(),
                member.id!,
                _apiPermissions(member),
              ),
        ]);
        return;
      }
      await DemoStore.instance.saveSharing(_childId, [
        for (final m in _members)
          {
            'name': m.name,
            'role': m.role,
            'contact': m.contact,
            'avatar': m.avatar,
            'permissions': m.permissions.map((k, v) => MapEntry(k, v.name)),
          },
      ], _pending);
    } catch (_) {
      if (mounted) _toast('Chưa lưu được thay đổi quyền chia sẻ. Vui lòng thử lại.');
    }
  }

  Future<void> _revokeMember(SharingMember member) async {
    try {
      if (_usesServer && member.id != null) {
        await _sharingApi.revokeMember(await _serverChildId(), member.id!);
      }
      if (!mounted) return;
      setState(() => _members.remove(member));
      if (!_usesServer) await _persist();
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast('Đã thu hồi quyền truy cập của ${member.name}.');
    } catch (_) {
      if (mounted) _toast('Chưa thể thu hồi quyền truy cập. Vui lòng thử lại.');
    }
  }

  /// Tạo lời mời với mối quan hệ và quyền chủ hồ sơ đã chọn; true khi thành công.
  Future<bool> _sendInvitation(SharingInvite invite) async {
    try {
      if (_usesServer) {
        await _sharingApi.invite(
          await _serverChildId(),
          invite.contact,
          invite.permissions,
          relationship: invite.relationship,
        );
        await _loadSharing();
      } else {
        if (!mounted) return false;
        setState(() => _pending.add('Lời mời · ${invite.contact}'));
        await _persist();
      }
      if (mounted) {
        _toast(
          _usesServer
              ? 'Đã gửi lời mời tới ${invite.contact} '
                    '(${relationshipLabel(invite.relationship)}), hiệu lực trong 7 ngày.'
              : 'Đã lưu lời mời trên máy (chế độ demo), chưa gửi tới máy chủ.',
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        _toast(sharingErrorMessage(
          error,
          'Chưa thể gửi lời mời. Vui lòng kiểm tra thông tin và thử lại.',
        ));
      }
      return false;
    }
  }

  Future<void> _cancelInvitation(String entry) async {
    try {
      final id = _pendingIds[entry];
      if (_usesServer && id != null) {
        await _sharingApi.cancelInvitation(await _serverChildId(), id);
      }
      if (!mounted) return;
      setState(() {
        _pending.remove(entry);
        _pendingIds.remove(entry);
      });
      if (!_usesServer) await _persist();
      _toast('Đã hủy lời mời.');
    } catch (error) {
      if (mounted) {
        _toast(sharingErrorMessage(error, 'Chưa hủy được lời mời. Vui lòng thử lại.'));
      }
    }
  }

  Future<void> _openPermissions(SharingMember member) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharingPermissionsScreen(
          member: member,
          onRevoke: () {
            unawaited(_revokeMember(member));
          },
        ),
      ),
    );
    await _persist();
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _invite() async {
    if (_members.length + _pending.length >= 3) {
      _toast('Hồ sơ đã đủ 3 vị trí chia sẻ.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InviteMemberScreen(
          childId: _childId,
          onSendInvite: _sendInvitation,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _transferOwnership() async {
    if (_members.isEmpty) {
      _toast('Cần có thành viên khác trong hồ sơ để bàn giao.');
      return;
    }
    final transferred = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OwnershipTransferScreen(members: _members),
      ),
    );
    if (transferred == true && mounted) {
      _toast('Đã gửi yêu cầu chuyển quyền sở hữu.');
    }
  }

  @override
  Widget build(BuildContext context) =>
      _childId != null && !DemoStore.instance.isChildOwner(_childId)
      ? SharedChildAccessScreen(childId: _childId)
      : _ownerView(context);

  Widget _ownerView(BuildContext context) => Scaffold(
    backgroundColor: SharingColors.background,
    appBar: _sharingAppBar(
      context,
      _childId == null
          ? 'Chia sẻ hồ sơ bé'
          : 'Chia sẻ hồ sơ bé · ${DemoStore.instance.childById(_childId)?['full_name'] ?? ''}',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Quản lý chia sẻ',
          onSelected: (_) => _transferOwnership(),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'transfer',
              child: Text('Chuyển quyền sở hữu hồ sơ'),
            ),
          ],
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (_loading) ...[
            const LinearProgressIndicator(color: SharingColors.primary),
            const SizedBox(height: 12),
          ],
          _SharingHeroCard(
            childId: _childId,
            usedSlots: _members.length + _pending.length,
            totalSlots: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _invite,
                  style: _primaryButtonStyle(),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(
                    'Mời cùng chăm bé',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: 'Mã mời',
                style: IconButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  side: const BorderSide(color: SharingColors.border),
                  backgroundColor: SharingColors.surface,
                  foregroundColor: SharingColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InviteMemberScreen(
                      childId: _childId,
                      startWithCode: true,
                      onSendInvite: (_) async => false,
                    ),
                  ),
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionHeading(
            title: 'Người đang cùng chăm bé',
            trailing: '${_members.length}/3',
          ),
          const SizedBox(height: 10),
          if (_members.isEmpty)
            const _EmptyMembersCard()
          else
            ..._members.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemberCard(
                  member: member,
                  onTap: () => _openPermissions(member),
                ),
              ),
            ),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionHeading(
              title: 'Lời mời đang chờ',
              trailing: '${_pending.length}',
            ),
            const SizedBox(height: 10),
            _PendingCard(
              entries: _pending,
              onCancel: (entry) => unawaited(_cancelInvitation(entry)),
            ),
          ],
        ],
      ),
    ),
  );
}

class SharingPermissionsScreen extends StatefulWidget {
  const SharingPermissionsScreen({
    required this.member,
    this.onRevoke,
    this.onLeave,
    super.key,
  });

  final SharingMember member;
  final VoidCallback? onRevoke;
  final VoidCallback? onLeave;

  @override
  State<SharingPermissionsScreen> createState() =>
      _SharingPermissionsScreenState();
}

class _SharingPermissionsScreenState extends State<SharingPermissionsScreen> {
  EdgeDraggingAutoScroller? _dragScroller;

  void _scrollWhileDragging(
    BuildContext itemContext,
    DragUpdateDetails details,
  ) {
    _dragScroller ??= EdgeDraggingAutoScroller(
      Scrollable.of(itemContext),
      velocityScalar: 30,
    );
    _dragScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: details.globalPosition, width: 48, height: 48),
    );
  }

  void _stopDragScroll() => _dragScroller?.stopAutoScroll();

  @override
  void dispose() {
    _stopDragScroll();
    super.dispose();
  }

  late final Map<String, AccessLevel> _permissions =
      Map<String, AccessLevel>.from(widget.member.permissions);

  Future<void> _confirmAction({required bool revoke}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SharingColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          revoke ? 'Thu hồi quyền truy cập?' : 'Rời khỏi hồ sơ bé?',
          style: const TextStyle(fontWeight: FontWeight.w800, color: SharingColors.textPrimary),
        ),
        content: Text(
          revoke
              ? '${widget.member.name} sẽ không còn xem được thông tin của bé.'
              : 'Bạn sẽ không còn xem được thông tin của bé An.',
          style: const TextStyle(color: SharingColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau', style: TextStyle(color: SharingColors.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: SharingColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(revoke ? 'Thu hồi' : 'Rời hồ sơ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (revoke) {
        widget.onRevoke?.call();
      } else {
        widget.onLeave?.call();
      }
    }
  }

  void _setAll(AccessLevel level) => setState(() {
    for (final module in _modules) {
      _permissions[module] = level;
    }
  });

  void _showQuickPermissionSheet(BuildContext context, String module) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SharingColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SharingColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(_moduleIcon(module), color: SharingColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Quyền truy cập: $module',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: SharingColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn cấp độ quyền cho thành viên với mục này:',
                  style: TextStyle(fontSize: 13, color: SharingColors.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final lvl in AccessLevel.values) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: _permissions[module] == lvl
                        ? SharingColors.primarySoft
                        : Colors.transparent,
                    leading: Icon(
                      switch (lvl) {
                        AccessLevel.none => Icons.lock_outline_rounded,
                        AccessLevel.view => Icons.visibility_outlined,
                        AccessLevel.edit => Icons.edit_note_rounded,
                      },
                      color: _permissions[module] == lvl
                          ? SharingColors.primary
                          : SharingColors.muted,
                    ),
                    title: Text(
                      switch (lvl) {
                        AccessLevel.none => 'Chưa cấp quyền (Khóa)',
                        AccessLevel.view => 'Chỉ xem',
                        AccessLevel.edit => 'Xem & sửa',
                      },
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _permissions[module] == lvl
                            ? SharingColors.primaryDark
                            : SharingColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      switch (lvl) {
                        AccessLevel.none => 'Không thể xem hoặc tương tác với mục này',
                        AccessLevel.view => 'Chỉ xem dữ liệu, không thể chỉnh sửa',
                        AccessLevel.edit => 'Có thể xem, thêm và sửa dữ liệu',
                      },
                      style: const TextStyle(fontSize: 11, color: SharingColors.textSecondary),
                    ),
                    trailing: _permissions[module] == lvl
                        ? const Icon(Icons.check_circle_rounded, color: SharingColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _permissions[module] = lvl);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SharingColors.background,
    appBar: _sharingAppBar(context, 'Quyền truy cập'),
    bottomNavigationBar: _SharingBottomBar(
      child: FilledButton(
        onPressed: () {
          widget.member.permissions
            ..clear()
            ..addAll(_permissions);
          Navigator.of(context).pop();
        },
        style: _primaryButtonStyle(),
        child: const Text('Lưu thay đổi'),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _PersonSummaryCard(member: widget.member),
          const SizedBox(height: 18),
          const Text(
            'Quyền theo từng mục',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: SharingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhấn giữ một mục rồi kéo vào vùng Xem hoặc Xem & sửa. Kéo về Chưa cấp quyền để thu hồi.',
            style: TextStyle(fontSize: 12, color: SharingColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ContactChip(
                  label: 'Chỉ xem tất cả',
                  selected: _permissions.values.every((l) => l == AccessLevel.view),
                  onTap: () => _setAll(AccessLevel.view),
                ),
                const SizedBox(width: 8),
                _ContactChip(
                  label: 'Xem & sửa tất cả',
                  selected: _permissions.values.every((l) => l == AccessLevel.edit),
                  onTap: () => _setAll(AccessLevel.edit),
                ),
                const SizedBox(width: 8),
                _ContactChip(
                  label: 'Thu hồi tất cả',
                  selected: _permissions.values.every((l) => l == AccessLevel.none),
                  onTap: () => _setAll(AccessLevel.none),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final level in AccessLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PermissionZone(
                level: level,
                modules: _modules
                    .where(
                      (module) =>
                          (_permissions[module] ?? AccessLevel.none) == level,
                    )
                    .toList(),
                onDrop: (module) =>
                    setState(() => _permissions[module] = level),
                onDragUpdate: _scrollWhileDragging,
                onDragEnd: _stopDragScroll,
                onTapModule: (module) =>
                    _showQuickPermissionSheet(context, module),
              ),
            ),
          const _OwnerPrivacyNote(),
          if (widget.onRevoke != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _confirmAction(revoke: true),
              icon: const Icon(Icons.person_remove_alt_1_rounded, size: 18),
              label: const Text('Thu hồi quyền thành viên'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SharingColors.danger,
                side: const BorderSide(color: SharingColors.dangerSoft),
                backgroundColor: SharingColors.dangerSoft,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
          if (widget.onLeave != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _confirmAction(revoke: false),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Rời khỏi hồ sơ bé'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SharingColors.danger,
                side: const BorderSide(color: SharingColors.dangerSoft),
                backgroundColor: SharingColors.dangerSoft,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({
    this.childId,
    required this.onSendInvite,
    this.startWithCode = false,
    super.key,
  });

  /// Gửi lời mời; trả về true khi máy chủ (hoặc bản cục bộ) đã tạo lời mời.
  final Future<bool> Function(SharingInvite invite) onSendInvite;
  final String? childId;
  final bool startWithCode;

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _contactController = TextEditingController();
  bool _usePhone = false;
  late bool _codeMode = widget.startWithCode;
  bool _inviteCreated = false;
  bool _sending = false;
  String? _relationship;
  // Mặc định chỉ xem mọi mục; chủ hồ sơ chỉnh lại trước khi gửi.
  final _permissions = <String, String>{
    for (final scope in sharingScopes) scope: 'view',
  };

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _send() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      _toast('Nhập email hoặc số điện thoại trước nhé.');
      return;
    }
    if (_relationship == null) {
      _toast('Chọn mối quan hệ của người này với bé nhé.');
      return;
    }
    if (_permissions.values.every((level) => level == 'none')) {
      _toast('Cho phép người này xem ít nhất một mục nhé.');
      return;
    }
    setState(() => _sending = true);
    final created = await widget.onSendInvite(
      SharingInvite(
        contact: contact,
        relationship: _relationship!,
        permissions: Map.of(_permissions),
      ),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (created) {
        _inviteCreated = true;
        _contactController.clear();
      }
    });
  }

  void _setAll(String level) => setState(() {
    for (final scope in sharingScopes) {
      _permissions[scope] = level;
    }
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SharingColors.background,
    appBar: _sharingAppBar(context, 'Mời người thân'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _InviteHeaderCard(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6EBE0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _ModeButton(
                  label: 'Email / SĐT',
                  selected: !_codeMode,
                  onTap: () => setState(() => _codeMode = false),
                ),
                _ModeButton(
                  label: 'Mã mời',
                  selected: _codeMode,
                  onTap: () => setState(() => _codeMode = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_codeMode)
            _InviteCodeCard(
              childId: widget.childId,
              onCopy: () async {
                await Clipboard.setData(
                  ClipboardData(text: _demoSharingCode(widget.childId)),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Đã sao chép mã test: ${_demoSharingCode(widget.childId)}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            )
          else ...[
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin người nhận',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SharingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ContactChip(
                        label: 'Email',
                        selected: !_usePhone,
                        onTap: () => setState(() => _usePhone = false),
                      ),
                      _ContactChip(
                        label: 'Số điện thoại',
                        selected: _usePhone,
                        onTap: () => setState(() => _usePhone = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contactController,
                    keyboardType: _usePhone
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      label: _usePhone ? 'Số điện thoại' : 'Địa chỉ email',
                      hint: _usePhone ? '09xx xxx xxx' : 'ten@example.com',
                      icon: _usePhone
                          ? Icons.phone_outlined
                          : Icons.mail_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mối quan hệ với bé',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SharingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('invite-relationship'),
                    initialValue: _relationship,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      label: 'Chọn mối quan hệ',
                      hint: 'Vd. Bà ngoại',
                      icon: Icons.family_restroom_rounded,
                    ),
                    dropdownColor: SharingColors.surface,
                    items: [
                      for (final entry in sharingRelationships.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => setState(() => _relationship = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Quyền xem các mục',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SharingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chọn những mục người này được xem hoặc ghi. Bạn có thể đổi lại sau.',
                    style: TextStyle(fontSize: 12, color: SharingColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ContactChip(
                        label: 'Chỉ xem tất cả',
                        selected: _permissions.values.every((l) => l == 'view'),
                        onTap: () => _setAll('view'),
                      ),
                      _ContactChip(
                        label: 'Xem & sửa tất cả',
                        selected: _permissions.values.every((l) => l == 'edit'),
                        onTap: () => _setAll('edit'),
                      ),
                    ],
                  ),
                  for (final scope in sharingScopes) ...[
                    const Divider(height: 18, color: SharingColors.border),
                    Text(
                      sharingScopeLabels[scope]!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SharingColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final level in const ['none', 'view', 'edit'])
                          _ContactChip(
                            key: ValueKey('invite-$scope-$level'),
                            label: sharingLevelLabel(level),
                            selected: _permissions[scope] == level,
                            onTap: () =>
                                setState(() => _permissions[scope] = level),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _InfoBanner(
              icon: Icons.schedule_rounded,
              text: 'Lời mời có hiệu lực trong 7 ngày. Bạn có thể hủy bất cứ lúc nào.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('invite-send'),
              onPressed: _sending ? null : _send,
              style: _primaryButtonStyle(),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _sending
                    ? 'Đang gửi…'
                    : _inviteCreated
                    ? 'Gửi lời mời khác'
                    : 'Gửi lời mời',
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AcceptInvitationScreen(childId: widget.childId),
              ),
            ),
            icon: const Icon(Icons.mark_email_unread_outlined),
            label: const Text('Xem thử giao diện nhận lời mời'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SharingColors.primary,
              backgroundColor: Colors.white,
              side: const BorderSide(color: SharingColors.border),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _OwnerPrivacyNote(),
        ],
      ),
    ),
  );
}

class AcceptInvitationScreen extends StatefulWidget {
  const AcceptInvitationScreen({super.key, this.childId});
  final String? childId;

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SharingColors.background,
    appBar: _sharingAppBar(context, 'Lời mời tham gia'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: SharingColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                color: SharingColors.primary,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Bạn được mời cùng chăm sóc ${_demoSharingChild(widget.childId)?['full_name'] ?? 'bé An'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: SharingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DemoStore.instance.signedIn ? DemoStore.instance.parent['fullName'] : 'Nguyễn Minh Anh'} · lời mời mô phỏng cục bộ.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: SharingColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _InviteDetailsCard(childId: widget.childId),
          const SizedBox(height: 12),
          const _InfoBanner(
            icon: Icons.lock_outline_rounded,
            text: 'Bạn chỉ xem và chỉnh sửa được những mục được cấp quyền.',
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () {
              setState(() => _accepted = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đã xem thử trạng thái chấp nhận lời mời. Chưa cấp quyền qua dịch vụ.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: _primaryButtonStyle(),
            child: Text(_accepted ? 'Đã tham gia hồ sơ' : 'Chấp nhận lời mời'),
          ),
          if (_accepted) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const SharedProfileSwitcherScreen(),
                ),
              ),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Chuyển hồ sơ bé'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SharingColors.primary,
                backgroundColor: Colors.white,
                side: const BorderSide(color: SharingColors.border),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              if (!_accepted) {
                Navigator.of(context).pop();
                return;
              }
              final leave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: SharingColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'Rời khỏi hồ sơ bé?',
                    style: TextStyle(fontWeight: FontWeight.w800, color: SharingColors.textPrimary),
                  ),
                  content: const Text(
                    'Bạn có thể được mời tham gia lại sau.',
                    style: TextStyle(color: SharingColors.textPrimary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Ở lại', style: TextStyle(color: SharingColors.muted)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: SharingColors.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Rời hồ sơ'),
                    ),
                  ],
                ),
              );
              if (leave == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              _accepted ? 'Rời khỏi hồ sơ bé' : 'Từ chối lời mời',
              style: const TextStyle(color: SharingColors.muted),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Mã mời hết hạn sau 7 ngày',
              style: TextStyle(fontSize: 11, color: SharingColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class SharedProfileSwitcherScreen extends StatefulWidget {
  const SharedProfileSwitcherScreen({super.key});

  @override
  State<SharedProfileSwitcherScreen> createState() =>
      _SharedProfileSwitcherScreenState();
}

class _SharedProfileSwitcherScreenState
    extends State<SharedProfileSwitcherScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SharingColors.background,
    appBar: _sharingAppBar(context, 'Chuyển hồ sơ bé'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _InfoBanner(
            icon: Icons.family_restroom_rounded,
            text: 'Chọn hồ sơ bé bạn muốn mở. Quyền truy cập sẽ theo hồ sơ được chọn.',
          ),
          const SizedBox(height: 16),
          RadioGroup<int>(
            groupValue: _selected,
            onChanged: (value) =>
                setState(() => _selected = value ?? _selected),
            child: Column(
              children: [
                for (
                  var i = 0;
                  i <
                      (DemoStore.instance.signedIn
                          ? DemoStore.instance.children.length
                          : 2);
                  i++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setState(() => _selected = i),
                      borderRadius: BorderRadius.circular(22),
                      child: _SurfaceCard(
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: i == 1
                                    ? SharingColors.attentionSoft
                                    : SharingColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.child_care_rounded,
                                color: i == 1
                                    ? SharingColors.attention
                                    : SharingColors.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DemoStore.instance.signedIn
                                        ? DemoStore.instance.children[i]['full_name']
                                              as String
                                        : i == 1
                                        ? 'Bé An'
                                        : 'Bé Na',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: SharingColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DemoStore.instance.signedIn
                                        ? DemoStore.instance.ageLabel(
                                            DemoStore.instance.children[i],
                                          )
                                        : i == 1
                                        ? 'Được chia sẻ với bạn · 24 tháng'
                                        : 'Hồ sơ của bạn · 3 tuổi',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: SharingColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio<int>(
                              value: i,
                              activeColor: SharingColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              if (DemoStore.instance.signedIn &&
                  DemoStore.instance.children.isNotEmpty) {
                await DemoStore.instance.selectChild(
                  DemoStore.instance.children[_selected]['id'] as String,
                );
                if (context.mounted) {
                  Navigator.of(context).popUntil(
                    (route) => route.settings.name == '/home' || route.isFirst,
                  );
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            style: _primaryButtonStyle(),
            child: Text(
              'Mở ${DemoStore.instance.signedIn && DemoStore.instance.children.isNotEmpty
                  ? DemoStore.instance.children[_selected]['full_name']
                  : _selected == 1
                  ? 'Bé An'
                  : 'Bé Na'}',
            ),
          ),
        ],
      ),
    ),
  );
}

class OwnershipTransferScreen extends StatefulWidget {
  const OwnershipTransferScreen({required this.members, super.key});

  final List<SharingMember> members;

  @override
  State<OwnershipTransferScreen> createState() =>
      _OwnershipTransferScreenState();
}

class _OwnershipTransferScreenState extends State<OwnershipTransferScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SharingColors.background,
    appBar: _sharingAppBar(context, 'Chuyển quyền sở hữu'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _InfoBanner(
            icon: Icons.shield_outlined,
            text: 'Chủ sở hữu mới sẽ quản lý thành viên và quyền truy cập. Thông tin cốt lõi của bé vẫn được bảo vệ.',
          ),
          const SizedBox(height: 18),
          const Text(
            'Chọn chủ sở hữu mới',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SharingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          RadioGroup<int>(
            groupValue: _selected,
            onChanged: (value) =>
                setState(() => _selected = value ?? _selected),
            child: Column(
              children: [
                for (var index = 0; index < widget.members.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setState(() => _selected = index),
                      borderRadius: BorderRadius.circular(22),
                      child: _SurfaceCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            _AvatarBadge(
                              initial: widget.members[index].avatar,
                              owner: widget.members[index].isOwner,
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.members[index].name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: SharingColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    widget.members[index].role,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: SharingColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio<int>(
                              value: index,
                              activeColor: SharingColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: SharingColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text(
                    'Xác nhận bàn giao?',
                    style: TextStyle(fontWeight: FontWeight.w800, color: SharingColors.textPrimary),
                  ),
                  content: Text(
                    'Bạn sẽ chuyển quyền sở hữu cho ${widget.members[_selected].name}.',
                    style: const TextStyle(color: SharingColors.textPrimary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Quay lại', style: TextStyle(color: SharingColors.muted)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: SharingColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Gửi yêu cầu'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            style: _primaryButtonStyle(),
            child: const Text('Tiếp tục bàn giao'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Việc bàn giao cần được xác nhận để đảm bảo an toàn hồ sơ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: SharingColors.muted),
          ),
        ],
      ),
    ),
  );
}

PreferredSizeWidget _sharingAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
}) => AppBar(
  backgroundColor: SharingColors.background,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  leading: IconButton(
    onPressed: () => Navigator.of(context).maybePop(),
    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
    color: SharingColors.textPrimary,
  ),
  title: Text(
    title,
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: SharingColors.textPrimary,
      letterSpacing: -0.3,
    ),
  ),
  actions: actions,
  centerTitle: false,
);

ButtonStyle _primaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: SharingColors.primary,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(56),
  padding: const EdgeInsets.symmetric(horizontal: 10),
  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
  elevation: 2,
  shadowColor: SharingColors.primary.withValues(alpha: 0.35),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
);

InputDecoration _inputDecoration({
  required String label,
  required String hint,
  required IconData icon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: const TextStyle(color: SharingColors.textSecondary, fontSize: 14),
  hintStyle: const TextStyle(color: SharingColors.muted, fontSize: 14),
  prefixIcon: Icon(icon, color: SharingColors.primary),
  filled: true,
  fillColor: SharingColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: SharingColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: SharingColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: SharingColors.primary, width: 2),
  ),
);

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.attention = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool attention;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: attention ? SharingColors.attentionSoft : SharingColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: attention
            ? SharingColors.attention.withValues(alpha: 0.3)
            : SharingColors.cardBorder,
        width: 1.2,
      ),
      boxShadow: const [
        BoxShadow(
          color: SharingColors.cardShadow,
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: SharingColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ),
      if (trailing != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: SharingColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SharingColors.primaryDark,
            ),
          ),
        ),
    ],
  );
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.entries, required this.onCancel});
  final List<String> entries;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    attention: true,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, color: SharingColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SharingColors.attention.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: SharingColors.attention,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entries[i],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: SharingColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Đang chờ phản hồi',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SharingColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (_) => onCancel(entries[i]),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: SharingColors.danger),
                          SizedBox(width: 8),
                          Text('Hủy lời mời', style: TextStyle(color: SharingColors.danger)),
                        ],
                      ),
                    ),
                  ],
                  tooltip: 'Tùy chọn lời mời',
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});
  final SharingMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: _SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _AvatarBadge(initial: member.avatar, owner: member.isOwner, size: 44),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: SharingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${member.role} · ${member.contact}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SharingColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: SharingColors.muted,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.initial,
    this.owner = false,
    this.size = 42,
  });
  final String initial;
  final bool owner;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: owner ? SharingColors.attentionSoft : SharingColors.primarySoft,
      shape: BoxShape.circle,
      border: Border.all(
        color: owner ? SharingColors.attention : SharingColors.primary.withValues(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: SharingColors.cardShadow,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w800,
        color: owner ? SharingColors.attention : SharingColors.primaryDark,
      ),
    ),
  );
}

class _OwnerPrivacyNote extends StatelessWidget {
  const _OwnerPrivacyNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: SharingColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SharingColors.primary.withValues(alpha: 0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 18, color: SharingColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Thông tin cốt lõi và quyền mời, xóa hồ sơ chỉ dành cho chủ sở hữu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: SharingColors.primaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyMembersCard extends StatelessWidget {
  const _EmptyMembersCard();

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    child: Center(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: SharingColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_add_outlined,
              size: 28,
              color: SharingColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có thành viên nào được mời.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SharingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mời người thân cùng theo dõi các chỉ số và nhật ký của bé.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: SharingColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PersonSummaryCard extends StatelessWidget {
  const _PersonSummaryCard({required this.member});
  final SharingMember member;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      children: [
        _AvatarBadge(initial: member.avatar, owner: member.isOwner, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SharingColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${member.role} · ${member.contact}',
                style: const TextStyle(
                  fontSize: 12,
                  color: SharingColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: SharingColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: SharingColors.primary,
            size: 20,
          ),
        ),
      ],
    ),
  );
}

IconData _moduleIcon(String module) => switch (module) {
  'Tăng trưởng' => Icons.show_chart_rounded,
  'Đánh giá' => Icons.fact_check_outlined,
  'Tiêm chủng' => Icons.vaccines_outlined,
  'Mọc răng' => Icons.sentiment_satisfied_alt_rounded,
  'Nhật ký' => Icons.menu_book_outlined,
  'Hoạt động' => Icons.directions_run_rounded,
  _ => Icons.extension_outlined,
};

class _InviteHeaderCard extends StatelessWidget {
  const _InviteHeaderCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          SharingColors.heroStart,
          SharingColors.heroEnd,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: SharingColors.cardShadow,
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: const Row(
      children: [
        Icon(
          Icons.volunteer_activism_outlined,
          size: 30,
          color: SharingColors.primary,
        ),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Mời người thân cùng đồng hành trong hành trình phát triển của bé.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: SharingColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: SharingColors.cardShadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? SharingColors.primaryDark : SharingColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? SharingColors.primarySoft : SharingColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? SharingColors.primary : SharingColors.border,
          width: selected ? 1.5 : 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? SharingColors.primaryDark : SharingColors.textSecondary,
        ),
      ),
    ),
  );
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.onCopy, this.childId});
  final String? childId;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: SharingColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            size: 40,
            color: SharingColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Mã mời test · ${_demoSharingChild(childId)?['full_name'] ?? 'Bé An'}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SharingColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: SharingColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SharingColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            _demoSharingCode(childId),
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w900,
              color: SharingColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock_outlined, size: 14, color: SharingColors.muted),
            SizedBox(width: 4),
            Text(
              'Mã bảo mật · Tự hết hạn sau 7 ngày',
              style: TextStyle(fontSize: 12, color: SharingColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Sao chép mã mời'),
          style: OutlinedButton.styleFrom(
            foregroundColor: SharingColors.primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: SharingColors.border),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SharingColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SharingColors.primary.withValues(alpha: 0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: SharingColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: SharingColors.primaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InviteDetailsCard extends StatelessWidget {
  const _InviteDetailsCard({this.childId});
  final String? childId;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _DetailLine(
          icon: Icons.child_care_rounded,
          label: 'Hồ sơ được chia sẻ',
          value: _demoSharingChild(childId) == null
              ? 'Bé An · 24 tháng'
              : '${_demoSharingChild(childId)!['full_name']} · ${DemoStore.instance.ageLabel(_demoSharingChild(childId)!)}',
        ),
        const Divider(height: 22, color: SharingColors.border),
        _DetailLine(
          icon: Icons.person_outline_rounded,
          label: 'Người mời',
          value: DemoStore.instance.signedIn
              ? DemoStore.instance.parent['fullName'] as String
              : 'Nguyễn Minh Anh',
        ),
        const Divider(height: 22, color: SharingColors.border),
        const _DetailLine(
          icon: Icons.visibility_outlined,
          label: 'Quyền ban đầu',
          value: 'Xem và ghi nhật ký',
        ),
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: SharingColors.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: SharingColors.textSecondary),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: SharingColors.textPrimary,
        ),
      ),
    ],
  );
}

class _SharingBottomBar extends StatelessWidget {
  const _SharingBottomBar({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SharingColors.surface,
      border: const Border(top: BorderSide(color: SharingColors.border)),
      boxShadow: const [
        BoxShadow(
          color: SharingColors.cardShadow,
          blurRadius: 16,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: child,
      ),
    ),
  );
}

class _PermissionZone extends StatelessWidget {
  const _PermissionZone({
    required this.level,
    required this.modules,
    required this.onDrop,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onTapModule,
  });
  final AccessLevel level;
  final List<String> modules;
  final ValueChanged<String> onDrop;
  final void Function(BuildContext, DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<String>? onTapModule;

  @override
  Widget build(BuildContext context) => DragTarget<String>(
    key: ValueKey('permission-zone-${level.name}'),
    onWillAcceptWithDetails: (details) =>
        _modules.contains(details.data) && !modules.contains(details.data),
    onAcceptWithDetails: (details) => onDrop(details.data),
    builder: (context, candidates, rejected) {
      final hovering = candidates.isNotEmpty;
      final (title, icon, color, bgColor) = switch (level) {
        AccessLevel.none => (
          'Chưa cấp quyền',
          Icons.lock_outline_rounded,
          SharingColors.muted,
          const Color(0xFFF7F8F5),
        ),
        AccessLevel.view => (
          'Chỉ xem',
          Icons.visibility_outlined,
          SharingColors.primary,
          SharingColors.primarySoft,
        ),
        AccessLevel.edit => (
          'Xem & sửa',
          Icons.edit_note_rounded,
          SharingColors.primaryDark,
          const Color(0xFFE4F0D3),
        ),
      };

      return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hovering ? color.withValues(alpha: 0.15) : SharingColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hovering ? color : SharingColors.cardBorder,
            width: hovering ? 2.0 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: SharingColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${modules.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (modules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    hovering ? 'Thả để chuyển vào vùng này' : 'Chưa có mục nào trong vùng này',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SharingColors.muted,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final module in modules)
                    LongPressDraggable<String>(
                      onDragUpdate: (details) => onDragUpdate(context, details),
                      onDragEnd: (_) => onDragEnd(),
                      key: ValueKey('permission-item-$module'),
                      data: module,
                      maxSimultaneousDrags: 1,
                      feedback: Material(
                        color: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 48,
                          ),
                          child: _PermissionItem(
                            module: module,
                            color: color,
                            bgColor: bgColor,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _PermissionItem(
                          module: module,
                          color: color,
                          bgColor: bgColor,
                        ),
                      ),
                      child: Semantics(
                        label:
                            '$module, $title. Chạm để chọn quyền, hoặc nhấn giữ để kéo.',
                        child: InkWell(
                          onTap: () => onTapModule?.call(module),
                          borderRadius: BorderRadius.circular(14),
                          child: _PermissionItem(
                            module: module,
                            color: color,
                            bgColor: bgColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.module,
    required this.color,
    required this.bgColor,
  });
  final String module;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 46),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_moduleIcon(module), size: 18, color: color),
        const SizedBox(width: 7),
        Text(
          module,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color == SharingColors.muted
                ? SharingColors.textPrimary
                : color,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.drag_indicator_rounded,
          size: 16,
          color: color.withValues(alpha: 0.5),
        ),
      ],
    ),
  );
}

class _SharingHeroCard extends StatelessWidget {
  const _SharingHeroCard({
    this.childId,
    required this.usedSlots,
    this.totalSlots = 3,
  });

  final String? childId;
  final int usedSlots;
  final int totalSlots;

  @override
  Widget build(BuildContext context) {
    final childData = _demoSharingChild(childId);
    final childName = childData?['full_name'] as String? ?? 'Bé An';
    final remaining = (totalSlots - usedSlots).clamp(0, totalSlots);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            SharingColors.heroStart,
            SharingColors.heroEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: SharingColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SharingColors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: SharingColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: SharingColors.primaryDark,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      childData != null
                          ? DemoStore.instance.ageLabel(childData)
                          : 'Đang theo dõi phát triển',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: SharingColors.primaryDark.withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: SharingColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: SharingColors.primary,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Bảo mật',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SharingColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Còn $remaining vị trí chia sẻ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: remaining > 0
                          ? SharingColors.primary
                          : SharingColors.danger,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(totalSlots, (index) {
                    final isFilled = index < usedSlots;
                    return Container(
                      margin: const EdgeInsets.only(left: 3),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? SharingColors.primary
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFilled
                              ? SharingColors.primary
                              : SharingColors.border,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        isFilled
                            ? Icons.check_rounded
                            : Icons.person_add_alt_outlined,
                        size: 11,
                        color: isFilled ? Colors.white : SharingColors.muted,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
