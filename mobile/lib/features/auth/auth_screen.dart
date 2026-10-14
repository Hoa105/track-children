import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'auth_entrance_animation.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onLoginSuccess,
    required this.onChildProfilePreview,
    required this.onBack,
    super.key,
  });

  final VoidCallback onLoginSuccess;
  final VoidCallback onChildProfilePreview;
  final VoidCallback onBack;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showSignUp = false;

  void _openSignUp() => setState(() => _showSignUp = true);

  void _openLogin() => setState(() => _showSignUp = false);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: AuthEntranceBackground(
      animationKey: _showSignUp,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: _showSignUp
                    ? SignUpScreen(
                        key: const ValueKey('sign-up-screen'),
                        onLogin: _openLogin,
                        onChildProfilePreview: widget.onChildProfilePreview,
                      )
                    : LoginScreen(
                        key: const ValueKey('login-screen'),
                        onSignUp: _openSignUp,
                        onBack: widget.onBack,
                        onLoginSuccess: widget.onLoginSuccess,
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
