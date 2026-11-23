import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import 'assessment_models.dart';
import 'assessment_video.dart';

const assessmentBody = TextStyle(
  fontSize: 14.5,
  height: 1.55,
  color: AssessmentColors.textPrimary,
);
const assessmentMuted = TextStyle(
  fontSize: 13,
  height: 1.5,
  color: AssessmentColors.muted,
);

/// Local styling keeps the assessment consistent without changing other flows.
class AssessmentScaffold extends StatelessWidget {
  const AssessmentScaffold({
    super.key,
    this.backgroundColor,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
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
            backgroundColor: AssessmentColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            shape: shape,
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AssessmentColors.primaryDark,
            minimumSize: const Size(48, 54),
            side: const BorderSide(color: AssessmentColors.border, width: 1.2),
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
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
                  ? AssessmentColors.primary
                  : AssessmentColors.surface,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : AssessmentColors.muted,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AssessmentColors.border),
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
        backgroundColor: backgroundColor ?? AssessmentColors.background,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
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
  'fine_motor' => AssessmentColors.fineMotor,
  'language_communication' => AssessmentColors.language,
  'cognitive' => AssessmentColors.cognitive,
  'social_emotional' => AssessmentColors.socialEmotional,
  _ => AssessmentColors.grossMotor,
};

class AssessmentIconBadge extends StatelessWidget {
  const AssessmentIconBadge(
    this.icon, {
    super.key,
    this.color = AssessmentColors.primary,
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
              color: color.withValues(alpha: .08),
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
                color.withValues(alpha: .15),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(size * .25),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
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
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AssessmentColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 12,
        runSpacing: 10,
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
                    size: 40,
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF6F9F1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AssessmentColors.cardBorder),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AssessmentColors.iconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                size: 16,
                color: AssessmentColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cách quan sát',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AssessmentColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(text, style: assessmentBody),
      ],
    ),
  );
}

class AssessmentDomainLabel extends StatelessWidget {
  const AssessmentDomainLabel(this.domain, {super.key});
  final String? domain;
  @override
  Widget build(BuildContext context) {
    final color = assessmentDomainColor(domain);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AssessmentIconBadge(
          assessmentDomainIcon(domain),
          color: color,
          size: 34,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            assessmentDomains[domain] ?? '',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
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
        offset: Offset(0, 10 * (1 - value)),
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
    builder: (context, animated, _) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: animated,
        minHeight: 8,
        backgroundColor: AssessmentColors.iconBackground.withValues(alpha: .5),
        color: AssessmentColors.primary,
      ),
    ),
  );
}

AppBar assessmentAppBar(String title, {VoidCallback? back, List<Widget>? actions}) =>
    AppBar(
      backgroundColor: AssessmentColors.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 60,
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: AssessmentColors.primaryDark,
          ),
          onPressed: back ?? () => Navigator.pop(context),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 19.5,
          fontWeight: FontWeight.w800,
          color: AssessmentColors.textPrimary,
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
          radius: 24,
          backgroundColor: AssessmentColors.primarySoft,
          child: Text(
            name.isEmpty ? 'B' : name.substring(0, 1),
            style: const TextStyle(
              color: AssessmentColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
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
                  color: AssessmentColors.textPrimary,
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
    this.accent = AssessmentColors.primary,
    this.tint = AssessmentColors.surface,
    required this.child,
  });
  final String? title;
  final IconData? icon;
  final Widget child;
  final bool featured;
  final Color accent, tint;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: tint,
      gradient: featured
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AssessmentColors.heroGradientStart,
                AssessmentColors.heroGradientEnd,
                AssessmentColors.surface,
              ],
            )
          : null,
      borderRadius: BorderRadius.circular(featured ? 26 : 22),
      border: Border.all(
        color: featured ? AssessmentColors.border : AssessmentColors.cardBorder,
        width: featured ? 1.2 : 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: AssessmentColors.cardShadow,
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
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
                            fontSize: featured ? 22 : 17.5,
                            fontWeight: FontWeight.w800,
                            color: AssessmentColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: neutral ? const Color(0xFFE4EDE0) : AssessmentColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: neutral ? AssessmentColors.muted : AssessmentColors.textSecondary,
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
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      selected: selected,
      button: true,
      child: AssessmentPress(
        enabled: onTap != null,
        child: AnimatedScale(
          scale: selected && !MediaQuery.disableAnimationsOf(context)
              ? 1.012
              : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            animationDuration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
            ),
            color: selected ? AssessmentColors.primarySoft : AssessmentColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected ? AssessmentColors.primary : AssessmentColors.cardBorder,
                width: selected ? 1.8 : 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AssessmentColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AssessmentColors.primary
                              : switch (label) {
                                  'Đã làm được' => AssessmentColors.achieved,
                                  'Chưa làm được' => AssessmentColors.notYet,
                                  'Chưa quan sát' => AssessmentColors.notObserved,
                                  _ => AssessmentColors.muted,
                                },
                          width: selected ? 0 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : switch (label) {
                                  'Đã làm được' => Icons.check_rounded,
                                  'Chưa làm được' => Icons.hourglass_empty_rounded,
                                  'Chưa quan sát' => Icons.visibility_outlined,
                                  _ => Icons.circle,
                                },
                          size: 15,
                          color: selected
                              ? Colors.white
                              : switch (label) {
                                  'Đã làm được' => AssessmentColors.achieved,
                                  'Chưa làm được' => AssessmentColors.notYet,
                                  'Chưa quan sát' => AssessmentColors.notObserved,
                                  _ => Colors.transparent,
                                },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.4,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected
                              ? AssessmentColors.primaryDark
                              : AssessmentColors.textPrimary,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AssessmentColors.primary,
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
              height: 8,
              child: Row(
                children: [
                  for (final key in assessmentAnswers.keys)
                    if ((summary[key] as num? ?? 0) > 0)
                      Expanded(
                        flex: (summary[key] as num).toInt(),
                        child: ColoredBox(
                          color: switch (key) {
                            'achieved' => AssessmentColors.achieved,
                            'not_yet' => AssessmentColors.notYet,
                            _ => AssessmentColors.notObserved,
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
      for (final v in assessmentAnswers.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                switch (v.key) {
                  'achieved' => Icons.check_circle_rounded,
                  'not_yet' => Icons.more_time_rounded,
                  _ => Icons.visibility_outlined,
                },
                color: switch (v.key) {
                  'achieved' => AssessmentColors.achieved,
                  'not_yet' => AssessmentColors.notYet,
                  _ => AssessmentColors.notObserved,
                },
                size: 20,
              ),
              const SizedBox(width: 10),
              Container(
                width: MediaQuery.textScalerOf(context).scale(34),
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: switch (v.key) {
                    'achieved' => AssessmentColors.achievedSoft,
                    'not_yet' => AssessmentColors.notYetSoft,
                    _ => AssessmentColors.notObservedSoft,
                  },
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summary[v.key] ?? 0}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: switch (v.key) {
                      'achieved' => AssessmentColors.primaryDark,
                      'not_yet' => AssessmentColors.notYet,
                      _ => AssessmentColors.notObserved,
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(v.value, style: assessmentBody),
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
