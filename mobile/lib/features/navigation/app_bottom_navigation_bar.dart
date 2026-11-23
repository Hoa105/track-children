import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';

class AppBottomNavigationBar extends StatefulWidget {
  const AppBottomNavigationBar({
    required this.onTap,
    this.selected = 'Trang chủ',
    super.key,
  });

  final ValueChanged<String> onTap;
  final String selected;

  static const _iconsPath = 'assets/images/scenery/icons/ui/';

  @override
  State<AppBottomNavigationBar> createState() => _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar> {
  void _onNavigationTap(String destination) {
    widget.onTap(destination);
  }

  void _onAddTap() {
    widget.onTap('Tạo ghi chép');
  }

  @override
  Widget build(BuildContext context) {
    final isAddActive =
        widget.selected == 'Tạo ghi chép' || widget.selected == 'Thêm nhật ký';

    return RepaintBoundary(
      child: Container(
        decoration: const BoxDecoration(
          color: NavBarColors.background,
          border: Border(
            top: BorderSide(color: NavBarColors.border, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: NavBarColors.shadow,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
      child: SafeArea(
        top: false,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.05,
          child: SizedBox(
            height: 66,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              _NavigationItem(
                label: 'Trang chủ',
                selected: widget.selected == 'Trang chủ',
                outlineAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-home-outline.svg',
                solidAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-home-solid.svg',
                onTap: () => _onNavigationTap('Trang chủ'),
              ),
              _NavigationItem(
                label: 'Theo dõi',
                selected: widget.selected == 'Theo dõi',
                outlineAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-tracking-outline.svg',
                solidAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-tracking-solid.svg',
                onTap: () => _onNavigationTap('Theo dõi'),
              ),
              Expanded(
                child: Semantics(
                  label: 'Tạo ghi chép',
                  button: true,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: _onAddTap,
                    radius: 36,
                    splashColor: HomeColors.primary.withValues(alpha: 0.15),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  NavBarColors.fabStart,
                                  NavBarColors.fabEnd,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isAddActive
                                      ? HomeColors.primary.withValues(alpha: 0.5)
                                      : NavBarColors.fabGlow,
                                  blurRadius: isAddActive ? 12 : 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: isAddActive
                                  ? Border.all(
                                      color: HomeColors.milestoneAccent,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.add_rounded,
                                color: NavBarColors.fabIcon,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Ghi chép',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: HomeColors.reminderCta,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _NavigationItem(
                label: 'Khám phá',
                selected: widget.selected == 'Khám phá',
                outlineAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-explore-outline.svg',
                solidAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-explore-solid.svg',
                onTap: () => _onNavigationTap('Khám phá'),
              ),
              _NavigationItem(
                label: 'Cá nhân',
                selected: widget.selected == 'Cá nhân',
                outlineAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-profile-outline.svg',
                solidAsset:
                    '${AppBottomNavigationBar._iconsPath}nav-account-solid.svg',
                onTap: () => _onNavigationTap('Cá nhân'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.selected,
    required this.outlineAsset,
    required this.solidAsset,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final String outlineAsset;
  final String solidAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: HomeColors.primary.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppLayout.minimumTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? NavBarColors.activeIndicator
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SvgPicture.asset(
                    selected ? solidAsset : outlineAsset,
                    width: 22,
                    height: 22,
                    semanticsLabel: label,
                    colorFilter: ColorFilter.mode(
                      selected
                          ? NavBarColors.activeIcon
                          : NavBarColors.inactiveIcon,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: -0.2,
                    color: selected
                        ? NavBarColors.activeLabel
                        : NavBarColors.inactiveLabel,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
