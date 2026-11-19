import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'teething_reference_data.dart';
import 'tooth_chart.dart';

class TeethingReferenceTab extends StatefulWidget {
  const TeethingReferenceTab({
    super.key,
    required this.initialAgeMonths,
    this.onMonthSelected,
  });
  final int initialAgeMonths;
  final ValueChanged<int>? onMonthSelected;

  @override
  State<TeethingReferenceTab> createState() => _TeethingReferenceTabState();
}

class _TeethingReferenceTabState extends State<TeethingReferenceTab> {
  String? _selectedToothId;

  @override
  Widget build(BuildContext context) {
    final stage = TeethingReferenceData.stageForMonth(widget.initialAgeMonths);
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > 650 ? (width - 600) / 2 : 16.0;
    return ListView(
      key: const PageStorageKey('teething-reference-tab'),
      padding: EdgeInsets.fromLTRB(inset, 16, inset, 24),
      children: [
        Semantics(
          liveRegion: true,
          child: stage.count == 0
              ? Text(
                  stage.noteTitle!,
                  key: const Key('reference-zero-title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: TeethingColors.primaryDark,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      // Keep one line without shrinking accessibility text.
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: '${TeethingReferenceData.countLabel} ',
                            ),
                            TextSpan(
                              text:
                                  '${stage.count} ${TeethingReferenceData.countUnit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        key: const Key('reference-summary'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                          color: TeethingColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          stage.note,
          key: const Key('reference-stage-note'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            color: TeethingColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ToothChart(
          eruptedIds: const {},
          referenceIds: TeethingReferenceData.toothIdsAt(stage.startMonth),
          selectedReferenceId: _selectedToothId,
          ageMonths: stage.startMonth,
          onToothTap: widget.onMonthSelected == null
              ? null
              : (tooth) {
                  setState(() => _selectedToothId = tooth.id);
                  widget.onMonthSelected!(
                    TeethingReferenceData.firstStageForTooth(tooth).startMonth,
                  );
                },
          showPairNumbers: true,
        ),
      ],
    );
  }
}
