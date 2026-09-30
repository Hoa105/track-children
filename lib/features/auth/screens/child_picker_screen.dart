import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/child.dart';
import '../../../models/child_share.dart';
import '../../../services/child_service.dart';
import '../../../services/service_locator.dart';
import '../../sharing/screens/shared_with_me_screen.dart';

class ChildPickerScreen extends StatefulWidget {
  const ChildPickerScreen({super.key});

  @override
  State<ChildPickerScreen> createState() => _ChildPickerScreenState();
}

class _ChildPickerScreenState extends State<ChildPickerScreen> {
  final ChildService _service = ServiceLocator.childService;
  List<Child>? _children;
  List<SharedChildAccess> _shared = const [];

  @override
  void initState() {
    super.initState();
    _service.getChildren().then((c) => setState(() => _children = c));
    _loadShared();
  }

  Future<void> _loadShared() async {
    final shared = await ServiceLocator.sharingService.getSharedWithMe();
    if (mounted) setState(() => _shared = shared);
  }

  Future<void> _openSharedWithMe() async {
    await context.push(AppRoutes.sharedWithMe);
    await _loadShared();
  }

  @override
  Widget build(BuildContext context) {
    final children = _children;
    final pendingCount = _shared.where((a) => a.status == ShareStatus.pending).length;
    final joinedShared = _shared.where((a) => a.status == ShareStatus.accepted).toList();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: children == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chọn bé để theo dõi', style: AppTextStyles.h1),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Tài khoản của mẹ có ${children.length} hồ sơ bé', style: AppTextStyles.bodySecondary),
                    const SizedBox(height: AppSpacing.xl),
                    Expanded(
                      child: ListView(
                        children: [
                          if (pendingCount > 0) ...[
                            CardContainer(
                              onTap: _openSharedWithMe,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              color: AppColors.amberSurfaceLight,
                              borderColor: AppColors.amberBorder,
                              child: Row(
                                children: [
                                  const Icon(Icons.mark_email_unread_outlined, color: AppColors.amberDark),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'Bạn có $pendingCount lời mời cùng theo dõi hồ sơ bé',
                                      style: AppTextStyles.body.copyWith(color: AppColors.amberHeadline),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.amberDark),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          for (var i = 0; i < children.length; i++) ...[
                            _childCard(children[i], i),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (joinedShared.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text('ĐƯỢC CHIA SẺ VỚI BẠN', style: AppTextStyles.captionBold),
                            const SizedBox(height: AppSpacing.sm),
                            for (final access in joinedShared) ...[
                              SharedChildTile(
                                access: access,
                                onTap: () {
                                  ServiceLocator.activeChild.selectShared(access);
                                  context.go(AppRoutes.home);
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoutes.childProfileNew),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('+ Thêm hồ sơ bé mới'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Nếu tài khoản chỉ có 1 hồ sơ bé, ứng dụng sẽ tự động chọn bé đó khi mẹ đăng nhập lần sau.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'Vào Trang chủ của bé',
                      onPressed: () => context.go(AppRoutes.home),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _childCard(Child child, int i) {
    final now = DateTime.now();
    final subtitle = i == 0
        ? '${child.ageLabel(now)} · ${child.gender.label}, Đánh giá gần nhất 02/08 · 22/25 mốc'
        : '${child.ageLabel(now)} · ${child.gender.label}, Chưa đo tăng trưởng tháng này';
    return CardContainer(
      onTap: () {
        ServiceLocator.activeChild.selectOwn(child);
        context.go(AppRoutes.home);
      },
      child: Row(
        children: [
          EmptyAvatar(label: child.name, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
