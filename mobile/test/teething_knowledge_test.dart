import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/teething/teething_knowledge_data.dart';
import 'package:track_children/features/teething/teething_knowledge_sheet.dart';

void main() {
  test('all care/safety entries match the approved JSON verbatim', () {
    final source = jsonDecode(
      File('../docs/update-teeth/01_DU_LIEU_2_TAB.json').readAsStringSync(),
    ) as Map;
    final actual = source['actual_tab'] as Map;
    expect(TeethingKnowledgeData.careTitle, actual['ui_copy']['care_title_vi']);
    expect(
      TeethingKnowledgeData.safetyTitle,
      actual['ui_copy']['safety_title_vi'],
    );
    for (final group in [
      ('care_rules', TeethingKnowledgeData.careRules, 12),
      ('safety_rules', TeethingKnowledgeData.safetyRules, 8),
    ]) {
      final rules = actual[group.$1] as List;
      expect(group.$2, hasLength(group.$3));
      for (var index = 0; index < rules.length; index++) {
        final rule = group.$2[index];
        expect(rule.id, rules[index]['id']);
        expect(rule.title, rules[index]['title_vi']);
        expect(rule.text, rules[index]['text_vi']);
        expect(rule.minMonth, rules[index]['min_month']);
        expect(rule.maxMonth, rules[index]['max_month']);
        expect(rule.knowledgeGroup, rules[index]['knowledge_group']);
        expect(rule.displayMode, rules[index]['display_mode']);
        expect(rule.priority, rules[index]['priority']);
      }
    }
  });

  test('care and safety change at the child age boundaries', () {
    Set<String> care(int month) =>
        TeethingKnowledgeData.careForAge(month).map((r) => r.id).toSet();
    Set<String> safety(int month) =>
        TeethingKnowledgeData.safetyForAge(month).map((r) => r.id).toSet();
    expect(care(2), contains('CARE_GUM'));
    expect(care(6), isNot(contains('CARE_GUM')));
    expect(care(11), contains('CARE_FIRST_VISIT'));
    expect(care(11), isNot(contains('CARE_VISIT_12')));
    expect(care(12), contains('CARE_VISIT_12'));
    expect(care(12), isNot(contains('CARE_FIRST_VISIT')));
    expect(care(23), contains('CARE_UNDER2_ASK'));
    expect(care(24), isNot(contains('CARE_UNDER2_ASK')));
    expect(care(35), contains('CARE_RICE'));
    expect(care(36), isNot(contains('CARE_RICE')));
    expect(safety(2), contains('SAFE_FEVER_YOUNG'));
    expect(safety(2), isNot(contains('SAFE_FEVER_OLDER')));
    expect(safety(3), contains('SAFE_FEVER_OLDER'));
    expect(safety(3), isNot(contains('SAFE_FEVER_YOUNG')));
    for (var month = 0; month <= 60; month++) {
      for (final rule in [
        ...TeethingKnowledgeData.careForAge(month),
        ...TeethingKnowledgeData.safetyForAge(month),
      ]) {
        expect(month, inInclusiveRange(rule.minMonth, rule.maxMonth));
      }
    }
  });

  test(
    'ages 36–60 show only the complete toothpaste guide for the shared topic',
    () {
      const duplicates = {'CARE_BRUSH_3Y', 'CARE_PASTE_3Y', 'CARE_HELP_BRUSH'};
      for (var month = 36; month <= 60; month++) {
        final visible = TeethingKnowledgeData.careForAge(month)
            .map((r) => r.id)
            .toSet();
        expect(visible.intersection(duplicates), {'CARE_PASTE_3Y'});
      }
    },
  );

  for (final age in [2, 36]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'age $age knowledge entries open on a narrow screen at scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 800);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(body: TeethingKnowledgeSheet(ageMonths: age)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final scrollable = find.descendant(
            of: find.byKey(const PageStorageKey('teething-knowledge-list')),
            matching: find.byType(Scrollable),
          );
          for (final rule in [
            ...TeethingKnowledgeData.generalRules,
            ...TeethingKnowledgeData.careForAge(age),
            ...TeethingKnowledgeData.safetyForAge(age),
          ]) {
            final tile = find.byKey(PageStorageKey('knowledge-${rule.id}'));
            await tester.scrollUntilVisible(tile, 200, scrollable: scrollable);
            await tester.ensureVisible(tile);
            await tester.pumpAndSettle();
            await tester.tap(find.text(rule.title));
            await tester.pumpAndSettle();
            expect(find.text(rule.text), findsOneWidget);
            if (rule.ageLabel != null) {
              expect(find.text(rule.ageLabel!), findsWidgets);
            }
            expect(find.text(rule.id), findsNothing);
            final expansion = tester.widget<ExpansionTile>(tile);
            expect(expansion.shape, const Border());
            expect(expansion.collapsedShape, const Border());
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.text(rule.title));
            await tester.pumpAndSettle();
            await tester.tap(find.text(rule.title));
            await tester.pumpAndSettle();
          }
          expect(find.text('Nguồn tham khảo'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
