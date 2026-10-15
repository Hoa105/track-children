import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import '../activities/activities_screen.dart';
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
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final store = DemoStore.instance;
      final child = store.child;
      final id = child?['id'] as String?;
      final entries = id == null
          ? <Map<String, dynamic>>[]
          : store.journalEntries(id);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text(
            'Khám phá',
            style: TextStyle(fontWeight: FontWeight.w700),
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
                  childName: child?['full_name'] as String? ?? 'Bé',
                  onLogout: onLogout,
                ),
              );
              return;
            }
            if (id == null) return;
            if (label == 'Theo dõi') {
              _open(
                context,
                GrowthScreen(
                  childName: child!['full_name'] as String,
                  onLogout: onLogout,
                ),
              );
            } else if (label == 'Tạo ghi chép') {
              _open(context, JournalEditorScreen(childId: id));
            }
          },
        ),
        body: child == null
            ? const Center(
                child: Text('Chọn hồ sơ bé để khám phá hành trình lớn khôn.'),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE1EDD6), Color(0xFFF3E8D2)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.spa_outlined,
                          color: AppColors.primary,
                          size: 36,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Mỗi ngày một chút lớn khôn',
                          style: TextStyle(
                            fontSize: 25,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Cùng nhìn lại những dấu mốc đáng nhớ của ${child['full_name']}.',
                          style: const TextStyle(
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          store.ageLabel(child),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Hành trình của bé'),
                  const SizedBox(height: 12),
                  _ExploreTile(
                    title: 'Lịch sử nhật ký',
                    subtitle:
                        '${entries.length} ghi chép · Những khoảnh khắc bên bé',
                    icon: Icons.auto_stories_outlined,
                    tint: const Color(0xFFFFE8CF),
                    onTap: () => _open(context, JournalScreen(childId: id!)),
                  ),
                  _ExploreTile(
                    title: 'Lịch sử đánh giá toàn diện',
                    subtitle: 'Nhìn lại các mốc phát triển của bé',
                    icon: Icons.fact_check_outlined,
                    tint: AppColors.purpleSurfaceLight,
                    onTap: () =>
                        _open(context, const AssessmentHistoryScreen()),
                  ),
                  _ExploreTile(
                    title: 'Lịch sử tăng trưởng',
                    subtitle:
                        '${store.records(id!).length} lần đo · Chiều cao, cân nặng',
                    icon: Icons.insights_rounded,
                    tint: AppColors.primarySoft,
                    onTap: () => _open(
                      context,
                      GrowthScreen(childName: child['full_name'] as String),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle('Cùng chăm sóc, cùng khám phá'),
                  const SizedBox(height: 12),
                  _ExploreTile(
                    title: 'Hoạt động cùng bé',
                    subtitle: 'Gợi ý vui chơi theo độ tuổi',
                    icon: Icons.extension_outlined,
                    tint: const Color(0xFFFFE8CF),
                    onTap: () => _open(context, ActivitiesScreen(childId: id)),
                  ),
                  _ExploreTile(
                    title: 'Tiêm chủng',
                    subtitle: 'Lịch hẹn và các mũi tiêm đã ghi nhận',
                    icon: Icons.vaccines_outlined,
                    tint: const Color(0xFFE1EBFF),
                    onTap: () => _open(context, VaccinationScreen(childId: id)),
                  ),
                  _ExploreTile(
                    title: 'Hành trình mọc răng',
                    subtitle: 'Lưu lại từng chiếc răng nhỏ',
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    tint: AppColors.purpleSurfaceLight,
                    onTap: () => _open(context, TeethingScreen(childId: id)),
                  ),
                ],
              ),
      );
    },
  );
}

class AssessmentHistoryScreen extends StatelessWidget {
  const AssessmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Lịch sử đánh giá toàn diện'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.purpleSurfaceLight,
              child: Icon(
                Icons.fact_check_outlined,
                size: 40,
                color: AppColors.purpleText,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Chưa có lịch sử đánh giá'),
            const SizedBox(height: 12),
            const Text(
              'Kết quả đánh giá toàn diện chưa được kết nối trong phiên bản hiện tại. Khi có dữ liệu, bạn có thể xem lại hành trình phát triển của bé tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tiếp tục khám phá'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
