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
      image: 'assets/images/scenery/backgrounds/splash_1.png',
      title: 'Cùng con lớn khôn mỗi ngày',
      description: 'Theo dõi tăng trưởng, đánh giá phát triển và khám phá hoạt động phù hợp với độ tuổi của con.',
      cropTop: .18,
      cropBottom: .13,
    ),
    _SplashPageData(
      image: 'assets/images/scenery/backgrounds/splash_2.png',
      title: 'Lưu giữ hành trình, cùng nhau chăm bé',
      description: 'Lưu nhật ký ảnh, video, nhận xét AI và chia sẻ hồ sơ để cả nhà cùng đồng hành với bé.',
      cropTop: .21,
      cropBottom: .23,
    ),
  ];

  final _controller = PageController();
  final _preferences = OnboardingPreferences();
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isFinishing = false;
  bool _artworkPreloaded = false;
  bool _transitioning = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_artworkPreloaded) return;
    _artworkPreloaded = true;
    // Decode both illustrations before the first swipe, without delaying UI.
    for (final page in _pages) {
      precacheImage(AssetImage(page.image), context, onError: (_, _) {});
    }
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

  Future<void> _next() async {
    if (_transitioning || _isFinishing) return;
    if (_currentPage == _pages.length - 1) {
      _finish();
      return;
    }
    _transitioning = true;
    try {
      await _controller.nextPage(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 460),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _transitioning = false;
    }
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
        backgroundColor: HomeColors.background,
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: HomeColors.primary)
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
      backgroundColor: HomeColors.background,
      body: PageView.builder(
        controller: _controller,
        itemCount: _pages.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) => _SplashPage(
          data: _pages[index],
          currentPage: _currentPage,
          isFinishing: _isFinishing,
          onContinue: _next,
          onSkip: _finish,
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
    required this.cropTop,
    required this.cropBottom,
  });

  final String image;
  final String title;
  final String description;
  final double cropTop, cropBottom;
}

class _SplashPage extends StatelessWidget {
  const _SplashPage({
    required this.data,
    required this.currentPage,
    required this.isFinishing,
    required this.onContinue,
    required this.onSkip,
  });

  final _SplashPageData data;
  final int currentPage;
  final bool isFinishing;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: PageStorageKey(data.image),
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isFinishing ? null : onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: HomeColors.reminderCta,
                          minimumSize: const Size(48, 48),
                          textStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Bỏ qua'),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          Text(
                            data.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: HomeColors.ink,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            data.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: HomeColors.reminderCta,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .52,
                        ),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: ClipRect(
                            // Trim transparent margins only; keep the first
                            // illustration's timeline and the second one's book.
                            child: Align(
                              alignment: Alignment(
                                0,
                                2 *
                                        data.cropTop /
                                        (data.cropTop + data.cropBottom) -
                                    1,
                              ),
                              heightFactor: 1 - data.cropTop - data.cropBottom,
                              widthFactor: .92,
                              child: RepaintBoundary(
                                child: Image.asset(
                                  data.image,
                                  width: constraints.maxWidth - 32,
                                  // Reserve the source aspect ratio even before
                                  // decoding finishes, so Column never reflows.
                                  height:
                                      (constraints.maxWidth - 32) * 1672 / 941,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                  errorBuilder: (_, _, _) => SizedBox(
                                    width: constraints.maxWidth - 32,
                                    height:
                                        (constraints.maxWidth - 32) *
                                        1672 /
                                        941,
                                  ),
                                ),
                              ),
                            ),
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
                                      ? HomeColors.primary
                                      : HomeColors.iconBackground,
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
                                backgroundColor: HomeColors.primary,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
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
