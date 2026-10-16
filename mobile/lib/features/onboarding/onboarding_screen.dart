import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/onboarding_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingPageData(
      title: 'Chăm sóc bé dễ dàng hơn',
      description: 'Tổng hợp những việc cần chăm bé mỗi ngày, từ lượng sữa đến lịch tiêm chủng và hoạt động chăm sóc.',
      illustration: _OnboardingIllustrationType.care,
    ),
    _OnboardingPageData(
      title: 'Theo dõi hành trình lớn khôn',
      description: 'Lưu lại các chỉ số tăng trưởng, những dấu mốc quan trọng và hành trình phát triển của bé theo thời gian.',
      illustration: _OnboardingIllustrationType.growth,
    ),
    _OnboardingPageData(
      title: 'Đồng hành cùng bé mỗi ngày',
      description: 'Lưu nhật ký chăm sóc và tham khảo những gợi ý theo dõi phù hợp để đồng hành cùng bé.',
      illustration: _OnboardingIllustrationType.journal,
    ),
  ];

  final _controller = PageController();
  final _preferences = OnboardingPreferences();
  int _currentPage = 0;
  bool _isFinishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      await _preferences.markCompleted();
      if (mounted) widget.onFinished();
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isFinishing ? null : _finish,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) =>
                      _OnboardingPage(data: _pages[index]),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Trang ${_currentPage + 1} trong ${_pages.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _currentPage ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == _currentPage
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isFinishing ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isFinishing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentPage == _pages.length - 1
                              ? 'Bắt đầu'
                              : 'Tiếp tục',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.illustration,
  });

  final String title;
  final String description;
  final _OnboardingIllustrationType illustration;
}

enum _OnboardingIllustrationType { care, growth, journal }

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artHeight = (constraints.maxHeight * .57).clamp(190.0, 330.0);
        return Column(
          children: [
            SizedBox(
              height: artHeight,
              child: Center(
                child: _IllustrationCard(
                  type: data.illustration,
                  height: artHeight,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(height: 1.25),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                data.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.55),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.type, required this.height});

  final _OnboardingIllustrationType type;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height * .88,
      width: height * .88,
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
      decoration: const BoxDecoration(
        color: Color(0xFFF0EFE2),
        shape: BoxShape.circle,
      ),
      child: switch (type) {
        _OnboardingIllustrationType.care => const _CareIllustration(),
        _OnboardingIllustrationType.growth => const _GrowthIllustration(),
        _OnboardingIllustrationType.journal => const _JournalIllustration(),
      },
    );
  }
}

class _CareIllustration extends StatelessWidget {
  const _CareIllustration();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Positioned(
        bottom: 38,
        child: Container(
          width: 186,
          height: 74,
          decoration: BoxDecoration(
            color: const Color(0xFFDCE6D5),
            borderRadius: BorderRadius.circular(48),
          ),
        ),
      ),
      const Positioned(
        left: 54,
        bottom: 52,
        child: _AvatarFigure(
          size: 76,
          color: Color(0xFF6D9C7E),
          icon: Icons.person_rounded,
        ),
      ),
      const Positioned(
        right: 48,
        bottom: 45,
        child: _AvatarFigure(
          size: 68,
          color: Color(0xFFE6B867),
          icon: Icons.child_care_rounded,
        ),
      ),
      const Positioned(
        top: 50,
        right: 62,
        child: Icon(Icons.favorite_rounded, color: Color(0xFFD98572), size: 25),
      ),
      const Positioned(
        left: 58,
        top: 62,
        child: Icon(Icons.spa_rounded, color: Color(0xFF9BAF8B), size: 28),
      ),
    ],
  );
}

class _GrowthIllustration extends StatelessWidget {
  const _GrowthIllustration();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.bottomCenter,
    children: [
      Positioned(
        bottom: 44,
        child: Container(
          width: 184,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFFDCE6D5),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      const Positioned(
        bottom: 53,
        left: 56,
        child: _BambooStage(height: 62, leafy: false),
      ),
      const Positioned(
        bottom: 53,
        child: _BambooStage(height: 112, leafy: true),
      ),
      const Positioned(
        bottom: 53,
        right: 48,
        child: _BambooStage(height: 157, leafy: true),
      ),
    ],
  );
}

class _BambooStage extends StatelessWidget {
  const _BambooStage({required this.height, required this.leafy});

  final double height;
  final bool leafy;

  @override
  Widget build(BuildContext context) {
    if (!leafy) {
      return SizedBox(
        width: 34,
        height: height,
        child: CustomPaint(painter: _ShootPainter()),
      );
    }
    return SizedBox(
      width: 36,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 13,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF6D9C7E),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          for (var i = 1; i < 4; i++)
            Positioned(
              bottom: height * i / 4,
              child: Container(
                width: 13,
                height: 2,
                color: const Color(0xFFD5E1CD),
              ),
            ),
          Positioned(
            top: 4,
            left: 0,
            child: Icon(
              Icons.eco_rounded,
              size: 19,
              color: const Color(0xFF91AA7B),
            ),
          ),
          Positioned(
            top: 16,
            right: 0,
            child: Icon(
              Icons.eco_rounded,
              size: 17,
              color: const Color(0xFF91AA7B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShootPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9BAF8B)
      ..style = PaintingStyle.fill;
    final shoot = Path()
      ..moveTo(size.width * .12, size.height)
      ..quadraticBezierTo(
        size.width * .12,
        size.height * .48,
        size.width * .5,
        size.height * .08,
      )
      ..quadraticBezierTo(
        size.width * .9,
        size.height * .47,
        size.width * .88,
        size.height,
      )
      ..close();
    canvas.drawPath(shoot, paint);
    final seam = Paint()
      ..color = const Color(0xFFDCE6D5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * .5, size.height * .16),
      Offset(size.width * .5, size.height * .94),
      seam,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JournalIllustration extends StatelessWidget {
  const _JournalIllustration();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Transform.rotate(
        angle: -.08,
        child: Container(
          width: 148,
          height: 184,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 35,
                color: AppColors.primary,
              ),
              const SizedBox(height: 13),
              for (var i = 0; i < 3; i++) ...[
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == 0 ? const Color(0xFFE5EFE3) : AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ),
      const Positioned(
        right: 46,
        bottom: 49,
        child: _BambooStage(height: 90, leafy: true),
      ),
      const Positioned(
        left: 44,
        top: 48,
        child: Icon(Icons.favorite_rounded, color: Color(0xFFD98572), size: 23),
      ),
    ],
  );
}

class _AvatarFigure extends StatelessWidget {
  const _AvatarFigure({
    required this.size,
    required this.color,
    required this.icon,
  });

  final double size;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, color: Colors.white, size: size * .48),
  );
}
