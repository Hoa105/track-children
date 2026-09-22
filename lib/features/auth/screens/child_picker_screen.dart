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
import '../../../services/child_service.dart';
import '../../../services/service_locator.dart';

class ChildPickerScreen extends StatefulWidget {
  const ChildPickerScreen({super.key});

  @override
  State<ChildPickerScreen> createState() => _ChildPickerScreenState();
}

class _ChildPickerScreenState extends State<ChildPickerScreen> {
  final ChildService _service = ServiceLocator.childService;
  List<Child>? _children;

  @override
  void initState() {
    super.initState();
    _service.getChildren().then((c) => setState(() => _children = c));
  }

  @override
  Widget build(BuildContext context) {
    final children = _children;
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
                      child: ListView.separated(
                        itemCount: children.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final child = children[i];
                          final now = DateTime.now();
                          final subtitle = i == 0
                              ? '${child.ageLabel(now)} · ${child.gender.label}, Đánh giá gần nhất 02/08 · 22/25 mốc'
                              : '${child.ageLabel(now)} · ${child.gender.label}, Chưa đo tăng trưởng tháng này';
                          return CardContainer(
                            onTap: () => context.go(AppRoutes.home),
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
                        },
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
}
