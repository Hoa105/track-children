import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'features/auth/auth_screen.dart';
import 'features/child/add_child_profile_screen.dart';
import 'features/child/child_profile_selection_screen.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/start_screen.dart';

void main() => runApp(const TrackChildrenApp());

class TrackChildrenApp extends StatefulWidget {
  const TrackChildrenApp({super.key});

  @override
  State<TrackChildrenApp> createState() => _TrackChildrenAppState();
}

class _TrackChildrenAppState extends State<TrackChildrenApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  void _showLoginAfterSplash() {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(
          onChildProfilePreview: _showChildProfilePreview,
          onLoginSuccess: _showChildProfileSelection,
          onBack: _showStartScreen,
        ),
      ),
      (_) => false,
    );
  }

  void _showStartScreen() {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SplashScreen(onLoginRequired: _showLoginAfterSplash),
      ),
      (_) => false,
    );
  }

  void _showDemoHome(String childName) {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            HomeScreen(childName: childName, onLogout: _showLoginAfterSplash),
      ),
      (_) => false,
    );
  }

  void _showChildProfileSelection() {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ChildProfileSelectionScreen(
          onSelectChild: _showDemoHome,
          onAddChild: _showChildProfilePreview,
        ),
      ),
      (_) => false,
    );
  }

  void _showChildProfilePreview() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AddChildProfileScreen(onOpenHomePreview: _showHomePreview),
      ),
    );
  }

  void _showHomePreview(String childName) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HomeScreen(childName: childName, onLogout: _showLoginAfterSplash),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Bé Lớn Khôn',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: _AppTextScaler(mediaQuery.textScaler, 1.15),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        fontFamily: 'Be Vietnam Pro',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      home: StartScreen(onLoginRequired: _showLoginAfterSplash),
    );
  }
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.parent, this.factor);

  final TextScaler parent;
  final double factor;

  @override
  double scale(double fontSize) => parent.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _AppTextScaler &&
      other.parent == parent &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(parent, factor);
}
