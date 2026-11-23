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
  String _ageLabel(Map<String, dynamic> child) {
    final months = int.parse(
      DemoStore.instance.ageLabel(child).split(' ').first,
    );
    if (months < 12) return '$months tháng';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    return remainingMonths == 0
        ? '$years tuổi'
        : '$years tuổi $remainingMonths tháng';
  }

  @override
  Widget build(BuildContext context) {
    final rawName = name.trim();
    final displayName = rawName.isEmpty
        ? 'Bé'
        : (rawName.toLowerCase().startsWith('bé ')
            ? rawName
            : 'Bé $rawName');
    return Row(
    key: const ValueKey('home-profile-header'),
    children: [
      Container(
        width: AppLayout.minimumTouchTarget,
        height: AppLayout.minimumTouchTarget,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HomeColors.surface,
          border: Border.all(color: HomeColors.surface, width: 3),
          boxShadow: [
            BoxShadow(
              color: HomeColors.ink.withValues(alpha: .08),
              blurRadius: 8,
            ),
          ],
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
                color: HomeColors.primary,
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
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeColors.ink,
                        fontSize: AppLayout.homeProfileNameSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (DemoStore.instance.signedIn)
                    PopupMenuButton<String>(
                      tooltip: 'Đổi hồ sơ bé',
                      color: HomeColors.surface,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: HomeColors.primary,
                      ),
                      itemBuilder: (_) => [
                        for (final child in DemoStore.instance.children)
                          PopupMenuItem(
                            value: child['id'] as String,
                            child: Text(
                              child['full_name'] as String,
                              style: const TextStyle(color: HomeColors.ink),
                            ),
                          ),
                      ],
                      onSelected: (id) => DemoStore.instance.selectChild(id),
                    )
                  else
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: HomeColors.primary,
                    ),
                ],
              ),
              Text(
                DemoStore.instance.child == null
                    ? 'Chưa chọn hồ sơ bé'
                    : _ageLabel(DemoStore.instance.child!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomeColors.primary,
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
            icon: Icons.settings_outlined,
            label: 'Cài đặt',
            onTap: onSettingsTap,
          ),
        ],
      ),
    ],
  );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    this.asset,
    this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  }) : assert(asset != null || icon != null, 'Either asset or icon must be provided');

  final String? asset;
  final IconData? icon;
  final String label;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = icon != null
        ? Icon(
            icon,
            size: 24,
            color: HomeColors.primary,
            semanticLabel: label,
          )
        : SvgPicture.asset(
            asset!,
            width: 24,
            height: 24,
            semanticsLabel: label,
            colorFilter: const ColorFilter.mode(
              HomeColors.primary,
              BlendMode.srcIn,
            ),
          );

    final unread = showBadge ? unreadNotificationCount(DemoStore.instance) : 0;
    return Material(
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
              count: unread,
              isLabelVisible: showBadge && unread > 0,
              child: iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}
