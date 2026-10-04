import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../core/widgets/primary_button.dart';

class _OnboardingPage {
  final String illustration;
  final String title;
  final String body;
  const _OnboardingPage(this.illustration, this.title, this.body);
}

const _pages = [
  _OnboardingPage(
    'theo dõi tăng trưởng',
    'Theo dõi tăng trưởng theo chuẩn WHO',
    'Ghi lại cân nặng, chiều cao, vòng đầu và xem biểu đồ bách phân vị của bé.',
  ),
  _OnboardingPage(
    'đánh giá phát triển',
    'Đánh giá mốc phát triển 4 lĩnh vực',
    'Vận động thô, vận động tinh, ngôn ngữ, xã hội – cảm xúc, chỉ trong vài phút.',
  ),
  _OnboardingPage(
    'hoạt động và nhật ký',
    'Gợi ý hoạt động và ghi nhật ký mỗi ngày',
    'Hoạt động phù hợp độ tuổi và một cuốn nhật ký lưu giữ những khoảnh khắc đáng nhớ.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.ease);
    } else {
      context.push(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.login),
                  child: const Text('Bỏ qua'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IllustrationPlaceholder(label: page.illustration, height: 200),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(page.title, textAlign: TextAlign.center, style: AppTextStyles.h2),
                        const SizedBox(height: AppSpacing.sm),
                        Text(page.body, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Theme.of(context).colorScheme.primary : const Color(0xFFE1E8E4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: PrimaryButton(
                label: _page < _pages.length - 1 ? 'Tiếp tục' : 'Bắt đầu',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
