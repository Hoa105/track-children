import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import '../../services/sharing_api.dart';

/// Tên hiển thị của từng mục dữ liệu được phân quyền khi chia sẻ.
const sharingScopeLabels = <String, String>{
  'growth': 'Tăng trưởng',
  'assessment': 'Đánh giá',
  'vaccination': 'Tiêm chủng',
  'teething': 'Mọc răng',
  'diary': 'Nhật ký',
  'activities': 'Hoạt động',
};

String sharingLevelLabel(String level) => switch (level) {
  'edit' => 'Xem & sửa',
  'view' => 'Chỉ xem',
  _ => 'Không xem',
};

/// Tóm tắt quyền, vd. "Xem & sửa: Nhật ký · Chỉ xem: Tăng trưởng, Tiêm chủng".
String sharingPermissionSummary(Map<String, String> permissions) {
  List<String> labels(String level) => [
    for (final scope in sharingScopes)
      if (permissions[scope] == level) sharingScopeLabels[scope]!,
  ];
  final edit = labels('edit'), view = labels('view');
  return [
    if (edit.isNotEmpty) 'Xem & sửa: ${edit.join(', ')}',
    if (view.isNotEmpty) 'Chỉ xem: ${view.join(', ')}',
  ].join(' · ').ifEmpty('Chưa được cấp quyền xem mục nào');
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// Lời mời đang chờ + các hồ sơ bé người khác chia sẻ với tài khoản này.
class SharedWithMeScreen extends StatefulWidget {
  const SharedWithMeScreen({super.key, this.api});
  final SharingApi? api;

  @override
  State<SharedWithMeScreen> createState() => _SharedWithMeScreenState();
}

class _SharedWithMeScreenState extends State<SharedWithMeScreen> {
  late final SharingApi _api = widget.api ?? SharingApi();
  List<IncomingInvitation> _invitations = [];
  bool _loading = true;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invitations = await _api.incoming();
      await DemoStore.instance.reloadAuthenticatedChildren();
      if (!mounted) return;
      setState(() => _invitations = invitations);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = sharingErrorMessage(error, 'Chưa tải được lời mời.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(IncomingInvitation invitation, bool accept) async {
    setState(() => _busy.add(invitation.id));
    try {
      if (accept) {
        await _api.accept(invitation.id);
      } else {
        await _api.decline(invitation.id);
      }
      await _load();
      if (!mounted) return;
      _toast(
        accept
            ? 'Đã tham gia hồ sơ của ${invitation.childName}.'
            : 'Đã từ chối lời mời.',
      );
    } catch (error) {
      if (mounted) {
        _toast(sharingErrorMessage(error, 'Chưa xử lý được lời mời. Vui lòng thử lại.'));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(invitation.id));
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Hồ sơ được chia sẻ với tôi')),
    body: ListenableBuilder(
      listenable: DemoStore.instance,
      builder: (context, _) {
        final shared = [
          for (final child in DemoStore.instance.children)
            if (!DemoStore.instance.isChildOwner(child['id'] as String)) child,
        ];
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (_loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                _Banner(icon: Icons.error_outline_rounded, text: _error!),
                const SizedBox(height: 12),
              ],
              _Heading('Lời mời đang chờ', '${_invitations.length}'),
              if (_invitations.isEmpty && !_loading)
                const _Empty('Chưa có lời mời nào.'),
              for (final invitation in _invitations)
                _InvitationCard(
                  invitation: invitation,
                  busy: _busy.contains(invitation.id),
                  onAccept: () => _respond(invitation, true),
                  onDecline: () => _respond(invitation, false),
                ),
              const SizedBox(height: 20),
              _Heading('Bé được chia sẻ với tôi', '${shared.length}'),
              if (shared.isEmpty)
                const _Empty('Bạn chưa tham gia hồ sơ bé nào của người khác.'),
              for (final child in shared)
                _SharedChildCard(
                  child: child,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => SharedChildAccessScreen(
                        childId: child['id'] as String,
                        api: _api,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Quyền của tài khoản này với một bé được chia sẻ, và nút rời hồ sơ.
class SharedChildAccessScreen extends StatefulWidget {
  const SharedChildAccessScreen({super.key, required this.childId, this.api});
  final String childId;
  final SharingApi? api;

  @override
  State<SharedChildAccessScreen> createState() =>
      _SharedChildAccessScreenState();
}

class _SharedChildAccessScreenState extends State<SharedChildAccessScreen> {
  late final SharingApi _api = widget.api ?? SharingApi();
  bool _leaving = false;

  Future<void> _leave(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rời khỏi hồ sơ của $name?'),
        content: const Text(
          'Bạn sẽ không xem hay ghi được dữ liệu của bé nữa. '
          'Chủ hồ sơ có thể mời bạn tham gia lại sau.',
        ),
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
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _api.leave(widget.childId);
      await DemoStore.instance.reloadAuthenticatedChildren();
      messenger.showSnackBar(
        SnackBar(content: Text('Đã rời khỏi hồ sơ của $name.')),
      );
      navigator.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _leaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              sharingErrorMessage(error, 'Chưa rời được hồ sơ. Vui lòng thử lại.'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = DemoStore.instance.childById(widget.childId);
    final name = child?['full_name'] as String? ?? 'bé';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Quyền của bạn · $name')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _Banner(
            icon: Icons.lock_outline_rounded,
            text:
                'Bạn đang được chia sẻ hồ sơ này. Chỉ chủ hồ sơ mới sửa thông tin bé, '
                'mời thêm người và thay đổi quyền.',
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              children: [
                for (final scope in sharingScopes) ...[
                  if (scope != sharingScopes.first)
                    const Divider(height: 1, color: AppColors.border),
                  _PermissionRow(
                    label: sharingScopeLabels[scope]!,
                    level: DemoStore.instance.childAccess(widget.childId, scope),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('leave-shared-child'),
            onPressed: _leaving || child == null ? null : () => _leave(name),
            icon: const Icon(Icons.logout_rounded),
            label: Text(_leaving ? 'Đang rời hồ sơ…' : 'Rời khỏi hồ sơ bé'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB44B42),
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });
  final IncomingInvitation invitation;
  final bool busy;
  final VoidCallback onAccept, onDecline;

  @override
  Widget build(BuildContext context) {
    final days = invitation.expiresAt.difference(DateTime.now()).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${invitation.inviterName} mời bạn cùng chăm sóc ${invitation.childName}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vai trò của bạn: ${relationshipLabel(invitation.relationship)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                sharingPermissionSummary(invitation.permissions),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                days <= 0 ? 'Hết hạn trong hôm nay' : 'Hết hạn sau $days ngày',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      child: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onAccept,
                      child: Text(busy ? 'Đang xử lý…' : 'Chấp nhận'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedChildCard extends StatelessWidget {
  const _SharedChildCard({required this.child, required this.onTap});
  final Map<String, dynamic> child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = child['id'] as String;
    final permissions = {
      for (final scope in sharingScopes)
        scope: DemoStore.instance.childAccess(id, scope),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.child_care_rounded, color: AppColors.primary),
          ),
          title: Text(child['full_name'] as String? ?? 'Bé'),
          subtitle: Text(sharingPermissionSummary(permissions)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.level});
  final String label, level;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
        Icon(
          switch (level) {
            'edit' => Icons.edit_outlined,
            'view' => Icons.visibility_outlined,
            _ => Icons.visibility_off_outlined,
          },
          size: 18,
          color: level == 'none' ? AppColors.textSecondary : AppColors.primary,
        ),
        const SizedBox(width: 6),
        Text(
          sharingLevelLabel(level),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.trailing);
  final String title, trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(trailing, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
