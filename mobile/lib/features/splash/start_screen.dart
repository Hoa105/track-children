import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_colors.dart';
import 'splash_screen.dart';

const _assets = 'assets/images/scenery/backgrounds/start-assets';

/// Presentation is independent of the existing introduction timer and routing.
class StartScreen extends StatefulWidget {
  const StartScreen({required this.onLoginRequired, super.key});
  final VoidCallback onLoginRequired;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _showIntroduction = false;
  bool _preloading = false;
  final _ready = <String>{};
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  void _onArtworkVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _timer != null) return;
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showIntroduction = true);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (_animation.status == AnimationStatus.dismissed) {
      _animation.forward();
    }
    if (!_preloading) {
      _preloading = true;
      for (final pose in ['idle', 'jump', 'welcome', 'happy']) {
        _loadPose(pose);
      }
    }
  }

  Future<void> _loadPose(String pose) async {
    var failed = false;
    await precacheImage(
      AssetImage('$_assets/mascot/$pose.png'),
      context,
      onError: (error, stack) => failed = true,
    );
    if (mounted && !failed) setState(() => _ready.add(pose));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntroduction) {
      return SplashScreen(onLoginRequired: widget.onLoginRequired);
    }
    return Scaffold(
      backgroundColor: StartColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Both full-screen layers share the same canvas, fit and alignment.
          SvgPicture.asset(
            '$_assets/background/start_background.svg',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            excludeFromSemantics: true,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = math
                    .min(
                      constraints.maxWidth / 360,
                      constraints.maxHeight / 752,
                    )
                    .clamp(0.0, 1.35);
                final mascotWidth = 350 * scale;
                final mascotHeight = mascotWidth * 600 / 640;
                final circleSize = 225 * scale;
                // Text keeps system scaling; illustration yields vertical space.
                return Column(
                  children: [
                    Spacer(flex: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) => Opacity(
                          opacity: ((_animation.value * 1200 - 550) / 180)
                              .clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bé lớn khôn',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 40 * math.min(1.0, scale),
                                  height: 1.2,
                                  color: StartColors.ink,
                                ),
                              ),
                              SvgPicture.asset(
                                '$_assets/decorations/underline.svg',
                                width: 150 * scale,
                                height: 20 * scale,
                                excludeFromSemantics: true,
                              ),
                              Opacity(
                                opacity: ((_animation.value * 1200 - 700) / 180)
                                    .clamp(0.0, 1.0),
                                child: const Text(
                                  'Cùng con lớn khôn mỗi ngày',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    height: 1.4,
                                    color: StartColors.slogan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    Flexible(
                      flex: 42,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: mascotWidth,
                          height: mascotHeight,
                          child: AnimatedBuilder(
                            animation: _animation,
                            builder: (context, _) {
                              final ms = _animation.value * 1200;
                              final requested = ms < 200
                                  ? 'idle'
                                  : ms < 550
                                  ? 'jump'
                                  : ms < 900
                                  ? 'welcome'
                                  : 'happy';
                              final pose = _ready.contains(requested)
                                  ? requested
                                  : _ready.contains('idle')
                                  ? 'idle'
                                  : _ready.isNotEmpty
                                  ? _ready.first
                                  : 'idle';
                              final y = ms < 200
                                  ? 24 *
                                        (1 - Curves.easeOut.transform(ms / 200))
                                  : ms < 550
                                  ? -16 * math.sin((ms - 200) / 350 * math.pi)
                                  : 0.0;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  SvgPicture.asset(
                                    '$_assets/decorations/circle.svg',
                                    width: circleSize,
                                    height: circleSize,
                                    excludeFromSemantics: true,
                                  ),
                                  Positioned(
                                    top: mascotHeight * 0.84,
                                    child: SvgPicture.asset(
                                      '$_assets/decorations/ground_shadow.svg',
                                      width: 110 * scale,
                                      height: 20 * scale,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(0, y * scale),
                                    child: Opacity(
                                      opacity: (ms / 200).clamp(0.0, 1.0),
                                      child: Image.asset(
                                        '$_assets/mascot/$pose.png',
                                        key: ValueKey(pose),
                                        width: mascotWidth,
                                        height: mascotHeight,
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                        excludeFromSemantics: true,
                                        frameBuilder:
                                            (context, child, frame, sync) {
                                              if (sync || frame != null) {
                                                _onArtworkVisible();
                                              }
                                              return child;
                                            },
                                        errorBuilder: (context, error, stack) {
                                          _onArtworkVisible();
                                          return const SizedBox.expand();
                                        },
                                      ),
                                    ),
                                  ),
                                  for (final decoration in ['rays', 'heart'])
                                    Positioned(
                                      left: decoration == 'rays'
                                          ? 24 * scale
                                          : null,
                                      right: decoration == 'heart'
                                          ? 24 * scale
                                          : null,
                                      top: 90 * scale,
                                      child: Opacity(
                                        opacity: ((ms - 550) / 250).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        child: SvgPicture.asset(
                                          '$_assets/decorations/$decoration.svg',
                                          width: 32 * scale,
                                          height: 36 * scale,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Spacer(flex: 25),
                  ],
                );
              },
            ),
          ),
          IgnorePointer(
            child: SvgPicture.asset(
              '$_assets/background/foreground.svg',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}
