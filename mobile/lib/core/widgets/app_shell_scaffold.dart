import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/child_share.dart';
import '../../services/active_child.dart';
import '../../services/service_locator.dart';
import '../routing/app_routes.dart';
import 'bottom_nav_bar.dart';

/// Scaffold wrapper shared by the 5 bottom-nav-bearing screens (Trang chủ,
/// Theo dõi, Hoạt động, Nhật ký, Thêm). Each screen owns its own AppBar/body;
/// this only supplies the persistent bottom nav and routes taps between the
/// 5 top-level routes with `go` (replacing history) so tabs behave like a
/// standard bottom-nav shell.
///
/// Per-child tabs follow the [ActiveChild]'s permissions: for a shared child
/// "Nhật ký" disappears without journal access, and "Theo dõi" without
/// access to both growth and assessments.
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

  static List<AppTab> visibleTabs(ActiveChild? active) => [
        for (final t in AppTab.values)
          if (switch (t) {
            AppTab.tracking => active == null ||
                active.canView(ShareSection.growth) ||
                active.canView(ShareSection.assessment),
            AppTab.journal => active == null || active.canView(ShareSection.journal),
            _ => true,
          })
            t,
      ];

  static String _routeFor(AppTab tab, ActiveChild? active) => switch (tab) {
        AppTab.home => AppRoutes.home,
        // Without growth access, "Theo dõi" opens the assessment history.
        AppTab.tracking =>
          active == null || active.canView(ShareSection.growth) ? AppRoutes.growth : AppRoutes.history,
        AppTab.activities => AppRoutes.activityGroups,
        AppTab.journal => AppRoutes.journal,
        AppTab.more => AppRoutes.moreHub,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: ValueListenableBuilder<ActiveChild?>(
        valueListenable: ServiceLocator.activeChild,
        builder: (context, active, _) => AppBottomNavBar(
          current: tab,
          tabs: visibleTabs(active),
          onTap: (t) {
            if (t != tab) context.go(_routeFor(t, active));
          },
        ),
      ),
    );
  }
}
