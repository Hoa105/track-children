import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/onboarding_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onLoginRequired, super.key});

  final VoidCallback onLoginRequired;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _pages = [
    _SplashPageData(
      image: 'assets/images/scenery/backgrounds/splash_screen_1.png',
      title: 'Chăm sóc bé dễ dàng hơn',
      description:
          'Theo dõi hành trình lớn khôn của con qua từng cột mốc phát triển.',
    ),
    _SplashPageData(
      image: 'assets/images/scenery/backgrounds/splash_screen_2.png',
      title: 'Đồng hành cùng bé mỗi ngày',
      description: 'Theo dõi tăng trưởng, lịch tiêm chủng, dinh dưỡng và những khoảnh khắc đáng nhớ.',
    ),
  ];

  final _controller = PageController();
  final _preferences = OnboardingPreferences();
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isFinishing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Keep the two-page start screen visible on every app launch.
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      await _preferences.markCompleted();
      if (mounted) widget.onLoginRequired();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa lưu được tiến trình. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Chưa thể khởi tạo ứng dụng. Vui lòng thử lại.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView.builder(
        controller: _controller,
        itemCount: _pages.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) => AnimatedBuilder(
          animation: _controller,
          child: _SplashPage(
            data: _pages[index],
            currentPage: _currentPage,
            isFinishing: _isFinishing,
            onContinue: _next,
          ),
          builder: (context, child) {
            final page = _controller.hasClients
                ? _controller.page ?? _currentPage.toDouble()
                : _currentPage.toDouble();
            final distance = (page - index).abs().clamp(0.0, 1.0).toDouble();
            final progress = 1 - distance;
            return Opacity(
              opacity: 0.84 + (0.16 * progress),
              child: Transform.scale(
                scale: 0.97 + (0.03 * progress),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplashPageData {
  const _SplashPageData({
    required this.image,
    required this.title,
    required this.description,
  });

  final String image;
  final String title;
  final String description;
}

class _SplashPage extends StatelessWidget {
  const _SplashPage({
    required this.data,
    required this.currentPage,
    required this.isFinishing,
    required this.onContinue,
  });

  final _SplashPageData data;
  final int currentPage;
  final bool isFinishing;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          Text(
                            data.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppColors.primaryDark,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            data.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ClipRect(
                        // Keep the artwork and embedded labels; trim only the
                        // empty sky (25%) and bottom background (15%).
                        child: Align(
                          alignment: const Alignment(0, 0.25),
                          heightFactor: 0.60,
                          child: Image.asset(
                            data.image,
                            width: constraints.maxWidth - 48,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'Trang ${currentPage + 1} trong 2',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              2,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: index == currentPage ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index == currentPage
                                      ? AppColors.primary
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isFinishing ? null : onContinue,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 56),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isFinishing
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      currentPage == 1 ? 'Bắt đầu' : 'Tiếp tục',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
