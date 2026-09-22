import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/app_routes.dart';
import 'bottom_nav_bar.dart';

/// Scaffold wrapper shared by the 5 bottom-nav-bearing screens (Trang chủ,
/// Theo dõi, Hoạt động, Nhật ký, Thêm). Each screen owns its own AppBar/body;
/// this only supplies the persistent bottom nav and routes taps between the
/// 5 top-level routes with `go` (replacing history) so tabs behave like a
/// standard bottom-nav shell.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.tab,
    required this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final AppTab tab;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  static const _routeForTab = {
    AppTab.home: AppRoutes.home,
    AppTab.tracking: AppRoutes.growth,
    AppTab.activities: AppRoutes.activityGroups,
    AppTab.journal: AppRoutes.journal,
    AppTab.more: AppRoutes.moreHub,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: AppBottomNavBar(
        current: tab,
        onTap: (t) {
          if (t != tab) context.go(_routeForTab[t]!);
        },
      ),
    );
  }
}
