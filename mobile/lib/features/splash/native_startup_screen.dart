import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';
import 'splash_screen.dart';
import 'start_screen.dart' show startLaunchChannel;

/// Android paints Start above this widget until the actual destination is ready.
/// Other platforms keep using the animated Flutter StartScreen.
class NativeStartupScreen extends StatefulWidget {
  const NativeStartupScreen({
    required this.onLoginRequired,
    this.initialize,
    super.key,
  });

  final VoidCallback onLoginRequired;
  final Future<void> Function()? initialize;

  @override
  State<NativeStartupScreen> createState() => _NativeStartupScreenState();
}

class _NativeStartupScreenState extends State<NativeStartupScreen> {
  bool _started = false;
  bool _ready = false;
  bool _failed = false;
  bool _notified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _initialize();
  }

  Future<void> _initialize() async {
    if (_failed) setState(() => _failed = false);
    try {
      // Start stays native while both application data and the first page's
      // illustration load. A completed engine alone is not a usable first page.
      await Future.wait([
        Future<void>.sync(() => widget.initialize?.call()),
        precacheImage(
          const AssetImage('assets/images/scenery/backgrounds/splash_1.png'),
          context,
          onError: (_, _) {},
        ),
      ]);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _notifyAfterContentFrame() {
    if (_notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await startLaunchChannel.invokeMethod<void>('contentReady');
      } on MissingPluginException {
        // Allows widget tests and non-native previews to render this route.
      } on PlatformException {
        // The widget stays usable if the host has already detached.
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: StartColors.background,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: StartColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: _buildContent(),
  );

  Widget _buildContent() {
    if (_ready) {
      _notifyAfterContentFrame();
      return SplashScreen(onLoginRequired: widget.onLoginRequired);
    }
    if (_failed) {
      // Reveal a usable retry screen instead of leaving an opaque native cover.
      _notifyAfterContentFrame();
      return Scaffold(
        backgroundColor: StartColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chưa thể khởi tạo ứng dụng. Vui lòng thử lại.',
                    textAlign: TextAlign.center,
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
      );
    }
    return const ColoredBox(
      color: StartColors.background,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
