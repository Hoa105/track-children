import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import 'assessment_models.dart';
import 'assessment_video.dart';

const assessmentBody = TextStyle(
  fontSize: 14,
  height: 1.6,
  color: AppColors.textPrimary,
);
const assessmentMuted = TextStyle(
  fontSize: 13,
  height: 1.5,
  color: AppColors.textSecondary,
);

/// Local styling keeps the assessment consistent without changing other flows.
class AssessmentScaffold extends StatelessWidget {
  const AssessmentScaffold({
    super.key,
    this.backgroundColor,
    this.appBar,
    required this.body,
  });
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget body;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Theme(
      data: base.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            shape: shape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(48, 52),
            side: const BorderSide(color: AppColors.border),
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        expansionTileTheme: const ExpansionTileThemeData(
          shape: Border(),
          collapsedShape: Border(),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.surface,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.border),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.background,
        appBar: appBar,
        body: body,
      ),
    );
  }
}

IconData assessmentDomainIcon(String? domain) => switch (domain) {
  'gross_motor' => Icons.directions_run_rounded,
  'fine_motor' => Icons.back_hand_outlined,
  'language_communication' => Icons.forum_outlined,
  'cognitive' => Icons.extension_outlined,
  'social_emotional' => Icons.favorite_border_rounded,
  _ => Icons.spa_outlined,
};
Color assessmentDomainColor(String? domain) => switch (domain) {
  'fine_motor' => const Color(0xFF805696),
  'language_communication' => const Color(0xFF326D9B),
  'cognitive' => const Color(0xFF91621F),
  'social_emotional' => const Color(0xFFA34D66),
  _ => AppColors.primary,
};

class AssessmentIconBadge extends StatelessWidget {
  const AssessmentIconBadge(
    this.icon, {
    super.key,
    this.color = AppColors.primary,
    this.size = 44,
  });
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -.13,
          child: Container(
            width: size * .9,
            height: size * .9,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(size * .28),
            ),
          ),
        ),
        Transform.rotate(
          angle: .07,
          child: Container(
            width: size * .86,
            height: size * .86,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                color.withValues(alpha: .14),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(size * .25),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: -.07,
              child: Icon(icon, color: color, size: size * .5),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Press feedback shared by answers and compact milestone/filter controls.
class AssessmentPress extends StatefulWidget {
  const AssessmentPress({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<AssessmentPress> createState() => _AssessmentPressState();
}

class _AssessmentPressState extends State<AssessmentPress> {
  bool pressed = false;
  void _set(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled ? (_) => _set(true) : null,
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale:
          pressed && widget.enabled && !MediaQuery.disableAnimationsOf(context)
          ? .975
          : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

class AssessmentDomainTrail extends StatelessWidget {
  const AssessmentDomainTrail({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '5 lĩnh vực phát triển',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 14,
        runSpacing: 12,
        children: [
          for (final domain in assessmentDomains.entries)
            Tooltip(
              message: domain.value,
              child: Semantics(
                label: domain.value,
                child: ExcludeSemantics(
                  child: AssessmentIconBadge(
                    assessmentDomainIcon(domain.key),
                    color: assessmentDomainColor(domain.key),
                    size: 42,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class AssessmentObservation extends StatelessWidget {
  const AssessmentObservation({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF3F5EC),
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cách quan sát',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: assessmentBody),
        ],
      ),
    ),
  );
}

class AssessmentDomainLabel extends StatelessWidget {
  const AssessmentDomainLabel(this.domain, {super.key});
  final String? domain;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      AssessmentIconBadge(
        assessmentDomainIcon(domain),
        color: assessmentDomainColor(domain),
        size: 36,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          assessmentDomains[domain] ?? '',
          style: TextStyle(
            color: assessmentDomainColor(domain),
            fontWeight: FontWeight.w800,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

/// Entrance-only motion. Rebuilds while saving do not replay the transition.
class AssessmentReveal extends StatelessWidget {
  const AssessmentReveal({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    ),
  );
}

class AssessmentProgress extends StatelessWidget {
  const AssessmentProgress({super.key, required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(0, 1)),
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 380,
    ),
    curve: Curves.easeOutCubic,
    builder: (context, animated, _) => LinearProgressIndicator(
      value: animated,
      minHeight: 8,
      borderRadius: BorderRadius.circular(8),
      backgroundColor: AppColors.primarySoft,
      color: AppColors.primary,
    ),
  );
}

AppBar assessmentAppBar(String title, {VoidCallback? back, List<Widget>? actions}) =>
    AppBar(
      backgroundColor: AppColors.background,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: back ?? () => Navigator.pop(context),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
      ),
      actions: actions,
    );

class AssessmentChildHeader extends StatelessWidget {
  const AssessmentChildHeader({super.key, required this.childId});
  final String childId;
  @override
  Widget build(BuildContext context) {
    final child = DemoStore.instance.childById(childId),
        name = child?['full_name'] as String? ?? 'Bé';
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.primarySoft,
          child: Text(
            name.isEmpty ? 'B' : name.substring(0, 1),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (child != null)
                Text(DemoStore.instance.ageLabel(child), style: assessmentMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class AssessmentCard extends StatelessWidget {
  const AssessmentCard({
    super.key,
    this.title,
    this.icon,
    this.featured = false,
    this.accent = AppColors.primary,
    this.tint = AppColors.surface,
    required this.child,
  });
  final String? title;
  final IconData? icon;
  final Widget child;
  final bool featured;
  final Color accent, tint;
  @override
  Widget build(BuildContext context) => Material(
    color: tint,
    shadowColor: AppColors.primaryDark.withValues(alpha: .08),
    elevation: featured ? 2 : 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(featured ? 30 : 24),
      side: BorderSide(
        color: featured ? const Color(0xFFCEE0D2) : AppColors.border,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: featured
          ? const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE1EDD6),
                  Color(0xFFF1E9D4),
                  Color(0xFFFAF7F0),
                ],
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || icon != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    AssessmentIconBadge(icon!, color: accent),
                    const SizedBox(width: 12),
                  ],
                  if (title != null)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: icon == null ? 0 : 8),
                        child: Text(
                          title!,
                          style: TextStyle(
                            fontSize: featured ? 23 : 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.35,
                            letterSpacing: -.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}

class AssessmentPill extends StatelessWidget {
  const AssessmentPill(this.text, {super.key, this.neutral = false});
  final String text;
  final bool neutral;
  @override
  Widget build(BuildContext context) => Align(
    widthFactor: 1,
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: neutral ? AppColors.background : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: neutral ? AppColors.textSecondary : AppColors.primaryDark,
        ),
      ),
    ),
  );
}

class AssessmentChoice extends StatelessWidget {
  const AssessmentChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      selected: selected,
      button: true,
      child: AssessmentPress(
        enabled: onTap != null,
        child: AnimatedScale(
          scale: selected && !MediaQuery.disableAnimationsOf(context)
              ? 1.015
              : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            animationDuration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
            ),
            color: selected ? AppColors.primarySoft : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : switch (label) {
                              'Đã làm được' => Icons.task_alt_rounded,
                              'Chưa làm được' => Icons.more_time_rounded,
                              'Chưa quan sát' => Icons.visibility_outlined,
                              _ => Icons.circle_outlined,
                            },
                      color: selected
                          ? AppColors.primary
                          : switch (label) {
                              'Đã làm được' => AppColors.primary,
                              'Chưa làm được' => const Color(0xFF91621F),
                              'Chưa quan sát' => const Color(0xFF326D9B),
                              _ => AppColors.textSecondary,
                            },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AssessmentCounts extends StatelessWidget {
  const AssessmentCounts({super.key, required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (assessmentAnswers.keys.any(
        (key) => (summary[key] as num? ?? 0) > 0,
      )) ...[
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  for (final key in assessmentAnswers.keys)
                    if ((summary[key] as num? ?? 0) > 0)
                      Expanded(
                        flex: (summary[key] as num).toInt(),
                        child: ColoredBox(
                          color: switch (key) {
                            'achieved' => AppColors.primary,
                            'not_yet' => const Color(0xFFB88535),
                            _ => const Color(0xFF6592B5),
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      for (final v in assessmentAnswers.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 10),
                child: Icon(
                  switch (v.key) {
                    'achieved' => Icons.check_circle_outline_rounded,
                    'not_yet' => Icons.more_time_rounded,
                    _ => Icons.visibility_outlined,
                  },
                  color: switch (v.key) {
                    'achieved' => AppColors.primary,
                    'not_yet' => const Color(0xFF91621F),
                    _ => const Color(0xFF326D9B),
                  },
                  size: 21,
                ),
              ),
              Container(
                width: MediaQuery.textScalerOf(context).scale(34),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: switch (v.key) {
                    'achieved' => AppColors.primarySoft,
                    'not_yet' => const Color(0xFFFFF3DB),
                    _ => const Color(0xFFEAF1F9),
                  },
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summary[v.key] ?? 0}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(v.value, style: assessmentBody),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class AssessmentDemoNote extends StatelessWidget {
  const AssessmentDemoNote({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 10),
    child: Text(
      'Chế độ trải nghiệm · Bài và kết quả minh họa được lưu riêng trên máy.',
      style: assessmentMuted,
    ),
  );
}

class AssessmentError extends StatelessWidget {
  const AssessmentError({
    super.key,
    required this.message,
    required this.retry,
    this.extra,
  });
  final String message;
  final VoidCallback retry;
  final Widget? extra;
  @override
  Widget build(BuildContext context) => AssessmentCard(
    icon: Icons.wifi_off_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: assessmentBody),
        Wrap(
          spacing: 12,
          children: [
            TextButton(onPressed: retry, child: const Text('Thử lại')),
            ?extra,
          ],
        ),
      ],
    ),
  );
}

void assessmentMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
Future<void> assessmentOpenLink(BuildContext context, String raw) async {
  final url = Uri.tryParse(raw);
  try {
    if (url == null ||
        url.scheme != 'https' ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        assessmentMessage(context, 'Chưa mở được liên kết. Vui lòng thử lại.');
      }
    }
  } catch (_) {
    if (context.mounted) {
      assessmentMessage(context, 'Chưa mở được liên kết. Vui lòng thử lại.');
    }
  }
}

List<Widget> assessmentMedia(Map<String, dynamic> payload) {
  final raw = payload['media'];
  final entries = raw is List
      ? raw
      : raw is Map
      ? [raw]
      : [];
  return [
    for (final (index, value) in entries.indexed)
      if (value['type'] == 'image')
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              value['url'] as String,
              fit: BoxFit.contain,
              semanticLabel:
                  value['alt'] as String? ?? 'Ảnh hướng dẫn quan sát kỹ năng',
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, _, _) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chưa tải được ảnh. Bạn vẫn có thể đọc hướng dẫn và trả lời.',
                  style: assessmentMuted,
                ),
              ),
            ),
          ),
        )
      else if (value['type'] == 'youtube')
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AssessmentVideoFrame(
            key: ValueKey(
              'assessment-video-${payload['skill_name']}-$index-${value['youtube_id']}',
            ),
            videoId: (value['youtube_id'] ?? '').toString(),
            caption: value['attribution'] as String?,
            semanticLabel: value['alt'] as String?,
          ),
        ),
  ];
}
