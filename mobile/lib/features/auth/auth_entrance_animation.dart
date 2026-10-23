import 'package:flutter/material.dart';

class AuthEntranceBackground extends StatelessWidget {
  static const _revealDelay = Duration(milliseconds: 80);
  static const _revealDuration = Duration(milliseconds: 600);

  const AuthEntranceBackground({
    required this.child,
    this.animationKey,
    super.key,
  });

  final Widget child;
  final Object? animationKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(animationKey),
              tween: Tween(begin: 0, end: 1),
              duration: _revealDelay + _revealDuration,
              curve: Curves.linear,
              builder: (context, value, _) {
                final delayFraction =
                    _revealDelay.inMilliseconds /
                    (_revealDelay + _revealDuration).inMilliseconds;
                final progress = value <= delayFraction
                    ? 0.0
                    : Curves.easeInOutCubic.transform(
                        (value - delayFraction) / (1 - delayFraction),
                      );

                return ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: progress,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Transform.translate(
                        offset: Offset(-20, -250 - 24 * (1 - progress)),
                        child: Opacity(
                          opacity: 0.68 * progress,
                          child: Transform.scale(
                            scale: 1.0875,
                            alignment: Alignment.topCenter,
                            child: Image.asset(
                              'assets/images/scenery/backgrounds/green_leaf.png',
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          child,
        ],
      );
    },
  );
}

class AuthEntranceCard extends StatelessWidget {
  static const _entranceDelay = Duration(milliseconds: 180);
  static const _entranceDuration = Duration(milliseconds: 600);

  const AuthEntranceCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: _entranceDelay + _entranceDuration,
    curve: Curves.linear,
    child: child,
    builder: (context, value, card) {
      final delayFraction =
          _entranceDelay.inMilliseconds /
          (_entranceDelay + _entranceDuration).inMilliseconds;
      final elapsed = 1 - value;
      final progress = elapsed <= delayFraction
          ? 0.0
          : Curves.easeOutCubic.transform(
              (elapsed - delayFraction) / (1 - delayFraction),
            );

      return Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - progress)),
          child: card,
        ),
      );
    },
  );
}
