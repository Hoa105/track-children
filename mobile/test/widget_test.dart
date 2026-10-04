// Basic smoke test: the app boots and renders the splash screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:track_children/main.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BeLonKhonApp());
    await tester.pumpAndSettle();

    expect(find.text('Bé Lớn Khôn'), findsWidgets);
    expect(find.text('Bắt đầu hành trình'), findsOneWidget);
  });
}
