import 'package:flutter/material.dart';

import 'teething_age_selector.dart';
import 'teething_reference_data.dart';

/// Reuses the compact scrolling controls without changing the actual month tab.
class TeethingStageSelector extends StatelessWidget {
  const TeethingStageSelector({
    required this.month,
    required this.onChanged,
    super.key,
  });

  final int month;
  final ValueChanged<int> onChanged;
  static final _choices = [
    for (final stage in TeethingReferenceData.stages)
      TeethingAgeChoice(
        month: stage.startMonth,
        label: stage.label,
        id: 'reference-stage-${stage.id}',
      ),
  ];

  @override
  Widget build(BuildContext context) => TeethingAgeSelector(
    month: TeethingReferenceData.stageForMonth(month).startMonth,
    currentMonth: month,
    maxMonth: 60,
    choices: _choices,
    onChanged: onChanged,
  );
}
