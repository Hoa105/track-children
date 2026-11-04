import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'teething_reference_data.dart';
import 'tooth_chart.dart';

class TeethingReferenceTab extends StatelessWidget {
  const TeethingReferenceTab({super.key, required this.initialAgeMonths});
  final int initialAgeMonths;

  @override
  Widget build(BuildContext context) {
    final month = TeethingReferenceData.clampMonth(initialAgeMonths);
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > 650 ? (width - 600) / 2 : 16.0;
    final count = TeethingReferenceData.possibleTeethCountAt(month);
    return ListView(
      key: const PageStorageKey('teething-reference-tab'),
      padding: EdgeInsets.fromLTRB(inset, 16, inset, 24),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'Bé có thể mọc được $count răng sữa',
            key: const Key('reference-summary'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bé có thể mọc muộn hơn hoặc chưa mọc đủ các răng được tô màu.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ToothChart(
          eruptedIds: const {},
          referenceIds: TeethingReferenceData.toothIdsAt(month),
          ageMonths: month,
          onToothTap: null,
          showPairNumbers: true,
        ),
      ],
    );
  }
}
