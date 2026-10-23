part of 'activities_screen.dart';

const _groupTints = [
  Color(0xFFE3EED8),
  Color(0xFFFFE8CF),
  Color(0xFFE1EBFF),
  Color(0xFFF2E3EF),
  Color(0xFFECE3FA),
  Color(0xFFFFEDD5),
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
  void _open(ChildActivity a) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          ActivityDetailScreen(childId: widget.childId, activity: a),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final store = DemoStore.instance;
      final child = store.childById(widget.childId);
      final reduced = MediaQuery.disableAnimationsOf(context);
      if (child == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Hoạt động')),
          body: const Center(child: Text('Chọn hồ sơ bé để xem hoạt động.')),
        );
      }
      final done = store.completedActivities(widget.childId);
      final age = WhoBmiReference.ageMonths(
        DateTime.parse(child['date_of_birth'] as String),
        DateTime.now(),
      );
      int distance(ChildActivity a) => age < a.minMonths
          ? a.minMonths - age
          : age > a.maxMonths
          ? age - a.maxMonths
          : 0;
      final ranked = [...activityCatalog]
        ..sort((a, b) {
          final diff = distance(a).compareTo(distance(b));
          return diff != 0
              ? diff
              : (done.contains(a.id) ? 1 : 0).compareTo(
                  done.contains(b.id) ? 1 : 0,
                );
        });
      final suggestions =
          ranked.where((a) => activityInstructions.containsKey(a.id)).toList()
            ..sort((a, b) => distance(a).compareTo(distance(b)));
      final featured = suggestions[_suggestion % suggestions.length];
      final picks = ranked
          .where((a) => _minutes == null || a.minutes == _minutes)
          .take(4)
          .toList();
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Hoạt động', style: _heading),
          actions: [
            IconButton.filledTonal(
              tooltip: 'Hoạt động yêu thích',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ActivityListScreen(childId: widget.childId),
                ),
              ),
              icon: const Icon(
                Icons.favorite_border_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Reveal(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE1EDD6), Color(0xFFF1E9D4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .09),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'HÔM NAY CHƠI GÌ?',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đổi gợi ý',
                            onPressed: () => setState(() => _suggestion++),
                            icon: const Icon(
                              Icons.shuffle_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(.06, 0),
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
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              featured.name,
                              style: const TextStyle(
                                fontSize: 28,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${featured.minutes} phút · ${featured.ageLabel}',
                              style: _secondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => _open(featured),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Cùng bé chơi',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Một chút thời gian, nhiều niềm vui', style: _heading),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in [null, 5, 10, 15])
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      minutes == null
                          ? Icons.apps_rounded
                          : Icons.timer_outlined,
                      size: 18,
                      color: _minutes == minutes
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    label: Text(minutes == null ? 'Tất cả' : '$minutes phút'),
                    selected: _minutes == minutes,
                    selectedColor: AppColors.primarySoft,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _minutes == minutes
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    onSelected: (_) => setState(() => _minutes = minutes),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Thử cùng bé', style: _heading),
            const SizedBox(height: 4),
            const Text(
              'Những ý tưởng nhỏ cho khoảnh khắc bên nhau.',
              style: _secondary,
            ),
            const SizedBox(height: 16),
            for (final a in picks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PressCard(
                  onTap: () => _open(a),
                  child: Row(
                    children: [
                      _PlayArt(groupId: a.groupId),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, style: _title),
                            const SizedBox(height: 6),
                            Text(
                              '${a.minutes} phút · ${a.ageLabel}',
                              style: _secondary,
                            ),
                            if (done.contains(a.id))
                              const Text(
                                'Đã chơi cùng bé',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_outward_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text('Khám phá thêm', style: _heading),
            const SizedBox(height: 4),
            const Text('Mỗi cách chơi, một điều mới mẻ.', style: _secondary),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 360 &&
                        MediaQuery.textScalerOf(context).scale(16) < 25
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final group in activityGroups)
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns,
                        child: _PressCard(
                          color: _groupTints[int.parse(group.id.substring(1))],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ActivityListScreen(
                                childId: widget.childId,
                                group: group,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PlayArt(groupId: group.id),
                              const SizedBox(height: 16),
                              Text(group.name, style: _title),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${activityCatalog.where((a) => a.groupId == group.id).length} ý tưởng chơi',
                                      style: _secondary,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text('Những trò bé đã thử', style: _heading),
              const SizedBox(height: 8),
              const Text(
                'Bé có thể chơi lại những trò quen thuộc bất cứ lúc nào.',
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
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(a.name, style: _title)),
                        const Icon(
                          Icons.replay_rounded,
                          color: AppColors.primary,
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

/// Layered icon artwork uses the app's existing toy asset and native vector icons.
class _PlayArt extends StatelessWidget {
  const _PlayArt({required this.groupId, this.large = false});
  final String groupId;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final group = activityGroups.firstWhere((g) => g.id == groupId);
    final tint = _groupTints[int.parse(groupId.substring(1))];
    final size = large ? 156.0 : 64.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.13,
            child: Container(
              width: size * .83,
              height: size * .83,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(large ? 40 : 20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: .08),
                    blurRadius: 16,
                    offset: const Offset(2, 8),
                  ),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: .08,
            child: Container(
              width: size * .8,
              height: size * .8,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(large ? 36 : 18),
              ),
              child: groupId == 'g1'
                  ? Image.asset(
                      'assets/images/scenery/icons/care/activity_blocks.png',
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      group.icon,
                      size: size * .49,
                      color: AppColors.primaryDark,
                      shadows: const [
                        Shadow(
                          color: Colors.white,
                          offset: Offset(0, 2),
                          blurRadius: 1,
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            right: 0,
            top: large ? 8 : 0,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: const Color(0xFFCE9E4F),
              size: large ? 28 : 15,
            ),
          ),
          if (large)
            const Positioned(
              left: 0,
              bottom: 12,
              child: Icon(Icons.circle, size: 14, color: AppColors.purpleText),
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
  });
  final Widget child;
  final VoidCallback onTap;
  final Color color;
  @override
  State<_PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<_PressCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .975 : 1,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(
              alpha: _pressed ? .02 : .045,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: widget.color,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Padding(
            padding: const EdgeInsets.all(18),
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
        : const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}
