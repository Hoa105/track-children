import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../core/widgets/primary_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGreenLighter,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(),
              const IllustrationPlaceholder(label: 'mẹ bế con', height: 200),
              const SizedBox(height: AppSpacing.xxl),
              Text('Bé Lớn Khôn', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Đồng hành cùng mẹ theo dõi từng bước phát triển của bé',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Bắt đầu hành trình',
                onPressed: () => context.push(AppRoutes.onboarding),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.push(AppRoutes.login),
                child: Text('Đã có tài khoản? Đăng nhập', style: AppTextStyles.bodySecondary),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
