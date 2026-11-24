part of 'activities_screen.dart';

const _groupTints = [
  Color(0xFFE8F4D9), // g0: Gross motor - fresh sprout green
  Color(0xFFFEF3DF), // g1: Fine motor - warm amber
  Color(0xFFE3F1FC), // g2: Language - gentle sky blue
  Color(0xFFFDEBF2), // g3: Cognitive/Social - blossom pink
  Color(0xFFEEE8F8), // g4: Music - soft lavender
  Color(0xFFFFF0E2), // g5: Story - warm peach
];

const _groupAccents = [
  Color(0xFF4A8025), // g0
  Color(0xFFB57218), // g1
  Color(0xFF2069B4), // g2
  Color(0xFFB34272), // g3
  Color(0xFF674898), // g4
  Color(0xFFBD581F), // g5
];

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key, required this.childId});
  final String childId;
  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  int _suggestion = 0;
  int? _minutes;
  Object? _catalogCacheKey;
  List<ChildActivity>? _cachedRanked;
  List<ChildActivity>? _cachedSuggestions;

  @override
  void initState() {
    super.initState();
    // Lấy "Đã làm" / "Yêu thích" mới nhất (vd bố đánh dấu trên máy khác).
    DemoStore.instance.syncActivities(widget.childId);
  }

  @override
  void didUpdateWidget(ActivitiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) {
      DemoStore.instance.syncActivities(widget.childId);
    }
  }

  void _open(ChildActivity a) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          ActivityDetailScreen(childId: widget.childId, activity: a),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([DemoStore.instance, activityCatalogState]),
    builder: (context, _) {
      final store = DemoStore.instance;
      final child = store.childById(widget.childId);
      final reduced = MediaQuery.disableAnimationsOf(context);
      if (child == null) {
        return Scaffold(
          backgroundColor: ActivitiesColors.background,
          appBar: AppBar(
            backgroundColor: ActivitiesColors.background,
            elevation: 0,
            title: const Text('Hoạt động', style: _heading),
          ),
          body: const Center(
            child: Text(
              'Chọn hồ sơ bé để xem hoạt động.',
              style: _secondary,
            ),
          ),
        );
      }
      final done = store.completedActivities(widget.childId);
      final favorites = store.favoriteActivities;
      final childName = (child['first_name'] as String?)?.trim().isNotEmpty == true
          ? (child['first_name'] as String).trim()
          : (child['full_name'] as String?)?.trim().isNotEmpty == true
          ? (child['full_name'] as String).trim()
          : 'bé';
      final age = WhoBmiReference.ageMonths(
        DateTime.parse(child['date_of_birth'] as String),
        DateTime.now(),
      );
      int distance(ChildActivity a) => age < a.minMonths
          ? a.minMonths - age
          : age > a.maxMonths
          ? age - a.maxMonths
          : 0;
      final cacheKey = (
        widget.childId,
        store.revision,
        age,
        activityCatalog.length,
      );
      List<ChildActivity> ranked;
      List<ChildActivity> suggestions;
      if (_catalogCacheKey == cacheKey &&
          _cachedRanked != null &&
          _cachedSuggestions != null) {
        ranked = _cachedRanked!;
        suggestions = _cachedSuggestions!;
      } else {
        ranked = [...activityCatalog]
          ..sort((a, b) {
            final diff = distance(a).compareTo(distance(b));
            return diff != 0
                ? diff
                : (done.contains(a.id) ? 1 : 0).compareTo(
                    done.contains(b.id) ? 1 : 0,
                  );
          });
        // Chỉ gợi ý trò có hướng dẫn đầy đủ (từ kho hoạt động hoặc soạn sẵn).
        suggestions =
            ranked
                .where(
                  (a) => a.remote || activityInstructions.containsKey(a.id),
                )
                .toList()
              ..sort((a, b) => distance(a).compareTo(distance(b)));
        _catalogCacheKey = cacheKey;
        _cachedRanked = ranked;
        _cachedSuggestions = suggestions;
      }
      final featured = suggestions.isEmpty
          ? (ranked.isNotEmpty ? ranked.first : null)
          : suggestions[_suggestion % suggestions.length];
      final picks = ranked
          .where((a) => _minutes == null || a.minutes == _minutes)
          .take(4)
          .toList();

      return Scaffold(
        backgroundColor: ActivitiesColors.background,
        appBar: AppBar(
          backgroundColor: ActivitiesColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cùng bé khám phá',
                style: _heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Hoạt động phù hợp cho $childName · $age tháng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _secondary.copyWith(fontSize: 12),
              ),
            ],
          ),
          actions: [
            IconButton.filledTonal(
              tooltip: 'Hoạt động yêu thích',
              style: IconButton.styleFrom(
                backgroundColor: ActivitiesColors.primarySoft,
                padding: const EdgeInsets.all(10),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ActivityListScreen(childId: widget.childId),
                ),
              ),
              icon: Badge(
                isLabelVisible: favorites.isNotEmpty,
                label: Text('${favorites.length}'),
                backgroundColor: ActivitiesColors.primary,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: ActivitiesColors.primary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            if (featured != null) ...[
              _Reveal(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ActivitiesColors.heroGradientStart,
                        ActivitiesColors.heroGradientEnd,
                      ],
                    ),
                    border: Border.all(
                      color: ActivitiesColors.border.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ActivitiesColors.primary.withValues(alpha: .08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ActivitiesColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: ActivitiesColors.primary,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'GỢI Ý HÔM NAY',
                                    style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: ActivitiesColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton.filledTonal(
                              tooltip: 'Đổi gợi ý',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.7),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                              onPressed: () => setState(() => _suggestion++),
                              icon: const Icon(
                                Icons.shuffle_rounded,
                                size: 18,
                                color: ActivitiesColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(.05, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Column(
                            key: ValueKey(featured.id),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Hero(
                                tag: 'activity-art-${featured.id}',
                                child: Center(
                                  child: _PlayArt(
                                    groupId: featured.groupId,
                                    large: true,
                                    imageUrl: featured.thumbnailUrl,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                featured.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: ActivitiesColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _MetaPill(
                                    icon: Icons.schedule_rounded,
                                    label: featured.durationLabel,
                                  ),
                                  _MetaPill(
                                    icon: Icons.child_care_rounded,
                                    label: featured.ageLabel,
                                  ),
                                  if (done.contains(featured.id))
                                    const _MetaPill(
                                      icon: Icons.check_circle_rounded,
                                      label: 'Đã chơi cùng bé',
                                      color: ActivitiesColors.primary,
                                      bgColor: ActivitiesColors.primarySoft,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: ActivitiesColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                              shadowColor: ActivitiesColors.primary.withValues(alpha: .3),
                            ),
                            onPressed: () => _open(featured),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text(
                              'Cùng bé chơi ngay',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // One-handed quick time filter row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thời lượng chơi',
                    style: _heading,
                  ),
                ),
                if (_minutes != null)
                  GestureDetector(
                    onTap: () => setState(() => _minutes = null),
                    child: const Text(
                      'Xem tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ActivitiesColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final minutes in [null, 5, 10, 15])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _minutes == minutes
                                ? ActivitiesColors.primary
                                : ActivitiesColors.border.withValues(alpha: 0.8),
                          ),
                        ),
                        avatar: Icon(
                          minutes == null
                              ? Icons.grid_view_rounded
                              : Icons.schedule_rounded,
                          size: 16,
                          color: _minutes == minutes
                              ? ActivitiesColors.primary
                              : ActivitiesColors.textSecondary,
                        ),
                        label: Text(
                          minutes == null ? 'Tất cả' : '$minutes phút',
                        ),
                        selected: _minutes == minutes,
                        selectedColor: ActivitiesColors.primarySoft,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _minutes == minutes
                              ? ActivitiesColors.primary
                              : ActivitiesColors.textPrimary,
                        ),
                        onSelected: (_) => setState(() => _minutes = minutes),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Picked activities
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thử cùng bé', style: _heading),
                      SizedBox(height: 2),
                      Text(
                        'Ý tưởng phù hợp theo độ tuổi của bé',
                        style: _secondary,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ActivityListScreen(childId: widget.childId),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tất cả'),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final a in picks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PressCard(
                  onTap: () => _open(a),
                  child: Row(
                    children: [
                      _PlayArt(groupId: a.groupId, imageUrl: a.thumbnailUrl),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: _title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: ActivitiesColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  a.durationLabel,
                                  style: _secondary,
                                ),
                                const SizedBox(width: 6),
                                const Text('·', style: _secondary),
                                const SizedBox(width: 6),
                                Text(
                                  a.ageLabel,
                                  style: _secondary,
                                ),
                              ],
                            ),
                            if (done.contains(a.id)) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: ActivitiesColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Đã chơi cùng bé',
                                    style: TextStyle(
                                      color: ActivitiesColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ActivitiesColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: ActivitiesColors.primary,
                          size: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),
            const Text('Khám phá theo nhóm', style: _heading),
            const SizedBox(height: 2),
            const Text(
              'Rèn luyện toàn diện các kỹ năng vận động & nhận thức',
              style: _secondary,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 360 &&
                        MediaQuery.textScalerOf(context).scale(16) < 25
                    ? 2
                    : 1;
                final spacing = 12.0;
                final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final group in activityGroups)
                      SizedBox(
                        width: width,
                        child: _GroupCard(
                          group: group,
                          childId: widget.childId,
                          tint: _groupTints[int.parse(group.id.substring(1))],
                          accent: _groupAccents[int.parse(group.id.substring(1))],
                        ),
                      ),
                  ],
                );
              },
            ),

            if (done.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Những trò bé đã thử', style: _heading),
              const SizedBox(height: 2),
              const Text(
                'Bé thích chơi lại những trò quen thuộc',
                style: _secondary,
              ),
              const SizedBox(height: 12),
              for (final a
                  in activityCatalog.where((a) => done.contains(a.id)).take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PressCard(
                    onTap: () => _open(a),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: ActivitiesColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: ActivitiesColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: _title),
                              const SizedBox(height: 2),
                              Text(
                                '${a.durationLabel} · ${a.ageLabel}',
                                style: _secondary,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.replay_rounded,
                          color: ActivitiesColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

/// Small meta tag pill
class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.color = ActivitiesColors.textSecondary,
    this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor ?? Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: ActivitiesColors.border.withValues(alpha: 0.6),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Group card with tactile feel
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.childId,
    required this.tint,
    required this.accent,
  });

  final ActivityGroup group;
  final String childId;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final count = activityCatalog.where((a) => a.groupId == group.id).length;
    return _PressCard(
      color: tint,
      borderColor: accent.withValues(alpha: 0.18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ActivityListScreen(
            childId: childId,
            group: group,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PlayArt(groupId: group.id),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            group.name,
            style: _title.copyWith(fontSize: 15),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$count ý tưởng chơi',
            style: _secondary.copyWith(color: accent, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Layered icon artwork uses the app's existing toy asset and native vector icons.
class _PlayArt extends StatelessWidget {
  const _PlayArt({required this.groupId, this.large = false, this.imageUrl});
  final String groupId;
  final bool large;

  /// Thumbnail from the backend; replaces the artwork when it loads.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final group = activityGroups.firstWhere((g) => g.id == groupId);
    final groupIndex = int.parse(groupId.substring(1));
    final tint = _groupTints[groupIndex];
    final accent = _groupAccents[groupIndex];
    final size = large ? 136.0 : 58.0;

    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(large ? 28 : 16),
        child: Image.network(
          ActivityApi.instance.imageUrl(imageUrl!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _PlayArt(groupId: groupId, large: large),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.08,
            child: Container(
              width: size * .86,
              height: size * .86,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(large ? 32 : 16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .12),
                    blurRadius: 12,
                    offset: const Offset(1, 4),
                  ),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: .05,
            child: Container(
              width: size * .82,
              height: size * .82,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(large ? 28 : 14),
                border: Border.all(
                  color: accent.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: groupId == 'g1'
                  ? Padding(
                      padding: EdgeInsets.all(size * .14),
                      child: Image.asset(
                        'assets/images/scenery/icons/care/activity_blocks.png',
                        fit: BoxFit.contain,
                      ),
                    )
                  : Icon(
                      group.icon,
                      size: size * .46,
                      color: accent,
                    ),
            ),
          ),
          Positioned(
            right: 0,
            top: large ? 6 : 0,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: const Color(0xFFE5A93C),
              size: large ? 24 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PressCard extends StatefulWidget {
  const _PressCard({
    required this.child,
    required this.onTap,
    this.color = Colors.white,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final Color? borderColor;

  @override
  State<_PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<_PressCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .98 : 1,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ActivitiesColors.primaryDark.withValues(
              alpha: _pressed ? .02 : .04,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: widget.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: widget.borderColor ?? ActivitiesColors.border.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 400),
    curve: Curves.easeOutCubic,
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}
