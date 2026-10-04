import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/child.dart';
import '../../../models/child_share.dart';
import '../../../services/auth_service.dart';
import '../../../services/service_locator.dart';
import '../../sharing/widgets/sharing_widgets.dart';

/// "Xóa tài khoản và dữ liệu" (F01.6). A child profile that other people
/// still follow can't just vanish with the account: the owner must either
/// hand it over (F23.11) or explicitly delete it — the request can't be
/// sent until every such profile has a decision.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

/// What happens to one owned child profile. [transferTo] null = delete it.
class _ProfileDecision {
  const _ProfileDecision.transfer(ChildShare this.transferTo);
  const _ProfileDecision.delete() : transferTo = null;

  final ChildShare? transferTo;
}

class _OwnedProfile {
  const _OwnedProfile(this.child, this.members, this.pendingInvites);

  final Child child;

  /// Joined members — the people a transfer can go to.
  final List<ChildShare> members;
  final int pendingInvites;

  bool get isShared => members.isNotEmpty;
}

const _reasons = ['Không còn sử dụng', 'Lo ngại về dữ liệu', 'Chuyển sang ứng dụng khác', 'Lý do khác'];

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordCtrl = TextEditingController();
  List<_OwnedProfile>? _profiles;
  int _sharedWithMeCount = 0;
  final Map<String, _ProfileDecision> _decisions = {};
  String? _reason;
  bool _understood = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sharing = ServiceLocator.sharingService;
    final children = await ServiceLocator.childService.getChildren();
    final profiles = <_OwnedProfile>[];
    for (final child in children) {
      final shares = await sharing.getShares(child.id);
      final members = shares.where((s) => s.status == ShareStatus.accepted).toList();
      profiles.add(_OwnedProfile(child, members, shares.length - members.length));
      // An ownership offer already sent from "Người cùng theo dõi" counts
      // as the decision for that profile.
      final offered = members.where((s) => s.transferPending).firstOrNull;
      if (offered != null) _decisions[child.id] = _ProfileDecision.transfer(offered);
    }
    final sharedWithMe = await sharing.getSharedWithMe();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _sharedWithMeCount = sharedWithMe.where((a) => a.status == ShareStatus.accepted).length;
    });
  }

  bool get _allDecided => _profiles!.where((p) => p.isShared).every((p) => _decisions.containsKey(p.child.id));

  bool get _canSubmit => !_submitting && _allDecided && _understood && _passwordCtrl.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final sharing = ServiceLocator.sharingService;
    final DateTime scheduledAt;
    try {
      scheduledAt = await ServiceLocator.authService.requestAccountDeletion(
        password: _passwordCtrl.text,
        reason: _reason,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.message}')));
      return;
    }
    // Send the ownership offers chosen here; drop any older offer that
    // pointed to someone else.
    for (final profile in _profiles!.where((p) => p.isShared)) {
      final target = _decisions[profile.child.id]!.transferTo;
      for (final m in profile.members.where((m) => m.transferPending && m.id != target?.id)) {
        await sharing.cancelOwnershipTransfer(m.id);
      }
      if (target != null && !target.transferPending) await sharing.requestOwnershipTransfer(target.id);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.schedule_rounded, color: AppColors.danger, size: 40),
        title: const Text('Đã gửi yêu cầu xóa tài khoản', textAlign: TextAlign.center),
        content: Text(
          'Tài khoản và dữ liệu sẽ bị xóa vào ngày ${DateFormat('dd/MM/yyyy').format(scheduledAt)}. '
          'Nếu đổi ý, bạn chỉ cần đăng nhập lại trước ngày này để hủy yêu cầu.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary,
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đăng xuất'))],
      ),
    );
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles;
    return Scaffold(
      appBar: AppBar(title: const Text('Xóa tài khoản')),
      body: profiles == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _stepTitle(1, 'Những gì sẽ bị xóa'),
                CardContainer(
                  color: AppColors.dangerSurfaceLight,
                  borderColor: AppColors.dangerSurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in [
                        'Tài khoản ${ServiceLocator.authService.currentUser.email} và thông tin cá nhân',
                        'Hồ sơ bé bạn là chủ mà không chuyển quyền cho ai, cùng toàn bộ dữ liệu của bé',
                        'Bài viết, bình luận, bài đã lưu ở Góc đồng hành và lịch sử hỏi Chatbot',
                        if (_sharedWithMeCount > 0)
                          'Quyền theo dõi $_sharedWithMeCount hồ sơ bé người khác chia sẻ với bạn',
                      ])
                        _bullet(line, Icons.remove_circle_outline_rounded, AppColors.danger),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ShareInfoNote(
                  icon: Icons.schedule_rounded,
                  text: 'Dữ liệu được xóa sau ${AuthService.deletionGracePeriod.inDays} ngày. '
                      'Trong thời gian này, đăng nhập lại sẽ hủy yêu cầu.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                _stepTitle(2, 'Hồ sơ bé của bạn'),
                if (profiles.isEmpty)
                  Text('Bạn chưa có hồ sơ bé nào.', style: AppTextStyles.caption)
                else
                  for (final p in profiles) ...[
                    _ProfileCard(
                      profile: p,
                      decision: _decisions[p.child.id],
                      onChanged: (d) => setState(() => _decisions[p.child.id] = d),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                if (profiles.any((p) => p.isShared))
                  const ShareInfoNote(
                    text: 'Người nhận cần chấp nhận trước ngày xóa tài khoản. '
                        'Nếu họ không nhận, hồ sơ bé sẽ bị xóa cùng tài khoản.',
                  ),
                const SizedBox(height: AppSpacing.xxl),
                _stepTitle(3, 'Xác nhận'),
                Text('Lý do (không bắt buộc)', style: AppTextStyles.bodySecondary),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final r in _reasons)
                      AppChip(
                        label: r,
                        selected: _reason == r,
                        onTap: () => setState(() => _reason = _reason == r ? null : r),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Nhập mật khẩu để xác nhận'),
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: () => setState(() => _understood = !_understood),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(value: _understood, onChanged: (v) => setState(() => _understood = v ?? false)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Tôi hiểu dữ liệu đã xóa không thể khôi phục.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!_allDecided)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Chọn cách xử lý cho các hồ sơ bé đang được chia sẻ ở bước 2.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                    ),
                  ),
                PrimaryButton(
                  label: _submitting ? 'Đang gửi…' : 'Gửi yêu cầu xóa tài khoản',
                  color: AppColors.danger,
                  onPressed: _canSubmit ? _submit : null,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
    );
  }

  Widget _stepTitle(int step, String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              child: Text('$step', style: AppTextStyles.captionBold.copyWith(color: Colors.white)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTextStyles.h3),
          ],
        ),
      );
}

Widget _bullet(String text, IconData icon, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary))),
        ],
      ),
    );

/// One owned profile: unshared ones are simply listed as deleted; shared
/// ones must pick "chuyển quyền cho …" or "xóa hồ sơ".
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.decision, required this.onChanged});

  final _OwnedProfile profile;
  final _ProfileDecision? decision;
  final ValueChanged<_ProfileDecision> onChanged;

  @override
  Widget build(BuildContext context) {
    final child = profile.child;
    final undecided = profile.isShared && decision == null;
    return CardContainer(
      borderColor: undecided ? AppColors.amberBorder : AppColors.border,
      color: undecided ? AppColors.amberSurfaceLight : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmptyAvatar(label: child.name, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name, style: AppTextStyles.titleMedium),
                    Text(
                      profile.isShared
                          ? '${profile.members.length} người cùng theo dõi'
                          : profile.pendingInvites > 0
                              ? 'Chưa ai tham gia · ${profile.pendingInvites} lời mời sẽ bị hủy'
                              : 'Không chia sẻ với ai',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (!profile.isShared)
                const SharePill(label: 'Sẽ bị xóa', color: AppColors.danger, background: AppColors.dangerSurface),
            ],
          ),
          if (profile.isShared) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              undecided ? 'Bắt buộc chọn trước khi xóa tài khoản:' : 'Cách xử lý:',
              style: AppTextStyles.captionBold.copyWith(color: undecided ? AppColors.amberDark : null),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final m in profile.members)
              _option(
                label: 'Chuyển quyền chủ cho ${m.displayName} (${m.role.label})',
                note: m.transferPending ? 'Đã gửi yêu cầu, đang chờ chấp nhận' : null,
                selected: decision?.transferTo?.id == m.id,
                onTap: () => onChanged(_ProfileDecision.transfer(m)),
              ),
            _option(
              label: 'Xóa hồ sơ bé và thu hồi quyền của mọi người',
              selected: decision != null && decision!.transferTo == null,
              danger: true,
              onTap: () => onChanged(const _ProfileDecision.delete()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _option({
    required String label,
    String? note,
    required bool selected,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smallRadius,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppColors.surface,
          border: Border.all(color: selected ? color : AppColors.border),
          borderRadius: AppRadius.smallRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? color : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body.copyWith(color: danger ? AppColors.danger : null)),
                  if (note != null) Text(note, style: AppTextStyles.caption.copyWith(color: AppColors.amberDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
