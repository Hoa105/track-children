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
  bool _addSelected = false;

  void _onNavigationTap(String destination) {
    if (_addSelected) setState(() => _addSelected = false);
    widget.onTap(destination);
  }

  void _onAddTap() {
    setState(() => _addSelected = true);
    widget.onTap('Tạo ghi chép');
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppLayout.smallGap),
          child: Row(
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
                child: Center(
                  heightFactor: 1,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _onAddTap,
                    child: SvgPicture.asset(
                      '${AppBottomNavigationBar._iconsPath}${_addSelected || widget.selected == 'Tạo ghi chép' ? 'nav-add-solid.svg' : 'nav-add-outline.svg'}',
                      width: 54,
                      height: 54,
                      semanticsLabel: 'Tạo ghi chép',
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
  );
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
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppLayout.minimumTouchTarget,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              selected ? solidAsset : outlineAsset,
              width: 24,
              height: 24,
              semanticsLabel: label,
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: selected ? AppColors.primary : const Color(0xFF858B95),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
