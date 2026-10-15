import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import 'splash_screen.dart';

/// Brand artwork shown before the existing introduction flow.
class StartScreen extends StatefulWidget {
  const StartScreen({required this.onLoginRequired, super.key});

  final VoidCallback onLoginRequired;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  Timer? _timer;
  bool _showIntroduction = false;

  void _onArtworkVisible() {
    // Start the display interval after the image has actually been painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _timer != null) return;
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showIntroduction = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntroduction) {
      return SplashScreen(onLoginRequired: widget.onLoginRequired);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/scenery/backgrounds/start_screen.png',
              fit: BoxFit.cover,
              semanticLabel: 'Bé lớn khôn. Cùng con lớn khôn mỗi ngày.',
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  _onArtworkVisible();
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                // Never trap the user on the launch screen if decoding fails.
                _onArtworkVisible();
                return const Center(child: Text('Bé lớn khôn'));
              },
            ),
            SafeArea(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: const _LoadingDots(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang tải ứng dụng',
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final activeDot = (_controller.value * 3).floor();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.smallGap / 2,
                ),
                child: AnimatedOpacity(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  opacity: index == activeDot ? 1 : 0.3,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: AppLayout.smallGap),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
