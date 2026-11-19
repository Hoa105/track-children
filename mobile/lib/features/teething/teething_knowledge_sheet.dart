import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'teething_knowledge_data.dart';

class TeethingKnowledgeSheet extends StatelessWidget {
  const TeethingKnowledgeSheet({required this.ageMonths, super.key});
  final int ageMonths;

  @override
  Widget build(BuildContext context) {
    final careRules = TeethingKnowledgeData.careForAge(ageMonths);
    final safetyRules = TeethingKnowledgeData.safetyForAge(ageMonths);
    final entries = <Object>[
      'Thông tin chung',
      ...TeethingKnowledgeData.generalRules,
      TeethingKnowledgeData.careTitle,
      ...careRules,
      TeethingKnowledgeData.safetyTitle,
      ...safetyRules,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kiến thức mọc răng',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: TeethingColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dành cho bé ${ageMonths.clamp(0, 60)} tháng',
                        style: const TextStyle(
                          fontSize: 14,
                          color: TeethingColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              key: const PageStorageKey('teething-knowledge-list'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                if (entry is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Text(
                      entry,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: TeethingColors.primaryDark,
                      ),
                    ),
                  );
                }
                final rule = entry as TeethingKnowledgeRule;
                return Card(
                  elevation: 0,
                  color: TeethingColors.surface,
                  child: ExpansionTile(
                    key: PageStorageKey('knowledge-${rule.id}'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      rule.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: TeethingColors.textPrimary,
                      ),
                    ),
                    subtitle: rule.ageLabel == null
                        ? null
                        : Text(
                            rule.ageLabel!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: TeethingColors.textSecondary,
                            ),
                          ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    children: [
                      Text(
                        rule.text,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: TeethingColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
