import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import '../../services/sharing_api.dart';
import '../../services/sharing_invitations.dart';

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
      SharingInvitations.instance.replace(invitations);
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
        _toast(
          sharingErrorMessage(
            error,
            'Chưa xử lý được lời mời. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(invitation.id));
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SettingsColors.background,
    appBar: AppBar(
      backgroundColor: SettingsColors.background,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
      title: const Text(
        'Hồ sơ được chia sẻ với tôi',
        style: TextStyle(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
    ),
    body: ListenableBuilder(
      listenable: DemoStore.instance,
      builder: (context, _) {
        final shared = [
          for (final child in DemoStore.instance.children)
            if (!DemoStore.instance.isChildOwner(child['id'] as String)) child,
        ];
        return RefreshIndicator(
          color: SettingsColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (_loading) ...[
                const LinearProgressIndicator(
                  color: SettingsColors.primary,
                  backgroundColor: SettingsColors.border,
                ),
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
        backgroundColor: SettingsColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Rời khỏi hồ sơ của $name?',
          style: const TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Bạn sẽ không còn xem hay cập nhật được thông tin chăm sóc của bé nữa. '
          'Chủ sở hữu có thể gửi lời mời bạn tham gia lại sau nếu cần.',
          style: TextStyle(color: SettingsColors.textPrimary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: SettingsColors.textSecondary,
            ),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB44545),
              foregroundColor: Colors.white,
            ),
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
        SnackBar(
          content: Text('Đã rời khỏi hồ sơ của $name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _leaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              sharingErrorMessage(
                error,
                'Chưa rời được hồ sơ. Vui lòng thử lại.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
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
      backgroundColor: SettingsColors.background,
      appBar: AppBar(
        backgroundColor: SettingsColors.background,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
        title: Text(
          'Quyền của bạn · $name',
          style: const TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const _Banner(
            icon: Icons.shield_outlined,
            text:
                'Bạn đang được chia sẻ quyền truy cập hồ sơ này. Chỉ chủ sở hữu mới có thể thay đổi thông tin bé, '
                'mời thêm thành viên hoặc chỉnh sửa phân quyền.',
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              children: [
                for (final scope in sharingScopes) ...[
                  if (scope != sharingScopes.first)
                    const Divider(height: 1, color: SettingsColors.border),
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
              foregroundColor: const Color(0xFFB44545),
              side: const BorderSide(color: Color(0xFFD57C7C)),
              backgroundColor: SettingsColors.surface,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SettingsColors.iconBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mail_rounded,
                      color: SettingsColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${invitation.inviterName} mời bạn cùng chăm sóc ${invitation.childName}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SettingsColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vai trò: ${relationshipLabel(invitation.relationship)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: SettingsColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: SettingsColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SettingsColors.border),
                ),
                child: Text(
                  sharingPermissionSummary(invitation.permissions),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SettingsColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                days <= 0 ? 'Hết hạn trong hôm nay' : 'Hết hạn sau $days ngày',
                style: const TextStyle(
                  fontSize: 12,
                  color: SettingsColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB44545),
                        side: const BorderSide(color: Color(0xFFD57C7C)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text(
                        'Từ chối',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: SettingsColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text(
                        busy ? 'Đang xử lý…' : 'Chấp nhận',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SettingsColors.iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.child_care_rounded,
              color: SettingsColors.textPrimary,
              size: 22,
            ),
          ),
          title: Text(
            child['full_name'] as String? ?? 'Bé',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: SettingsColors.textPrimary,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            sharingPermissionSummary(permissions),
            style: const TextStyle(
              color: SettingsColors.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: SettingsColors.textSecondary,
          ),
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: SettingsColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          switch (level) {
            'edit' => Icons.edit_outlined,
            'view' => Icons.visibility_outlined,
            _ => Icons.visibility_off_outlined,
          },
          size: 19,
          color: level == 'none'
              ? SettingsColors.textSecondary
              : SettingsColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          sharingLevelLabel(level),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: level == 'none'
                ? SettingsColors.textSecondary
                : SettingsColors.primaryDark,
          ),
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
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: SettingsColors.textSecondary,
              letterSpacing: .6,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: SettingsColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: SettingsColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: SettingsColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: SettingsColors.border),
    ),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: SettingsColors.textSecondary,
          fontSize: 14,
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SettingsColors.primarySoft,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SettingsColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: SettingsColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              color: SettingsColors.textPrimary,
              height: 1.45,
            ),
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
      color: SettingsColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: SettingsColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
