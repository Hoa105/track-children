import '../../services/demo_store.dart';

import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../navigation/app_bottom_navigation_bar.dart';
import '../settings/settings_screen.dart';
import '../child/child_profile_screen.dart';
import '../growth/growth_screen.dart';

class _HomeHeroPreview {
  const _HomeHeroPreview({
    required this.ageLabel,
    required this.backgroundAsset,
    required this.characterAsset,
    required this.headline,
    required this.message,
    required this.characterOnLeft,
    required this.characterWidthFraction,
    this.characterScale = 1,
    this.characterOffsetX = 0,
  });

  final String ageLabel;
  final String backgroundAsset;
  final String characterAsset;
  final String headline;
  final String message;
  final bool characterOnLeft;
  final double characterWidthFraction;
  final double characterScale;
  final double characterOffsetX;
}

const _homeHeroPreviews = <_HomeHeroPreview>[
  _HomeHeroPreview(
    ageLabel: '0–3 tháng',
    backgroundAsset: 'assets/images/scenery/backgrounds/hero_0_3_months.png',
    characterAsset: 'assets/images/scenery/characters/baby_boy_0_3_months.png',
    headline: 'Chào bé đến\nvới thế giới',
    message: 'Cùng chăm sóc và theo dõi những tháng đầu đời của bé.',
    characterOnLeft: true,
    characterWidthFraction: .62,
    characterScale: AppLayout.homeHeroSmallCharacterScale,
    characterOffsetX: -AppLayout.homeHeroCharacterLeftShift,
  ),
  _HomeHeroPreview(
    ageLabel: '4–6 tháng',
    backgroundAsset: 'assets/images/scenery/backgrounds/hero_4_6_months.png',
    characterAsset: 'assets/images/scenery/characters/baby_boy_4_6_months.png',
    headline: 'Bé khám phá\nxung quanh',
    message: 'Mỗi ngày là một trải nghiệm mới cùng bé.',
    characterOnLeft: false,
    characterWidthFraction: .66,
    characterScale: AppLayout.homeHeroSmallCharacterScale,
  ),
  _HomeHeroPreview(
    ageLabel: '7–9 tháng',
    backgroundAsset: 'assets/images/scenery/backgrounds/hero_7_9_months.png',
    characterAsset: 'assets/images/scenery/characters/baby_boy_7_9_months.png',
    headline: 'Bé ngày càng\ncứng cáp',
    message: 'Ghi lại những bước tiến nhỏ của bé mỗi ngày.',
    characterOnLeft: true,
    characterWidthFraction: .64,
    characterOffsetX: -AppLayout.homeHeroCharacterLeftShift,
  ),
  _HomeHeroPreview(
    ageLabel: '10–12 tháng',
    backgroundAsset: 'assets/images/scenery/backgrounds/hero_10_12_months.png',
    characterAsset:
        'assets/images/scenery/characters/baby_boy_10_12_months.png',
    headline: 'Cùng bé bước\nđến tuổi lên một',
    message: 'Đồng hành cùng bé trong cột mốc đầu đời.',
    characterOnLeft: false,
    characterWidthFraction: .60,
  ),
  _HomeHeroPreview(
    ageLabel: '1–3 tuổi',
    backgroundAsset: 'assets/images/scenery/backgrounds/hero_1_3_years.png',
    characterAsset: 'assets/images/scenery/characters/boy_1_3_years.png',
    headline: 'Cùng bé học\nđiều mới',
    message: 'Khuyến khích bé khám phá và tự tin mỗi ngày.',
    characterOnLeft: true,
    characterWidthFraction: .60,
  ),
  _HomeHeroPreview(
    ageLabel: '4–5 tuổi',
    backgroundAsset: 'assets/images/scenery/backgrounds/hero_4_5_years.png',
    characterAsset: 'assets/images/scenery/characters/boy_4_5_years.png',
    headline: 'Bé lớn khôn\nvà tự tin',
    message: 'Cùng lưu giữ hành trình trưởng thành của bé.',
    characterOnLeft: false,
    characterWidthFraction: .64,
    characterScale: AppLayout.homeHeroSmallCharacterScale,
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.childName,
    this.heroAgeIndex = 0,
    this.onLogout,
    super.key,
  }) : assert(heroAgeIndex >= 0 && heroAgeIndex < 6);

  /// Selects the existing age artwork without exposing preview controls.
  final int heroAgeIndex;

  final String childName;
  final VoidCallback? onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with DemoStoreBinding {
  final _scrollController = ScrollController();
  final _backgroundScale = ValueNotifier<double>(1.08);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateBackgroundScale);
  }

  void _updateBackgroundScale() {
    final progress = (_scrollController.offset / 180).clamp(0.0, 1.0);
    _backgroundScale.value = 1.08 - (0.08 * progress);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateBackgroundScale)
      ..dispose();
    _backgroundScale.dispose();
    super.dispose();
  }

  static const _shortcuts = <_Shortcut>[
    _Shortcut('Lượng sữa', '3/5 bữa', 'milk_bottle.png'),
    _Shortcut('Tiêm chủng', 'Còn 1 mũi', 'vaccination_syringe.png'),
    _Shortcut('Mọc răng', 'Đang theo dõi', 'tooth.png'),
    _Shortcut('Hoạt động', 'Đạt 4/5', 'activity_blocks.png'),
    _Shortcut('Nhật ký', '3 ghi chú mới', 'diary_book.png'),
  ];

  void _comingSoon(BuildContext context, String label) {
    if (label == 'Theo dõi nhanh') {
      _openGrowth();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label sẽ được làm ở bước sau.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          onLogout: widget.onLogout,
          childName:
              DemoStore.instance.child?['full_name'] as String? ??
              widget.childName,
        ),
      ),
    );
  }

  void _openGrowth() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GrowthScreen(
          childName:
              DemoStore.instance.child?['full_name'] as String? ??
              widget.childName,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = DemoStore.instance.child;
    final currentName = active?['full_name'] as String? ?? widget.childName;
    final name = currentName.trim().isEmpty ? 'Bé An' : currentName.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final topInset = MediaQuery.paddingOf(context).top;
                      final widthBasedHeight = (constraints.maxWidth * .78)
                          .clamp(248.0, 320.0)
                          .toDouble();
                      final heroHeight =
                          widthBasedHeight * AppLayout.homeHeroHeightFactor;
                      final months = active == null
                          ? null
                          : int.parse(
                              DemoStore.instance
                                  .ageLabel(active)
                                  .split(' ')
                                  .first,
                            );
                      final ageIndex = months == null
                          ? widget.heroAgeIndex
                          : months < 4
                          ? 0
                          : months < 7
                          ? 1
                          : months < 10
                          ? 2
                          : months < 13
                          ? 3
                          : months < 48
                          ? 4
                          : 5;
                      final preview = _homeHeroPreviews[ageIndex];
                      return Stack(
                        key: const ValueKey('home-hero'),
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _HomeTopBackdrop(
                                scale: _backgroundScale,
                                preview: preview,
                              ),
                            ),
                          ),
                          Positioned(
                            top:
                                topInset +
                                AppLayout.minimumTouchTarget +
                                AppLayout.smallGap,
                            bottom: AppLayout.mediumGap,
                            left: preview.characterOnLeft
                                ? AppLayout.smallGap + preview.characterOffsetX
                                : null,
                            right: preview.characterOnLeft
                                ? null
                                : AppLayout.smallGap - preview.characterOffsetX,
                            width:
                                constraints.maxWidth *
                                AppLayout.homeHeroCharacterWidthFraction *
                                preview.characterScale,
                            child: IgnorePointer(
                              child: Image.asset(
                                preview.characterAsset,
                                key: const ValueKey('home-hero-character'),
                                fit: BoxFit.contain,
                                alignment: preview.characterOnLeft
                                    ? Alignment.bottomLeft
                                    : Alignment.bottomRight,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: topInset + 8),
                            child: _HomeTopSection(
                              name: name,
                              heroHeight: heroHeight,
                              preview: preview,
                              onProfileTap: () =>
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => ChildProfileScreen(
                                        initialFields:
                                            active ?? {'full_name': name},
                                        onSave: active == null
                                            ? null
                                            : (fields, avatar) => DemoStore
                                                  .instance
                                                  .saveChild(
                                                    active['id'] as String,
                                                    fields,
                                                  )
                                                  .then((_) {}),
                                      ),
                                    ),
                                  ),
                              onSettingsTap: _openSettings,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Transform.translate(
                    offset: const Offset(0, -AppLayout.homeHeroOverlap),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _CareCard(onTap: (s) => _comingSoon(context, s)),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.list(
                children: [
                  _GrowthCards(),
                  const SizedBox(height: 14),
                  _TimelineCard(
                    onTap: () => _comingSoon(context, 'Hành trình phát triển'),
                  ),
                  const SizedBox(height: 14),
                  _JournalCard(onTap: () => _comingSoon(context, 'Nhật ký')),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        onTap: (label) {
          if (label == 'Cá nhân') {
            _openSettings();
          } else if (label == 'Theo dõi') {
            _openGrowth();
          } else if (label != 'Trang chủ') {
            _comingSoon(context, label);
          }
        },
      ),
    );
  }
}

class _HomeTopSection extends StatelessWidget {
  const _HomeTopSection({
    required this.name,
    required this.heroHeight,
    required this.preview,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  final String name;
  final double heroHeight;
  final _HomeHeroPreview preview;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _ProfileHeader(
          name: name,
          onTap: onProfileTap,
          onSettingsTap: onSettingsTap,
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.pagePadding,
          0,
          AppLayout.pagePadding,
          AppLayout.mediumGap,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final message = _HeroBanner(preview: preview);
            // Keep content sizing independent of the artwork painted below it.
            final characterSpace =
                (constraints.maxWidth * preview.characterWidthFraction)
                    .clamp(0.0, heroHeight)
                    .toDouble();
            final textInset = characterSpace + AppLayout.smallGap;
            // Stack only when a side-by-side message would be too narrow.
            final stacked =
                constraints.maxWidth < 288 ||
                constraints.maxWidth - textInset <
                    AppLayout.homeHeroMessageMinWidth ||
                MediaQuery.textScalerOf(context)
                        .scale(AppLayout.homeHeroTitleSize) >
                    32;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  message,
                  const SizedBox(height: AppLayout.mediumGap),
                  SizedBox(height: heroHeight),
                ],
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    heroHeight +
                    AppLayout.minimumTouchTarget +
                    AppLayout.smallGap,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.characterOnLeft) ...[
                    SizedBox(width: characterSpace),
                    const SizedBox(width: AppLayout.smallGap),
                  ],
                  Expanded(child: message),
                  if (!preview.characterOnLeft) ...[
                    const SizedBox(width: AppLayout.smallGap),
                    SizedBox(width: characterSpace),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _HomeTopBackdrop extends StatelessWidget {
  const _HomeTopBackdrop({required this.scale, required this.preview});

  final ValueListenable<double> scale;
  final _HomeHeroPreview preview;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipRect(
        child: AnimatedBuilder(
          animation: scale,
          builder: (context, child) => Transform.scale(
            scale: scale.value,
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: Image.asset(
            preview.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: AppLayout.homeHeroFadeExtent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0),
                AppColors.background.withValues(alpha: .25),
                AppColors.background.withValues(alpha: .85),
                AppColors.background,
              ],
              stops: const [0, .3, .72, 1],
            ),
          ),
        ),
      ),
    ],
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.onTap,
    required this.onSettingsTap,
  });
  final String name;
  final VoidCallback onTap;
  final VoidCallback onSettingsTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        Container(
          width: AppLayout.minimumTouchTarget,
          height: AppLayout.minimumTouchTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x1A194C3C), blurRadius: 8),
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
                  color: AppColors.primary,
                  size: 28,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DemoStore.instance.parent['role'] == 'father'
                      ? 'Chào bố,'
                      : DemoStore.instance.parent['role'] == 'guardian'
                      ? 'Chào bạn,'
                      : 'Chào mẹ,',
                  style: TextStyle(color: AppColors.primaryDark, fontSize: 13),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
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
                      ? '24 tháng · 12,5 kg · 85 cm'
                      : '${DemoStore.instance.ageLabel(DemoStore.instance.child!)} · ${DemoStore.instance.latest(DemoStore.instance.child!['id'] as String, 0) ?? '—'} kg · ${DemoStore.instance.latest(DemoStore.instance.child!['id'] as String, 1) ?? '—'} cm',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppLayout.homeHeroBodySize,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppLayout.smallGap),
        if (constraints.maxWidth < 328 ||
            MediaQuery.textScalerOf(context)
                    .scale(AppLayout.homeProfileNameSize) >
                32)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundAction(
                asset: 'assets/images/scenery/icons/ui/notification_bell.svg',
                dot: true,
                onTap: () {},
              ),
              const SizedBox(height: AppLayout.smallGap),
              _RoundAction(
                asset: 'assets/images/scenery/icons/ui/settings_sliders.svg',
                onTap: onSettingsTap,
              ),
            ],
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundAction(
                asset: 'assets/images/scenery/icons/ui/notification_bell.svg',
                dot: true,
                onTap: () {},
              ),
              const SizedBox(width: AppLayout.smallGap),
              _RoundAction(
                asset: 'assets/images/scenery/icons/ui/settings_sliders.svg',
                onTap: onSettingsTap,
              ),
            ],
          ),
      ],
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.asset,
    required this.onTap,
    this.dot = false,
  });
  final String asset;
  final VoidCallback onTap;
  final bool dot;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(asset, width: 24, height: 24),
            if (dot)
              Positioned(
                right: 10,
                top: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE65F5F),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.preview});
  final _HomeHeroPreview preview;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 340;
    return _FrostedHeroPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.headline,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: compact
                  ? AppLayout.homeHeroCompactTitleSize
                  : AppLayout.homeHeroTitleSize,
              height: 1.15,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Color(0x80FFF9EE), blurRadius: 8)],
            ),
          ),
          const SizedBox(height: AppLayout.smallGap),
          Text(
            preview.message,
            style: TextStyle(
              color: const Color(0xFF304442),
              fontSize: AppLayout.homeHeroBodySize,
              height: 1.35,
              shadows: const [Shadow(color: Color(0xA6FFF9EE), blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedHeroPanel extends StatelessWidget {
  const _FrostedHeroPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ClipRRect(
      key: const ValueKey('home-hero-message'),
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: AppLayout.homeHeroPanelBlur,
          sigmaY: AppLayout.homeHeroPanelBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.heroPanel.withValues(alpha: .58),
                AppColors.heroPanel.withValues(alpha: .42),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppLayout.mediumGap),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _Shortcut {
  const _Shortcut(this.label, this.status, this.iconAsset);
  final String label, status, iconAsset;
}

class _CareCard extends StatelessWidget {
  const _CareCard({required this.onTap});
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('home-care-card'),
    padding: const EdgeInsets.all(AppLayout.pagePadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D194C3C),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onTap('Theo dõi nhanh'),
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppLayout.minimumTouchTarget,
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hôm nay bé cần gì?',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF183257),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppLayout.mediumGap),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: AppLayout.mediumGap,
          runSpacing: AppLayout.mediumGap,
          children: [
            for (final item in _HomeScreenState._shortcuts)
              _CareItem(
                item: _Shortcut(
                  item.label,
                  (DemoStore.instance.child?['care'] as Map?)?[item.label]
                          as String? ??
                      item.status,
                  item.iconAsset,
                ),
                onTap: () => onTap(item.label),
              ),
          ],
        ),
      ],
    ),
  );
}

class _CareItem extends StatelessWidget {
  const _CareItem({required this.item, required this.onTap});
  final _Shortcut item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppLayout.homeCareIconSize + AppLayout.smallGap * 2,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '${item.label}: ${item.status}',
          child: Semantics(
            label: '${item.label}, ${item.status}',
            button: true,
            child: Material(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed) ||
                      states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)) {
                    return AppColors.primary.withValues(alpha: .32);
                  }
                  return null;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(AppLayout.smallGap),
                  child: Image.asset(
                    'assets/images/scenery/icons/care/${item.iconAsset}',
                    width: AppLayout.homeCareIconSize,
                    height: AppLayout.homeCareIconSize,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppLayout.smallGap),
        Text(
          item.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF173052),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.status,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _GrowthCards extends StatelessWidget {
  const _GrowthCards();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final store = DemoStore.instance;
      final child = store.child;
      String value(int metric, String fallback) => child == null
          ? fallback
          : '${store.latest(child['id'] as String, metric)?.toStringAsFixed(1) ?? '?'} ${metric == 0 ? 'kg' : 'cm'}';
      String change(int metric, String fallback) {
        if (child == null) return fallback;
        final records = store
            .records(child['id'] as String)
            .where((r) => r['v$metric'] != null)
            .toList();
        if (records.length < 2) return 'Số đo đầu tiên';
        final delta =
            (records.last['v$metric'] as num) -
            (records[records.length - 2]['v$metric'] as num);
        return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${metric == 0 ? 'kg' : 'cm'}';
      }

      List<double> trend(int metric, List<double> fallback) {
        if (child == null) return fallback;
        final values = store
            .records(child['id'] as String)
            .where((r) => r['v$metric'] != null)
            .map((r) => (r['v$metric'] as num).toDouble())
            .toList();
        if (values.isEmpty) return [.5];
        final lo = values.reduce((a, b) => a < b ? a : b),
            hi = values.reduce((a, b) => a > b ? a : b);
        return values
            .map((v) => hi == lo ? .5 : .15 + (v - lo) / (hi - lo) * .7)
            .toList();
      }

      final cards = [
        _MetricCard(
          iconAsset: 'assets/images/scenery/icons/ui/bamboo_segment-solid.svg',
          label: 'Cân nặng',
          value: value(0, '12,5 kg'),
          change: change(0, '↑ +0,3kg'),
          trend: trend(0, [.25, .5, .65, .82]),
        ),
        _MetricCard(
          iconAsset: 'assets/images/scenery/icons/ui/ruler-solid.svg',
          label: 'Chiều cao',
          value: value(1, '85 cm'),
          change: change(1, '↑ +1,2cm'),
          trend: trend(1, [.2, .42, .48, .75, .9]),
        ),
      ];
      final stacked =
          constraints.maxWidth < 328 ||
          MediaQuery.textScalerOf(context).scale(20) > 28;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cards[0],
            const SizedBox(height: AppLayout.mediumGap),
            cards[1],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 10),
          Expanded(child: cards[1]),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.change,
    required this.trend,
  });
  final String iconAsset;
  final String label, value, change;
  final List<double> trend;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 126),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x09194C3C),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primarySoft,
              child: iconAsset.endsWith('.svg')
                  ? SvgPicture.asset(iconAsset, width: 24, height: 24)
                  : Image.asset(iconAsset, width: 24, height: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF183257),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppLayout.smallGap,
          runSpacing: AppLayout.smallGap,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4E4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                change,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 58,
              height: 30,
              child: CustomPaint(painter: _SparkPainter(trend)),
            ),
          ],
        ),
        const Text(
          'so với tháng trước',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    ),
  );
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final pt = Offset(
        values.length == 1 ? s.width / 2 : s.width * i / (values.length - 1),
        s.height * (1 - values[i]),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
      c.drawCircle(pt, 2.2, Paint()..color = AppColors.primary);
    }
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}

int get _currentAgeMilestoneIndex {
  final child = DemoStore.instance.child;
  if (child == null) return 0;
  final months = int.parse(DemoStore.instance.ageLabel(child).split(' ').first);
  return months < 4
      ? 0
      : months < 7
      ? 1
      : months < 10
      ? 2
      : months < 13
      ? 3
      : months < 48
      ? 4
      : 5;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.onTap});
  final VoidCallback onTap;
  static const ages = [
    '0–3 tháng',
    '4–6 tháng',
    '7–9 tháng',
    '10–12 tháng',
    '1–3 tuổi',
    '4–5 tuổi',
  ];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x09194C3C), blurRadius: 12)],
    ),
    child: Column(
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/images/scenery/icons/ui/bamboo_segment-solid.svg',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Hành trình lớn khôn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF183257),
                ),
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text(
                'Xem tất cả  ›',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppLayout.mediumGap),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < ages.length; i++)
                  SizedBox(
                    width: MediaQuery.textScalerOf(context)
                        .scale(72)
                        .clamp(72.0, 144.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 8,
                          child: i == _currentAgeMilestoneIndex
                              ? const Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox.square(dimension: 6),
                                  ),
                                )
                              : null,
                        ),
                        Image.asset(
                          _ageMilestoneAssets[i][i == _currentAgeMilestoneIndex
                              ? 1
                              : 0],
                          width: 58,
                          height: 72,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ages[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: i == _currentAgeMilestoneIndex
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            fontWeight: i == _currentAgeMilestoneIndex
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5E9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/images/scenery/icons/ui/bamboo_segment-solid.svg',
                width: 23,
                height: 23,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  DemoStore.instance.child == null ? 'Bé đang ở những tháng đầu đời. Ba mẹ cùng theo dõi từng bước phát triển nhé!' : 'Bé đang ở giai đoạn ${DemoStore.instance.ageLabel(DemoStore.instance.child!)}. Cùng theo dõi từng bước phát triển nhé!',
                  style: TextStyle(fontSize: 12, color: Color(0xFF41584D)),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ],
    ),
  );
}

const _ageMilestoneAssets = <List<String>>[
  [
    'assets/images/scenery/icons/age_milestones/stage_01_0_3_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_01_0_3_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_02_4_6_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_02_4_6_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_03_7_9_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_03_7_9_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_04_10_12_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_04_10_12_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_05_1_3_years_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_05_1_3_years_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_06_4_5_years_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_06_4_5_years_active_simple_flat_bright.png',
  ],
];

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x09194C3C), blurRadius: 12)],
    ),
    child: Column(
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/images/scenery/icons/ui/camera-solid.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Nhật ký gần đây',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF183257),
                ),
              ),
            ),
            TextButton(
              onPressed: onTap,
              child: const Text(
                'Xem tất cả  ›',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9D8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  size: 34,
                  color: Color(0xFFD99170),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (DemoStore.instance.child?['journal'] as Map?)?['title']
                              as String? ??
                          'Bé ăn ngon hơn',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF183257),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DemoStore.instance.child == null
                          ? 'Hôm nay, 08:30   ·   Dinh dưỡng'
                          : '${(DemoStore.instance.child?['journal'] as Map?)?['date']?.toString().split('T').first ?? '—'} · ${(DemoStore.instance.child?['journal'] as Map?)?['category'] ?? 'Nhật ký'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz_rounded, color: Colors.blueGrey),
            ],
          ),
        ),
      ],
    ),
  );
}
