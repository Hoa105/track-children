import 'vaccination_style.dart';

import 'package:flutter/material.dart';

import '../../app_layout.dart';

class VaccinationContent extends StatelessWidget {
  const VaccinationContent({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: VaccinationColors.surface,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class VaccinationTabs extends StatelessWidget {
  const VaccinationTabs({
    super.key,
    required this.index,
    required this.onChanged,
  });
  final int index;
  final ValueChanged<int> onChanged;

  static const _tabs = [
    'Theo tuổi',
    'Vắc-xin',
    'Đã tiêm',
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.pagePadding),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VaccinationColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VaccinationColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          for (final (i, text) in _tabs.indexed)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: index == i ? VaccinationColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: index == i
                      ? [
                          BoxShadow(
                            color: VaccinationColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppLayout.minimumTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        child: Center(
                          child: Semantics(
                            selected: index == i,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: index == i
                                          ? Colors.white
                                          : VaccinationColors.primaryDark,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class VaccinationSection extends StatelessWidget {
  const VaccinationSection({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    required this.children,
  });
  final String label, title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppLayout.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: VaccinationColors.secondary),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: VaccinationColors.textPrimary,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: VaccinationColors.secondary),
            ),
          ),
        const SizedBox(height: AppLayout.mediumGap),
        const Divider(height: 1, color: VaccinationColors.border),
        ...children,
      ],
    ),
  );
}
