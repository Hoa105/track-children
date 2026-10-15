import 'vaccination_style.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';

class VaccinationContent extends StatelessWidget {
  const VaccinationContent({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
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
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.pagePadding),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (i, text) in ['Theo tuổi', 'Vắc-xin', 'Đã tiêm'].indexed)
            Expanded(
              child: Material(
                color: index == i ? AppColors.primary : Colors.transparent,
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
                        vertical: 12,
                      ),
                      child: Center(
                        child: Semantics(
                          selected: index == i,
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: index == i
                                      ? Colors.white
                                      : AppColors.primaryDark,
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
            color: AppColors.textPrimary,
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
        const Divider(height: 1, color: AppColors.border),
        ...children,
      ],
    ),
  );
}
