import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/growth_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });
  for (final failFirst in [false, true]) {
    testWidgets('remote view permission and empty data, retry=$failFirst', (
      tester,
    ) async {
      var fail = false;
      final child = {
        'id': 'server-child',
        'fullName': 'Remote child',
        'dateOfBirth': '2026-02-17',
        'gender': 'female',
        'growthAccess': 'view',
      };
      GrowthApi.instance = GrowthApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'accessToken': 'access',
                'refreshToken': 'raw',
                'user': {'id': 'owner', 'fullName': 'Parent'},
              }),
              200,
            );
          }
          if (r.url.path.endsWith('/children')) {
            return http.Response(
              jsonEncode({
                'children': [child],
              }),
              200,
            );
          }
          if (fail) {
            return http.Response(
              '{"error":{"code":"DATABASE_UNAVAILABLE"}}',
              503,
            );
          }
          return http.Response(jsonEncode({'child': child, 'days': []}), 200);
        }),
      );
      final store = DemoStore.instance;
      await store.login('remote@example.test', 'secret', useServer: true);
      await store.selectChild('server-child');
      fail = failFirst;
      await tester.pumpWidget(
        const MaterialApp(home: GrowthScreen(childName: 'Remote child')),
      );
      await tester.pumpAndSettle();
      if (failFirst) {
        expect(find.text('Thử lại'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Dữ liệu mẫu'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Số đo'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      GrowthApi.instance.clear();
    });
  }
}
