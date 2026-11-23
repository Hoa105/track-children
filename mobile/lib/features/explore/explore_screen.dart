import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import '../activities/activities_screen.dart';
import '../assessment/assessment_screen.dart';
import '../feeding/milk_calculator_screen.dart';
import '../growth/growth_screen.dart';
import '../journal/journal_screen.dart';
import '../navigation/app_bottom_navigation_bar.dart';
import '../settings/settings_screen.dart';
import '../teething/teething_screen.dart';
import '../vaccination/vaccination_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: DemoStore.instance,
        builder: (context, _) {
          final store = DemoStore.instance;
          final child = store.child;

          if (child == null) {
            return Scaffold(
              backgroundColor: ExploreColors.background,
              appBar: AppBar(
                backgroundColor: ExploreColors.background,
                scrolledUnderElevation: 0,
                elevation: 0,
                centerTitle: false,
                title: const Text(
                  'Khám phá',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ExploreColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              bottomNavigationBar: AppBottomNavigationBar(
                selected: 'Khám phá',
                onTap: (label) {
                  if (label == 'Trang chủ') {
                    Navigator.of(context).popUntil(
                      (route) => route.settings.name == '/home' || route.isFirst,
                    );
                    return;
                  }
                  if (label == 'Cá nhân') {
                    _open(
                      context,
                      SettingsScreen(
                        childName: 'Bé',
                        onLogout: onLogout,
                      ),
                    );
                  }
                },
              ),
              body: const _EmptyChildView(),
            );
          }

          final id = child['id'] as String;
          final rawChildName =
              ((child['full_name'] as String?) ?? 'Bé').trim();
          final childName = rawChildName.isEmpty
              ? 'Bé'
              : (rawChildName.toLowerCase().startsWith('bé ')
                  ? rawChildName
                  : (rawChildName.toLowerCase() == 'bé'
                      ? 'Bé'
                      : 'Bé $rawChildName'));
          final entries = store.journalEntries(id);
          final growthCount = store.records(id).length;
          final vaxCount = store.vaccinations(id).length;
          final teethCount = store.teeth(id).length;

          return Scaffold(
            backgroundColor: ExploreColors.background,
            appBar: AppBar(
              backgroundColor: ExploreColors.background,
              scrolledUnderElevation: 0,
              elevation: 0,
              centerTitle: false,
              title: const Text(
                'Khám phá',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ExploreColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            bottomNavigationBar: AppBottomNavigationBar(
              selected: 'Khám phá',
              onTap: (label) {
                if (label == 'Trang chủ') {
                  Navigator.of(context).popUntil(
                    (route) => route.settings.name == '/home' || route.isFirst,
                  );
                  return;
                }
                if (label == 'Cá nhân') {
                  _open(
                    context,
                    SettingsScreen(
                      childName: childName,
                      onLogout: onLogout,
                    ),
                  );
                  return;
                }
                if (label == 'Theo dõi') {
                  _open(
                    context,
                    GrowthScreen(
                      childName: childName,
                      onLogout: onLogout,
                    ),
                  );
                } else if (label == 'Tạo ghi chép' || label == 'Thêm nhật ký') {
                  openAddJournal(context, childId: id);
                }
              },
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
              children: [
                // 1. Hero Card: Thông tin mốc lớn khôn của bé
                _JourneyHeroBanner(
                  childName: childName,
                  ageLabel: store.ageLabel(child),
                  avatarBase64: child['avatar_base64'] as String?,
                  avatarUrl: child['avatar_url'] as String?,
                ),

                const SizedBox(height: 20),

                // 2. Nhóm 1: Hành trình của bé
                const _SectionHeader('Hành trình của bé'),
                _ModernExploreTile(
                  title: 'Lịch sử nhật ký',
                  subtitle:
                      '${entries.length} ghi chép · Những khoảnh khắc đáng nhớ bên bé',
                  icon: Icons.auto_stories_rounded,
                  tint: const Color(0xFFFFE8CF),
                  iconColor: const Color(0xFFD36E1A),
                  onTap: () => _open(context, JournalScreen(childId: id)),
                ),
                _ModernExploreTile(
                  title: 'Lịch sử đánh giá phát triển',
                  subtitle: 'Nhìn lại các mốc phát triển toàn diện của bé',
                  icon: Icons.fact_check_rounded,
                  tint: const Color(0xFFF3E5F5),
                  iconColor: const Color(0xFF8E24AA),
                  onTap: () => _open(
                    context,
                    AssessmentScreen(childId: id, initialHistory: true),
                  ),
                ),
                _ModernExploreTile(
                  title: 'Lịch sử tăng trưởng',
                  subtitle:
                      '$growthCount lần đo · Chiều cao, cân nặng chuẩn WHO',
                  icon: Icons.insights_rounded,
                  tint: const Color(0xFFE5EFE3),
                  iconColor: ExploreColors.primary,
                  onTap: () => _open(
                    context,
                    GrowthScreen(
                      childName: childName,
                      onLogout: onLogout,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Nhóm 2: Cùng chăm sóc, cùng khám phá
                const _SectionHeader('Cùng chăm sóc, cùng khám phá'),
                _ModernExploreTile(
                  title: 'Tính lượng sữa & Cữ bú',
                  subtitle:
                      'Gợi ý cữ bú và lượng ml chuẩn theo cân nặng & ngày tuổi',
                  icon: Icons.local_drink_rounded,
                  tint: const Color(0xFFFFF4D9),
                  iconColor: const Color(0xFFC47B1B),
                  onTap: () =>
                      _open(context, MilkCalculatorScreen(childId: id)),
                ),
                _ModernExploreTile(
                  title: 'Tiêm chủng',
                  subtitle:
                      '$vaxCount mũi đã ghi nhận · Theo dõi lịch hẹn tiêm phòng',
                  icon: Icons.vaccines_rounded,
                  tint: const Color(0xFFE2EDFD),
                  iconColor: const Color(0xFF1E88E5),
                  onTap: () => _open(context, VaccinationScreen(childId: id)),
                ),
                _ModernExploreTile(
                  title: 'Hành trình mọc răng',
                  subtitle:
                      '$teethCount chiếc răng sữa đã mọc · Lưu lại từng chiếc răng nhỏ',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  tint: const Color(0xFFEDE7F6),
                  iconColor: const Color(0xFF7E57C2),
                  onTap: () => _open(context, TeethingScreen(childId: id)),
                ),
                _ModernExploreTile(
                  title: 'Hoạt động cùng bé',
                  subtitle: 'Gợi ý trò chơi tương tác kích thích trí não theo tháng tuổi',
                  icon: Icons.extension_rounded,
                  tint: const Color(0xFFE0F2F1),
                  iconColor: const Color(0xFF00897B),
                  onTap: () => _open(context, ActivitiesScreen(childId: id)),
                ),
              ],
            ),
          );
        },
      );
}

/// Compact & modern Hero Banner
class _JourneyHeroBanner extends StatelessWidget {
  const _JourneyHeroBanner({
    required this.childName,
    required this.ageLabel,
    this.avatarBase64,
    this.avatarUrl,
  });

  final String childName;
  final String ageLabel;
  final String? avatarBase64;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final rawName = childName.trim();
    final displayName = rawName.isEmpty
        ? 'Bé'
        : (rawName.toLowerCase().startsWith('bé ')
            ? rawName
            : (rawName.toLowerCase() == 'bé' ? 'Bé' : 'Bé $rawName'));

    Widget avatarWidget;
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(avatarBase64!);
        avatarWidget = ClipOval(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: 60,
            height: 60,
            errorBuilder: (_, _, _) => const Icon(
              Icons.child_care_rounded,
              color: ExploreColors.primary,
              size: 32,
            ),
          ),
        );
      } catch (_) {
        avatarWidget = const Icon(
          Icons.child_care_rounded,
          color: ExploreColors.primary,
          size: 32,
        );
      }
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatarWidget = ClipOval(
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          errorBuilder: (_, _, _) => const Icon(
            Icons.child_care_rounded,
            color: ExploreColors.primary,
            size: 32,
          ),
        ),
      );
    } else {
      avatarWidget = const Icon(
        Icons.child_care_rounded,
        color: ExploreColors.primary,
        size: 32,
      );
    }

    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ExploreColors.heroGradientStart,
              ExploreColors.heroGradientEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: ExploreColors.border,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: ExploreColors.cardShadow,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: ExploreColors.iconBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: avatarWidget,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ExploreColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ageLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: ExploreColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Mỗi ngày một chút lớn khôn 🌱',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ExploreColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cùng nhìn lại những dấu mốc đáng nhớ và đồng hành trên từng bước phát triển của bé yêu.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: ExploreColors.textPrimary,
              ),
            ),
          ],
        ),
      );
  }
}

/// Clean section header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ExploreColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      );
}

/// Modern feature item tile with clear visual hierarchy, soft colors, and one-handed reach.
class _ModernExploreTile extends StatelessWidget {
  const _ModernExploreTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Material(
          color: ExploreColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ExploreColors.border, width: 1.1),
                boxShadow: const [
                  BoxShadow(
                    color: ExploreColors.cardShadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: ExploreColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: ExploreColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: ExploreColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: ExploreColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Fallback view when no child is selected.
class _EmptyChildView extends StatelessWidget {
  const _EmptyChildView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: ExploreColors.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.child_care_rounded,
                    size: 40,
                    color: ExploreColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa chọn hồ sơ bé',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ExploreColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng chọn hoặc tạo hồ sơ bé để khám phá các tiện ích theo dõi và chăm sóc.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: ExploreColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}
