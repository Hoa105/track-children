import 'package:flutter/material.dart';
import '../../models/assessment_domain.dart';
import '../theme/app_text_styles.dart';
import 'progress_bar.dart';

/// A single "domain name — status · x/y" row with a colored progress bar,
/// used on Home, Results and History screens.
class DomainProgressRow extends StatelessWidget {
  const DomainProgressRow({
    super.key,
    required this.domain,
    required this.achieved,
    required this.total,
    this.statusLabel,
  });

  final AssessmentDomain domain;
  final int achieved;
  final int total;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : achieved / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(domain.icon, size: 16, color: domain.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(domain.label, style: AppTextStyles.body),
              ),
              Text(
                statusLabel != null ? '$statusLabel · $achieved/$total' : '$achieved/$total',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppProgressBar(value: ratio, color: domain.color),
        ],
      ),
    );
  }
}
