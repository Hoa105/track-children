import '../../services/demo_store.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';

class ChildProfileSelectionScreen extends StatefulWidget {
  const ChildProfileSelectionScreen({
    required this.onSelectChild,
    required this.onAddChild,
    super.key,
  });

  final ValueChanged<String> onSelectChild;
  final VoidCallback onAddChild;

  @override
  State<ChildProfileSelectionScreen> createState() => _SelectionState();
}

class _SelectionState extends State<ChildProfileSelectionScreen>
    with DemoStoreBinding {
  bool _selecting = false;

  Future<void> _select(Map<String, dynamic> child) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      await DemoStore.instance.selectChild(child['id'] as String);
      if (mounted) widget.onSelectChild(child['full_name'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: ChildProfileSelectionColors.background,
        colorScheme: base.colorScheme.copyWith(
          primary: ChildProfileSelectionColors.primary,
          onPrimary: ChildProfileSelectionColors.surface,
          secondary: ChildProfileSelectionColors.primary,
          onSecondary: ChildProfileSelectionColors.surface,
          surface: ChildProfileSelectionColors.surface,
          onSurface: ChildProfileSelectionColors.ink,
        ),
        textTheme: base.textTheme.apply(
          fontFamily: 'Nunito',
          bodyColor: ChildProfileSelectionColors.ink,
          displayColor: ChildProfileSelectionColors.ink,
        ),
        iconTheme: const IconThemeData(
          color: ChildProfileSelectionColors.primary,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: ChildProfileSelectionColors.primary,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: ChildProfileSelectionColors.primary,
          linearTrackColor: ChildProfileSelectionColors.pressed,
        ),
        splashColor: ChildProfileSelectionColors.pressed,
        highlightColor: ChildProfileSelectionColors.pressed,
      ),
      child: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: 'Quay lại',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Chọn hồ sơ bé',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chọn hồ sơ để tiếp tục theo dõi hành trình của bé.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: ChildProfileSelectionColors.secondary,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 24),
                        if (_selecting) const LinearProgressIndicator(),
                        if (!DemoStore.instance.signedIn)
                          _ChildProfileCard(
                            onTap: () => widget.onSelectChild('Bé An'),
                          ),
                        for (final child in DemoStore.instance.children)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChildProfileCard(
                              name: child['full_name'] as String,
                              age: DemoStore.instance.ageLabel(child),
                              onTap: () => _select(child),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: widget.onAddChild,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Thêm hồ sơ bé'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor:
                                  ChildProfileSelectionColors.primary,
                              foregroundColor:
                                  ChildProfileSelectionColors.surface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
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
      ),
    );
  }
}

class _ChildProfileCard extends StatelessWidget {
  const _ChildProfileCard({
    required this.onTap,
    this.name = 'Bé An',
    this.age = '24 tháng',
  });
  final String name, age;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ChildProfileSelectionColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: ChildProfileSelectionColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ChildProfileSelectionColors.avatar,
              ),
              child: const Icon(
                Icons.child_care_rounded,
                color: ChildProfileSelectionColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: ChildProfileSelectionColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    age,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ChildProfileSelectionColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ChildProfileSelectionColors.primary,
            ),
          ],
        ),
      ),
    ),
  );
}
