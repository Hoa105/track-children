import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'services/demo_store.dart';
import 'services/auth_service.dart';
import 'services/vaccination_api.dart';
import 'services/vaccination_schedule.dart';
import 'features/auth/auth_screen.dart';
import 'features/child/add_child_profile_screen.dart';
import 'features/child/child_profile_selection_screen.dart';
import 'features/home/home_screen.dart';
import 'features/growth/growth_overview.dart';
import 'features/growth/growth_weight_detail.dart';
import 'features/growth/growth_stature_detail.dart';
import 'features/growth/growth_head_detail.dart';
import 'features/growth/growth_bmi_detail.dart';
import 'features/growth/growth_conclusion_explanation.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DemoStore.instance.initialize();
  await DemoStore.instance.logout();
  await AuthService.instance.restore();
  final vaccinationApi = VaccinationApi();
  DemoStore.vaccinationRemote = vaccinationApi;
  // Không chờ: backend tắt thì dùng lịch tiêm có sẵn trong app.
  vaccinationApi.fetchSchedule().then(applyVaccineCatalog).catchError((_) {});
  // Gửi lên backend các mũi đang chỉ lưu trên máy (vd thêm khi chưa có mạng).
  for (final child in DemoStore.instance.children) {
    DemoStore.instance.syncVaccinations(child['id'] as String);
  }
  runApp(const TrackChildrenApp());
}

class TrackChildrenApp extends StatefulWidget {
  const TrackChildrenApp({super.key});

  @override
  State<TrackChildrenApp> createState() => _TrackChildrenAppState();
}

class _TrackChildrenAppState extends State<TrackChildrenApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GrowthRepository _growthRepository = MockGrowthRepository();

  Future<void> _logout() async {
    final revocation = AuthService.instance.logout();
    await DemoStore.instance.clearAuthenticatedCache();
    if (!mounted) return;
    await _showLoginAfterSplash();
    final revoked = await revocation;
    if (!revoked && mounted) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã đăng xuất trên máy. Chưa thu hồi được phiên trên máy chủ do lỗi kết nối.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showLoginAfterSplash() async {
    if (AuthService.instance.signedIn) {
      await _showChildProfileSelection();
      return;
    }
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
        builder: (_) => HomeScreen(childName: childName, onLogout: _logout),
        settings: const RouteSettings(name: '/home'),
      ),
      (_) => false,
    );
  }

  Future<void> _showChildProfileSelection() async {
    if (AuthService.instance.user != null) {
      await DemoStore.instance.bindAuthenticatedUser(
        AuthService.instance.user!,
      );
      if (!AuthService.instance.demoMode) {
        final owner = AuthService.instance.user!['id'] as String;
        try {
          final response = await AuthService.instance.authorizedRequest(
            'GET',
            '/children',
          );
          if (AuthService.instance.user?['id'] != owner) return;
          await DemoStore.instance.cacheAuthenticatedChildren(
            owner,
            (response['children'] as List)
                .map((c) => Map<String, dynamic>.from(c as Map))
                .toList(),
          );
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.maybeOf(_navigatorKey.currentContext ?? context)
                ?.showSnackBar(
                  SnackBar(content: Text('Chưa tải được hồ sơ bé: $error')),
                );
          }
        }
      }
    }
    if (!mounted) return;
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

  Future<void> _showChildProfilePreview() async {
    if (AuthService.instance.user != null) {
      await DemoStore.instance.bindAuthenticatedUser(
        AuthService.instance.user!,
      );
    }
    if (!mounted) return;
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
        builder: (_) => HomeScreen(childName: childName, onLogout: _logout),
        settings: const RouteSettings(name: '/home'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Bé Lớn Khôn',
      debugShowCheckedModeBanner: false,
      routes: {
        '/growth/bmi-detail': (_) =>
            GrowthBmiDetailScreen(repository: _growthRepository),
        '/growth/head-detail': (_) =>
            GrowthHeadDetailScreen(repository: _growthRepository),
        '/growth/length-detail': (_) =>
            GrowthStatureDetailScreen(repository: _growthRepository),
        '/growth/weight-velocity-explanation': (_) =>
            const GrowthConclusionExplanationScreen(
              introText:
                  'Cùng tìm hiểu dữ liệu và cách tính tốc độ tăng cân của bé.',
              sources: {
                'WHO Weight velocity': 'https://www.who.int/tools/child-growth-standards/standards/weight-velocity',
              },
              sections: [
                GrowthExplanationSection(
                  '1. Dữ liệu được sử dụng',
                  'Chưa có lần đo được chọn. Hãy mở phần giải thích từ tab Tốc độ.',
                ),
                GrowthExplanationSection(
                  '2. Cách tính',
                  'Cần hai số đo và khoảng thời gian hợp lệ.',
                ),
                GrowthExplanationSection(
                  '3. Xu hướng qua các tháng',
                  'Chưa đủ dữ liệu nhận xét xu hướng.',
                ),
                GrowthExplanationSection(
                  '4. Căn cứ WHO',
                  'Chưa có kết quả đối chiếu WHO hợp lệ cho lần đo đang đánh giá.',
                ),
              ],
            ),
        '/growth/weight-explanation': (_) =>
            const GrowthConclusionExplanationScreen(),
        '/growth': (_) => GrowthOverview(repository: _growthRepository),
        '/growth/weight-detail': (_) =>
            GrowthWeightDetailScreen(repository: _growthRepository),
      },
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
        fontFamily: 'Nunito',
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
