import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';

enum AccessLevel { none, view, edit }

Map<String, dynamic>? _demoSharingChild(String? id) =>
    id == null ? DemoStore.instance.child : DemoStore.instance.childById(id);
String _demoSharingCode(String? id) =>
    id == null ? 'AN-4K9P-72' : 'DEMO-${id.toUpperCase()}';

List<SharingMember> demoSharingMembers(String id) => [
  for (final m in DemoStore.instance.childById(id)?['members'] as List? ?? [])
    SharingMember(
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
    required this.name,
    required this.role,
    required this.contact,
    required this.avatar,
    Map<String, AccessLevel>? permissions,
  }) : permissions = permissions ?? _defaultPermissions();

  final String name;
  final String role;
  final String contact;
  final String avatar;
  final Map<String, AccessLevel> permissions;

  static Map<String, AccessLevel> _defaultPermissions() => {
    for (final module in _modules) module: AccessLevel.none,
  };
}

const _modules = <String>[
  'Lượng sữa',
  'Tiêm chủng',
  'Mọc răng',
  'Nhật ký',
  'Hoạt động',
];

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
              module: module == 'Lượng sữa' || module == 'Nhật ký'
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

  Future<void> _persist() async {
    if (_childId == null) return;
    try {
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
      if (mounted) _toast('Chưa lưu được dữ liệu chia sẻ test.');
    }
  }

  Future<void> _openPermissions(SharingMember member) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharingPermissionsScreen(
          member: member,
          onRevoke: () {
            setState(() => _members.remove(member));
            _persist();
            Navigator.of(context).pop();
            _toast('Đã thu hồi quyền truy cập của ${member.name}.');
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
          onSendInvite: (contact) {
            setState(() => _pending.add('Lời mời · $contact'));
            _persist();
          },
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: _sharingAppBar(
      context,
      _childId == null
          ? 'Chia sẻ hồ sơ bé'
          : 'Chia sẻ · ${DemoStore.instance.childById(_childId)?['full_name'] ?? 'Hồ sơ bé'}',
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SharingIntroCard(),
          const SizedBox(height: 14),
          _OwnerCard(),
          const SizedBox(height: 12),
          _MemberCapacityCard(count: _members.length + _pending.length),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Mời người cùng chăm bé',
                  subtitle: 'Email hoặc SĐT',
                  onTap: _invite,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Mã mời',
                  subtitle: 'Hiệu lực 7 ngày',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => InviteMemberScreen(
                        childId: _childId,
                        startWithCode: true,
                        onSendInvite: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
              onCancel: (entry) {
                setState(() => _pending.remove(entry));
                _persist();
                _toast('Đã hủy lời mời.');
              },
            ),
          ],
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
          const SizedBox(height: 12),
          _OwnerPrivacyNote(),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _transferOwnership,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Chuyển quyền sở hữu hồ sơ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
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
  late final Map<String, AccessLevel> _permissions =
      Map<String, AccessLevel>.from(widget.member.permissions);

  Future<void> _confirmAction({required bool revoke}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(revoke ? 'Thu hồi quyền truy cập?' : 'Rời khỏi hồ sơ bé?'),
        content: Text(
          revoke
              ? '${widget.member.name} sẽ không còn xem được thông tin của bé.'
              : 'Bạn sẽ không còn xem được thông tin của bé An.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB84C4C),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: _sharingAppBar(context, 'Quyền truy cập'),
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kéo từng mục vào vùng quyền phù hợp. Mục để ngoài hai vùng cấp quyền sẽ không được xem hoặc chỉnh sửa.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final level in AccessLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PermissionDropZone(
                level: level,
                modules: _modules
                    .where((module) => _permissions[module] == level)
                    .toList(),
                onModuleDropped: (module) =>
                    setState(() => _permissions[module] = level),
              ),
            ),
          const SizedBox(height: 6),
          const _OwnerPrivacyNote(),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              widget.member.permissions
                ..clear()
                ..addAll(_permissions);
              Navigator.of(context).pop();
            },
            style: _primaryButtonStyle(),
            child: const Text('Lưu thay đổi'),
          ),
          if (widget.onRevoke != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _confirmAction(revoke: true),
              icon: const Icon(Icons.person_remove_alt_1_rounded),
              label: const Text('Thu hồi quyền thành viên'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB84C4C),
              ),
            ),
          ],
          if (widget.onLeave != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _confirmAction(revoke: false),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Rời khỏi hồ sơ bé'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB84C4C),
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

  final ValueChanged<String> onSendInvite;
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

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  void _send() {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập email hoặc số điện thoại trước nhé.'),
        ),
      );
      return;
    }
    widget.onSendInvite(contact);
    setState(() => _inviteCreated = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tạo lời mời, hiệu lực trong 7 ngày.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
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
              color: const Color(0xFFEDEDE5),
              borderRadius: BorderRadius.circular(14),
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
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ContactChip(
                        label: 'Email',
                        selected: !_usePhone,
                        onTap: () => setState(() => _usePhone = false),
                      ),
                      const SizedBox(width: 8),
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
                          : Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mối quan hệ với bé',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StaticPill('Ông bà', selected: true),
                      _StaticPill('Người chăm sóc'),
                      _StaticPill('Bảo mẫu'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _InfoBanner(
              icon: Icons.schedule_rounded,
              text: 'Lời mời có hiệu lực trong 7 ngày. Bạn có thể hủy bất cứ lúc nào.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _send,
              style: _primaryButtonStyle(),
              icon: const Icon(Icons.send_rounded),
              label: Text(_inviteCreated ? 'Gửi lời mời khác' : 'Gửi lời mời'),
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
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
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
    backgroundColor: AppColors.background,
    appBar: _sharingAppBar(context, 'Lời mời tham gia'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
        children: [
          const SizedBox(height: 12),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Bạn được mời cùng chăm sóc ${_demoSharingChild(widget.childId)?['full_name'] ?? 'bé An'}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DemoStore.instance.signedIn ? DemoStore.instance.parent['fullName'] : 'Nguyễn Minh Anh'} · lời mời mô phỏng cục bộ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                ),
              );
            },
            style: _primaryButtonStyle(),
            child: Text(_accepted ? 'Đã tham gia hồ sơ' : 'Chấp nhận lời mời'),
          ),
          if (_accepted) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const SharedProfileSwitcherScreen(),
                ),
              ),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Chuyển hồ sơ bé'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              if (!_accepted) {
                Navigator.of(context).pop();
                return;
              }
              final leave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Rời khỏi hồ sơ bé?'),
                  content: const Text('Bạn có thể được mời tham gia lại sau.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Ở lại'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Rời hồ sơ'),
                    ),
                  ],
                ),
              );
              if (leave == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(_accepted ? 'Rời khỏi hồ sơ bé' : 'Từ chối lời mời'),
          ),
          const Center(
            child: Text(
              'Mã mời hết hạn sau 7 ngày',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
    backgroundColor: AppColors.background,
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
                borderRadius: BorderRadius.circular(20),
                child: _SurfaceCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: i == 1
                              ? const Color(0xFFFFE9D8)
                              : AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.child_care_rounded,
                          color: i == 1
                              ? const Color(0xFFB66B4F)
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
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
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<int>(
                        value: i,
                        groupValue: _selected,
                        activeColor: AppColors.primary,
                        onChanged: (value) =>
                            setState(() => _selected = value!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
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
    backgroundColor: AppColors.background,
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(widget.members.length, (index) {
            final member = widget.members[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _selected = index),
                borderRadius: BorderRadius.circular(20),
                child: _SurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _AvatarBadge(initial: member.avatar),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              member.role,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<int>(
                        value: index,
                        groupValue: _selected,
                        activeColor: AppColors.primary,
                        onChanged: (value) =>
                            setState(() => _selected = value!),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Xác nhận bàn giao?'),
                  content: Text(
                    'Bạn sẽ chuyển quyền sở hữu cho ${widget.members[_selected].name}.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Quay lại'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
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
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

PreferredSizeWidget _sharingAppBar(BuildContext context, String title) =>
    AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        color: AppColors.textPrimary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
    );

ButtonStyle _primaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(50),
  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

InputDecoration _inputDecoration({
  required String label,
  required String hint,
  required IconData icon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  prefixIcon: Icon(icon, color: AppColors.primary),
  filled: true,
  fillColor: const Color(0xFFFCFBF8),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
  ),
);

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFF1EFE8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08194C3C),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SharingIntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFE9F2E6), Color(0xFFF8F4E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.family_restroom_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bên nhau chăm sóc bé',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Chia sẻ hành trình lớn khôn với gia đình.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OwnerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      children: [
        _AvatarBadge(
          initial: DemoStore.instance.signedIn
              ? (DemoStore.instance.parent['fullName'] as String).substring(
                  0,
                  1,
                )
              : 'A',
          owner: true,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DemoStore.instance.signedIn
                    ? DemoStore.instance.parent['fullName'] as String
                    : 'Nguyễn Minh Anh',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Chủ sở hữu · Bạn',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Toàn quyền',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MemberCapacityCard extends StatelessWidget {
  const _MemberCapacityCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.people_alt_outlined,
              size: 19,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Thành viên được mời',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$count/3',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: count / 3,
            minHeight: 7,
            backgroundColor: AppColors.primarySoft,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Còn ${3 - count} vị trí chia sẻ',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0EEE7)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
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
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      if (trailing != null)
        Text(
          trailing!,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  color: Color(0xFFB38B4A),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entries[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Đang chờ · Còn hiệu lực 6 ngày',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (_) => onCancel(entries[i]),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'cancel', child: Text('Hủy lời mời')),
                  ],
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.textSecondary,
                  ),
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
      borderRadius: BorderRadius.circular(21),
      child: _SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _AvatarBadge(initial: member.avatar),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${member.role} · ${member.contact}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Đang hoạt động',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.initial, this.owner = false});
  final String initial;
  final bool owner;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: owner ? const Color(0xFFFFE9D8) : AppColors.primarySoft,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: owner ? const Color(0xFFB66B4F) : AppColors.primaryDark,
      ),
    ),
  );
}

class _OwnerPrivacyNote extends StatelessWidget {
  const _OwnerPrivacyNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F5E9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 17, color: AppColors.primary),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Thông tin cốt lõi và quyền mời, xóa hồ sơ chỉ dành cho chủ sở hữu.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(height: 1.45, color: AppColors.primaryDark),
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
    child: Text(
      'Chưa có thành viên nào được mời.',
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.textSecondary),
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
        _AvatarBadge(initial: member.avatar),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${member.role} · ${member.contact}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.verified_user_outlined,
          color: AppColors.primary,
          size: 20,
        ),
      ],
    ),
  );
}

class _PermissionDropZone extends StatelessWidget {
  const _PermissionDropZone({
    required this.level,
    required this.modules,
    required this.onModuleDropped,
  });

  final AccessLevel level;
  final List<String> modules;
  final ValueChanged<String> onModuleDropped;

  @override
  Widget build(BuildContext context) => DragTarget<String>(
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) => onModuleDropped(details.data),
    builder: (context, candidates, rejected) {
      final isHovering = candidates.isNotEmpty;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isHovering ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHovering ? AppColors.primary : AppColors.border,
            width: isHovering ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (level) {
                    AccessLevel.none => Icons.block_outlined,
                    AccessLevel.view => Icons.visibility_outlined,
                    AccessLevel.edit => Icons.edit_note_rounded,
                  },
                  color: level == AccessLevel.none
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (level) {
                      AccessLevel.none => 'Chưa cấp quyền',
                      AccessLevel.view => 'Xem',
                      AccessLevel.edit => 'Xem & sửa',
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${modules.length} mục',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (modules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  isHovering ? 'Thả mục vào đây' : 'Kéo mục vào vùng này',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final module in modules)
                    _DraggablePermissionToken(module: module, level: level),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class _DraggablePermissionToken extends StatelessWidget {
  const _DraggablePermissionToken({required this.module, required this.level});

  final String module;
  final AccessLevel level;

  @override
  Widget build(BuildContext context) {
    final feedback = Material(
      color: Colors.transparent,
      child: _PermissionToken(module: module, level: level, elevated: true),
    );
    final placeholder = Opacity(
      opacity: 0.35,
      child: _PermissionToken(module: module, level: level),
    );
    final token = _PermissionToken(module: module, level: level);

    if (kIsWeb) {
      return Draggable<String>(
        data: module,
        feedback: feedback,
        childWhenDragging: placeholder,
        child: token,
      );
    }

    return LongPressDraggable<String>(
      data: module,
      feedback: feedback,
      childWhenDragging: placeholder,
      child: token,
    );
  }
}

class _PermissionToken extends StatelessWidget {
  const _PermissionToken({
    required this.module,
    required this.level,
    this.elevated = false,
  });

  final String module;
  final AccessLevel level;
  final bool elevated;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$module, ${_accessLabel(level)}. Kéo để di chuyển.',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: level == AccessLevel.none
            ? const Color(0xFFF3F2ED)
            : const Color(0xFFE8F2E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_moduleIcon(module), size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            module,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.drag_indicator_rounded,
            size: 15,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}

IconData _moduleIcon(String module) => switch (module) {
  'Lượng sữa' => Icons.local_drink_outlined,
  'Tiêm chủng' => Icons.vaccines_outlined,
  'Mọc răng' => Icons.sentiment_satisfied_alt_rounded,
  'Nhật ký' => Icons.menu_book_outlined,
  _ => Icons.extension_outlined,
};

String _accessLabel(AccessLevel level) => switch (level) {
  AccessLevel.none => 'Không xem',
  AccessLevel.view => 'Xem',
  AccessLevel.edit => 'Xem & sửa',
};

class _InviteHeaderCard extends StatelessWidget {
  const _InviteHeaderCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFFE9F2E6),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      children: [
        Icon(
          Icons.volunteer_activism_outlined,
          size: 28,
          color: AppColors.primary,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Mời người thân cùng đồng hành trong hành trình của bé.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
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
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
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
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : const Color(0xFFF8F7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _StaticPill extends StatelessWidget {
  const _StaticPill(this.label, {this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: selected ? AppColors.primarySoft : const Color(0xFFF8F7F2),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: selected ? AppColors.primary : AppColors.border,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
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
    child: Column(
      children: [
        const Icon(
          Icons.qr_code_2_rounded,
          size: 76,
          color: AppColors.primaryDark,
        ),
        const SizedBox(height: 8),
        Text(
          'Mã mời test · ${_demoSharingChild(childId)?['full_name'] ?? 'Bé An'}',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7EF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _demoSharingCode(childId),
            style: TextStyle(
              fontSize: 22,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Mã bảo mật · Tự hết hạn sau 7 ngày',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 17),
          label: const Text('Sao chép mã mời'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
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
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F5E9),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              height: 1.45,
              color: AppColors.primaryDark,
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
    child: Column(
      children: [
        _DetailLine(
          icon: Icons.child_care_rounded,
          label: 'Hồ sơ được chia sẻ',
          value: _demoSharingChild(childId) == null
              ? 'Bé An · 24 tháng'
              : '${_demoSharingChild(childId)!['full_name']} · ${DemoStore.instance.ageLabel(_demoSharingChild(childId)!)}',
        ),
        Divider(height: 20, color: AppColors.border),
        _DetailLine(
          icon: Icons.person_outline_rounded,
          label: 'Người mời',
          value: DemoStore.instance.signedIn
              ? DemoStore.instance.parent['fullName'] as String
              : 'Nguyễn Minh Anh',
        ),
        Divider(height: 20, color: AppColors.border),
        _DetailLine(
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
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}
