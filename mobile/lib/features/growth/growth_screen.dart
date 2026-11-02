import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../explore/explore_screen.dart';
import '../settings/settings_screen.dart';
import 'api_growth_repository.dart';
import 'growth_overview.dart';
import 'growth_tracking_flow.dart';

Future<void> openMeasurementFromHome(
  BuildContext context, {
  required String childName,
}) async {
  final repository =
      !AuthService.instance.demoMode && AuthService.instance.signedIn
      ? ApiGrowthRepository()
      : MockGrowthRepository();
  try {
    await repository.refreshMeasurements();
    if (!context.mounted) return;
    if (!repository.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có quyền xem số đo.')),
      );
      return;
    }
    if (await openTrackingEditor(context, repository) && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu số đo')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa tải được số đo. Vui lòng thử lại.')),
      );
    }
  }
}

class GrowthScreen extends StatelessWidget {
  const GrowthScreen({
    required this.childName,
    this.onLogout,
    this.initialMetric = 0,
    this.openMeasurement = false,
    super.key,
  });

  final String childName;
  final VoidCallback? onLogout;
  final int initialMetric;
  final bool openMeasurement;

  @override
  Widget build(BuildContext context) => GrowthOverview(
    openEditorOnStart: openMeasurement,
    repository: AuthService.instance.demoMode || !AuthService.instance.signedIn
        ? null
        : ApiGrowthRepository(),
    onNavigation: (destination) {
      if (destination == 'Trang chủ') {
        Navigator.of(
          context,
        ).popUntil((route) => route.settings.name == '/home' || route.isFirst);
      } else if (destination == 'Cá nhân') {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SettingsScreen(childName: childName, onLogout: onLogout),
          ),
        );
      } else if (destination == 'Khám phá') {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExploreScreen(onLogout: onLogout),
          ),
        );
      }
    },
  );
}
