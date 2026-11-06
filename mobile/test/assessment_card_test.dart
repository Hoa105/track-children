import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/assessment/assessment_widgets.dart';

void main() {
  testWidgets(
    'reduced motion keeps progress readable and answers interactive',
    (tester) async {
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: AssessmentScaffold(
              body: StatefulBuilder(
                builder: (context, update) => Column(
                  children: [
                    const AssessmentProgress(value: .5),
                    AssessmentReveal(
                      child: AssessmentChoice(
                        label: 'Đã làm được',
                        selected: selected,
                        onTap: () => update(() => selected = true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
      await tester.tap(find.text('Đã làm được'));
      await tester.pumpAndSettle();
      expect(tester.widget<AssessmentChoice>(find.byType(AssessmentChoice)).selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  for (final featured in [false, true]) {
    testWidgets(
      'assessment cards ($featured) support list tiles and expanded source links',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AssessmentCard(
                featured: featured,
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: false,
                      onChanged: (_) {},
                      title: const Text('Xác nhận'),
                    ),
                    ExpansionTile(
                      title: const Text('Nguồn tham khảo'),
                      children: [
                        ListTile(
                          title: const Text('CDC'),
                          onTap: () => tapped = true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Nguồn tham khảo'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('CDC'));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
