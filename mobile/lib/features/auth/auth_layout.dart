import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'social_provider_icon.dart';

enum AuthMascotPose {
  welcome,
  idle,
  typing,
  passwordHidden,
  passwordVisible,
  error,
  success,
}

/// Tracks only presentation events, never field contents.
class AuthMascotController extends ChangeNotifier {
  final Map<FocusNode, bool Function()?> _fields = {};
  bool _error = false, _success = false, _welcome = true;
  bool _focusQueued = false, _disposed = false;
  AuthMascotPose _lastNotifiedPose = AuthMascotPose.welcome;

  void _emitPose() {
    if (_disposed || pose == _lastNotifiedPose) return;
    _lastNotifiedPose = pose;
    notifyListeners();
  }

  void _focusChanged() {
    // FocusManager updates the old and new nodes in the same microtask.
    // Read the final focus once, avoiding a fleeting idle pose between fields.
    if (_focusQueued) return;
    _focusQueued = true;
    scheduleMicrotask(() {
      _focusQueued = false;
      _emitPose();
    });
  }

  FocusNode field({bool Function()? obscured}) {
    final node = FocusNode();
    _fields[node] = obscured;
    node.addListener(() {
      if (node.hasFocus) _error = false;
      _focusChanged();
    });
    return node;
  }

  AuthMascotPose get pose {
    if (_success) return AuthMascotPose.success;
    if (_error) return AuthMascotPose.error;
    for (final entry in _fields.entries) {
      if (!entry.key.hasFocus) continue;
      if (entry.value == null) return AuthMascotPose.typing;
      return entry.value!()
          ? AuthMascotPose.passwordHidden
          : AuthMascotPose.passwordVisible;
    }
    return _welcome ? AuthMascotPose.welcome : AuthMascotPose.idle;
  }

  void begin({required bool reducedMotion}) {
    _welcome = !reducedMotion;
  }

  void finishWelcome() {
    _welcome = false;
    _emitPose();
  }

  void edited() {
    if (_error) {
      _error = false;
      _emitPose();
    }
  }

  void visibilityChanged() => _emitPose();
  void showError() {
    _error = true;
    _emitPose();
  }

  void showSuccess() {
    _success = true;
    _emitPose();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final node in _fields.keys) {
      node.dispose();
    }
    super.dispose();
  }
}

class AuthMascot extends StatefulWidget {
  const AuthMascot({required this.controller, super.key});
  final AuthMascotController controller;
  static const root = 'assets/images/scenery/backgrounds/auth-mascot/';
  static String asset(AuthMascotPose pose) =>
      '$root${switch (pose) {
        AuthMascotPose.passwordHidden => 'password_hidden',
        AuthMascotPose.passwordVisible => 'password_visible',
        _ => pose.name,
      }}.png';
  @override
  State<AuthMascot> createState() => _AuthMascotState();
}

class _AuthMascotState extends State<AuthMascot>
    with SingleTickerProviderStateMixin {
  late final _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );
  final _loads = <AuthMascotPose, Future<void>>{};
  final _ready = <AuthMascotPose>{};
  late AuthMascotPose _target = widget.controller.pose;
  late List<double> _from = [
    for (final pose in AuthMascotPose.values) pose == _target ? 1 : 0,
  ];
  int _request = 0;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_requestPose);
  }

  List<double> get _weights {
    final progress = Curves.easeInOutCubic.transform(_transition.value);
    return [
      for (final pose in AuthMascotPose.values)
        _from[pose.index] * (1 - progress) + (pose == _target ? progress : 0),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _transition.value = 1;
    if (_loads.isEmpty) {
      for (final pose in AuthMascotPose.values) {
        _loads[pose] =
            precacheImage(AssetImage(AuthMascot.asset(pose)), context).then((
              _,
            ) {
              if (mounted) _ready.add(pose);
            });
      }
    }
  }

  @override
  void didUpdateWidget(AuthMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_requestPose);
    widget.controller.addListener(_requestPose);
    _requestPose();
  }

  void _requestPose() {
    final pose = widget.controller.pose;
    final request = ++_request;
    if (pose == _target) return;
    if (_ready.contains(pose)) {
      _showPose(pose);
    } else {
      // Keep the current image visible until the next one has decoded.
      _loads[pose]?.then((_) {
        if (mounted && request == _request) _showPose(pose);
      });
    }
  }

  void _showPose(AuthMascotPose pose) {
    setState(() {
      // Retarget from the current blend, rather than restarting either image.
      _from = _weights;
      _target = pose;
      if (_reducedMotion) {
        _transition.value = 1;
      } else {
        _transition.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    ++_request;
    widget.controller.removeListener(_requestPose);
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _transition,
        builder: (context, _) {
          final weights = _weights;
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.bottomCenter,
            children: [
              for (final pose in AuthMascotPose.values)
                if (weights[pose.index] > 0)
                  Opacity(
                    key: ValueKey(pose),
                    opacity: weights[pose.index],
                    child: Image.asset(
                      AuthMascot.asset(pose),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
            ],
          );
        },
      ),
    ),
  );
}

/// Shared, locally themed layout; other screens retain the application theme.
class AuthLayout extends StatefulWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.mascot,
    required this.child,
    this.compact = false,
    this.backTooltip = 'Quay lại',
    super.key,
  });
  final String title, subtitle, backTooltip;
  final VoidCallback? onBack;
  final AuthMascotController mascot;
  final Widget child;
  final bool compact;
  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_started) {
      if (reduced) _entrance.value = 1;
      return;
    }
    _started = true;
    widget.mascot.begin(reducedMotion: reduced);
    if (reduced) {
      _entrance.value = 1;
    } else {
      _entrance.forward().then((_) {
        if (mounted) widget.mascot.finishWelcome();
      });
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = base.copyWith(
      scaffoldBackgroundColor: HomeColors.background,
      textTheme: base.textTheme.apply(
        fontFamily: 'Nunito',
        bodyColor: HomeColors.ink,
        displayColor: HomeColors.ink,
      ),
      iconTheme: const IconThemeData(color: HomeColors.primary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HomeColors.reminderCta,
          minimumSize: const Size(48, 48),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HomeColors.reminderCta,
          foregroundColor: HomeColors.surface,
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
    final height = widget.compact ? 180.0 : 200.0;
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: HomeColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: widget.backTooltip,
                        onPressed: widget.onBack,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        color: HomeColors.ink,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: HomeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _entrance,
                      builder: (context, child) {
                        final progress = Curves.easeOutCubic.transform(
                          _entrance.value,
                        );
                        final formProgress = const Interval(
                          .3,
                          1,
                          curve: Curves.easeOutCubic,
                        ).transform(_entrance.value);
                        return Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Padding(
                              // The updated artwork meets the form at y=540/600.
                              padding: EdgeInsets.only(top: height * .9),
                              child: Opacity(
                                opacity: formProgress,
                                child: Transform.translate(
                                  offset: Offset(0, 8 * (1 - formProgress)),
                                  child: child,
                                ),
                              ),
                            ),
                            // Keep the artwork anchored to the form edge and
                            // paint fingers over the border without blocking inputs.
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: height,
                              child: IgnorePointer(
                                child: ClipRect(
                                  child: Transform.translate(
                                    offset: Offset(
                                      0,
                                      height * .9 * (1 - progress),
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: height * 640 / 600,
                                        height: height,
                                        child: AuthMascot(
                                          controller: widget.mascot,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: Container(
                        key: const ValueKey('auth-form-surface'),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: HomeColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: HomeColors.iconBackground),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({required this.onPressed, super.key});
  final ValueChanged<SocialProvider>? onPressed;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Row(
        children: [
          Expanded(child: Divider(color: HomeColors.iconBackground)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Hoặc tiếp tục với',
              style: TextStyle(fontSize: 13, color: HomeColors.ink),
            ),
          ),
          Expanded(child: Divider(color: HomeColors.iconBackground)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final provider in [
            SocialProvider.google,
            SocialProvider.apple,
          ]) ...[
            if (provider == SocialProvider.apple) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onPressed == null
                    ? null
                    : () => onPressed!(provider),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  backgroundColor: HomeColors.surface,
                  foregroundColor: HomeColors.ink,
                  side: const BorderSide(color: HomeColors.iconBackground),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: SocialProviderIcon(provider: provider),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tiếp tục với ${provider == SocialProvider.google ? 'Google' : 'Apple'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}
