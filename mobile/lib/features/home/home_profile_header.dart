import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../../services/app_notifications.dart';
import '../../services/demo_store.dart';

class HomeProfileHeader extends StatelessWidget {
  const HomeProfileHeader({
    required this.name,
    required this.onTap,
    required this.onSettingsTap,
    required this.onNotificationsTap,
    super.key,
  });
  final String name;
  final VoidCallback onTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onNotificationsTap;
  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('home-profile-header'),
    children: [
      Container(
        width: AppLayout.minimumTouchTarget,
        height: AppLayout.minimumTouchTarget,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x1A194C3C), blurRadius: 8)],
        ),
        child: DemoStore.instance.child?['avatar_base64'] != null
            ? ClipOval(
                child: Image.memory(
                  base64Decode(
                    DemoStore.instance.child!['avatar_base64'] as String,
                  ),
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(
                Icons.child_care_rounded,
                color: AppColors.primary,
                size: 28,
              ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            key: const ValueKey('home-profile-summary'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: AppLayout.homeProfileNameSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (DemoStore.instance.signedIn)
                    PopupMenuButton<String>(
                      tooltip: 'Đổi hồ sơ bé',
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                      ),
                      itemBuilder: (_) => [
                        for (final child in DemoStore.instance.children)
                          PopupMenuItem(
                            value: child['id'] as String,
                            child: Text(child['full_name'] as String),
                          ),
                      ],
                      onSelected: (id) => DemoStore.instance.selectChild(id),
                    )
                  else
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                    ),
                ],
              ),
              Text(
                DemoStore.instance.child == null
                    ? 'Chưa chọn hồ sơ bé'
                    : DemoStore.instance.ageLabel(DemoStore.instance.child!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppLayout.homeHeroBodySize,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 4),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundAction(
            asset: 'assets/images/scenery/icons/ui/notification_bell.svg',
            label: 'Thông báo',
            showBadge: true,
            onTap: onNotificationsTap,
          ),
          const SizedBox(width: 4),
          _RoundAction(
            asset: 'assets/images/scenery/icons/ui/settings_sliders.svg',
            label: 'Cài đặt',
            onTap: onSettingsTap,
          ),
        ],
      ),
    ],
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.asset,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });
  final String asset;
  final String label;
  final bool showBadge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Badge.count(
            count: unreadNotificationCount(DemoStore.instance),
            isLabelVisible:
                showBadge && unreadNotificationCount(DemoStore.instance) > 0,
            child: SvgPicture.asset(
              asset,
              width: 24,
              height: 24,
              semanticsLabel: label,
            ),
          ),
        ),
      ),
    ),
  );
}
