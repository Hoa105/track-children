import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_colors.dart';
import 'splash_screen.dart';

const _assets = 'assets/images/scenery/backgrounds/start-assets';
const startLaunchChannel = MethodChannel('be_lon_khon/start_launch');

/// Presentation is independent of the existing introduction timer and routing.
class StartScreen extends StatefulWidget {
  const StartScreen({
    required this.onLoginRequired,
    this.initialize,
    super.key,
  });
  final VoidCallback onLoginRequired;
  final Future<void> Function()? initialize;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _showIntroduction = false;
  bool _preloading = false;
  bool _startupReady = false;
  bool _displayElapsed = false;
  bool _startupFailed = false;
  bool _handoffReady = false;
  bool _artworkVisible = false;
  final _ready = <String>{};
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _initialize();
    _prepareLaunch();
  }

  Future<void> _prepareLaunch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _completeHandoff();
      return;
    }
    try {
      // Release the native preview only after the fixed title has painted.
      final painted = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => painted.complete());
      WidgetsBinding.instance.scheduleFrame();
      await painted.future;
      await startLaunchChannel.invokeMethod<void>('release');
    } on MissingPluginException {
      // Web, tests and non-Android hosts do not have a native launch overlay.
    } on PlatformException {
      // The native preview does not depend on this optional acknowledgement.
    }
    _completeHandoff();
  }

  void _completeHandoff() {
    if (!mounted) return;
    setState(() => _handoffReady = true);
    if (_artworkVisible) _onArtworkVisible();
  }

  double get _sceneTime => math.max(0, _animation.value * 1200 - 300);

  Future<void> _initialize() async {
    if (_startupFailed) setState(() => _startupFailed = false);
    try {
      await widget.initialize?.call();
      if (!mounted) return;
      setState(() {
        _startupReady = true;
        _showIntroduction = _displayElapsed;
      });
    } catch (_) {
      if (mounted) setState(() => _startupFailed = true);
    }
  }

  void _onArtworkVisible() {
    _artworkVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_handoffReady || _timer != null) return;
      if (!MediaQuery.disableAnimationsOf(context)) _animation.forward();
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _displayElapsed = true;
            _showIntroduction = _startupReady;
          });
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    }
    if (!_preloading) {
      _preloading = true;
      for (final pose in ['idle', 'happy', 'welcome']) {
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

  Widget _reveal(Widget child, {double start = 0, double end = 250}) =>
      AnimatedBuilder(
        animation: _animation,
        child: child,
        builder: (context, child) => Opacity(
          opacity: ((_sceneTime - start) / (end - start)).clamp(0.0, 1.0),
          child: child,
        ),
      );

  Widget _buildHeading(double scale, double availableWidth) {
    final titleStyle = TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w900,
      fontSize: 40 * math.min(1.0, scale),
      height: 1.2,
      color: StartColors.ink,
    );
    final titleMetrics = TextPainter(
      text: TextSpan(text: 'B\u00e9 l\u1edbn kh\u00f4n', style: titleStyle),
      textDirection: Directionality.of(context),
      textAlign: TextAlign.center,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: availableWidth);
    final titleLeft = (availableWidth - titleMetrics.width) / 2;
    final titleRight = titleLeft + titleMetrics.width;
    final firstLetter = titleMetrics.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    final firstLetterLeft =
        titleLeft + (firstLetter.isEmpty ? 0 : firstLetter.first.left);
    titleMetrics.dispose();
    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 1,
                child: Text(
                  'B\u00e9 l\u1edbn kh\u00f4n',
                  key: const ValueKey('start-title'),
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
              ),
              _reveal(
                SvgPicture.asset(
                  '$_assets/decorations/underline.svg',
                  width: 150 * scale,
                  height: 20 * scale,
                  excludeFromSemantics: true,
                ),
                start: 100,
                end: 300,
              ),
              _reveal(
                const Text(
                  'C\u00f9ng con l\u1edbn kh\u00f4n m\u1ed7i ng\u00e0y',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.4,
                    color: StartColors.slogan,
                  ),
                ),
                start: 200,
                end: 450,
              ),
            ],
          ),
          Positioned(
            key: const ValueKey('start-decoration-jump_marks'),
            left: (firstLetterLeft - 12 * scale).clamp(
              0.0,
              math.max(0.0, availableWidth - 32 * scale),
            ),
            top: -23 * scale,
            child: _reveal(
              Transform.rotate(
                angle: -math.pi / 6,
                child: SvgPicture.asset(
                  '$_assets/decorations/jump_marks.svg',
                  width: 32 * scale,
                  height: 22 * scale,
                  excludeFromSemantics: true,
                ),
              ),
              start: 100,
              end: 300,
            ),
          ),
          Positioned(
            key: const ValueKey('start-decoration-dashed_curve'),
            left: (titleRight - 14 * scale).clamp(
              0.0,
              math.max(0.0, availableWidth - 64 * scale),
            ),
            top: -18 * scale,
            child: _reveal(
              SvgPicture.asset(
                '$_assets/decorations/dashed_curve.svg',
                width: 64 * scale,
                height: 32 * scale,
                excludeFromSemantics: true,
              ),
              start: 100,
              end: 300,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntroduction) {
      return SplashScreen(onLoginRequired: widget.onLoginRequired);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: StartColors.background,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: StartColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: StartColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Both full-screen layers share the same canvas, fit and alignment.
            _reveal(
              SvgPicture.asset(
                '$_assets/background/start_background.svg',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                excludeFromSemantics: true,
              ),
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
                  // Updated poses share a square 1254px canvas with less alpha padding.
                  final mascotWidth = 245 * scale;
                  final mascotHeight = mascotWidth;
                  final circleSize = 225 * scale;
                  // Text keeps system scaling; illustration yields vertical space.
                  return Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * .17),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHeading(scale, constraints.maxWidth - 32),
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
                                final ms = _sceneTime;
                                final requested = ms < 200
                                    ? 'idle'
                                    : ms < 900
                                    ? 'happy'
                                    : 'welcome';
                                final pose = _ready.contains(requested)
                                    ? requested
                                    : _ready.contains('idle')
                                    ? 'idle'
                                    : 'idle';
                                final y = ms < 200
                                    ? 24 *
                                          (1 -
                                              Curves.easeOut.transform(
                                                ms / 200,
                                              ))
                                    : 0.0;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    _reveal(
                                      SvgPicture.asset(
                                        '$_assets/decorations/circle.svg',
                                        width: circleSize,
                                        height: circleSize,
                                        excludeFromSemantics: true,
                                      ),
                                      start: 100,
                                      end: 350,
                                    ),
                                    Positioned(
                                      top: mascotHeight - 20 * scale,
                                      child: _reveal(
                                        SvgPicture.asset(
                                          '$_assets/decorations/ground_shadow.svg',
                                          width: 110 * scale,
                                          height: 20 * scale,
                                          excludeFromSemantics: true,
                                        ),
                                        start: 100,
                                        end: 350,
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: Offset(0, y * scale),
                                      child: Opacity(
                                        opacity: (ms / 200).clamp(0.0, 1.0),
                                        child: Transform.scale(
                                          scale: pose == 'idle' ? 1.067 : 1.16,
                                          filterQuality: FilterQuality.high,
                                          child: Image.asset(
                                            '$_assets/mascot/$pose.png',
                                            key: ValueKey(pose),
                                            width: mascotWidth,
                                            height: mascotHeight,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            gaplessPlayback: true,
                                            excludeFromSemantics: true,
                                            frameBuilder:
                                                (context, child, frame, sync) {
                                                  if (sync || frame != null) {
                                                    _onArtworkVisible();
                                                  }
                                                  return child;
                                                },
                                            errorBuilder:
                                                (context, error, stack) {
                                                  _onArtworkVisible();
                                                  return const SizedBox.expand();
                                                },
                                          ),
                                        ),
                                      ),
                                    ),
                                    for (final (
                                          decoration,
                                          left,
                                          right,
                                          top,
                                          bottom,
                                          width,
                                          height,
                                        )
                                        in const <
                                          (
                                            String,
                                            double?,
                                            double?,
                                            double?,
                                            double?,
                                            double,
                                            double,
                                          )
                                        >[
                                          ('heart', -1, null, 84, null, 26, 28),
                                          ('rays', null, -2, 74, null, 28, 30),
                                          (
                                            'sparkles',
                                            null,
                                            67,
                                            -4,
                                            null,
                                            22,
                                            22,
                                          ),
                                        ])
                                      Positioned(
                                        key: ValueKey(
                                          'start-decoration-$decoration',
                                        ),
                                        left: left == null
                                            ? null
                                            : left * scale,
                                        right: right == null
                                            ? null
                                            : right * scale,
                                        top: top == null ? null : top * scale,
                                        bottom: bottom == null
                                            ? null
                                            : bottom * scale,
                                        child: Opacity(
                                          opacity: ((ms - 550) / 250).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          child: Transform.rotate(
                                            angle: decoration == 'heart'
                                                ? -math.pi / 15
                                                : 0,
                                            child: SvgPicture.asset(
                                              '$_assets/decorations/$decoration.svg',
                                              width: width * scale,
                                              height: height * scale,
                                              excludeFromSemantics: true,
                                            ),
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
              child: _reveal(
                SvgPicture.asset(
                  '$_assets/background/foreground.svg',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  excludeFromSemantics: true,
                ),
                start: 150,
                end: 400,
              ),
            ),
            if (_startupFailed)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: StartColors.background,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Chưa thể khởi tạo ứng dụng. Vui lòng thử lại.',
                          ),
                          TextButton(
                            onPressed: _initialize,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
