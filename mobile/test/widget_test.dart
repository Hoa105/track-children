import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/features/splash/start_screen.dart';
import 'package:track_children/main.dart';
import 'package:track_children/services/demo_store.dart';

Future<void> openIntroduction(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const TrackChildrenApp());
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/scenery/backgrounds/start_screen.png'),
      tester.element(find.byType(StartScreen)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });
  testWidgets('startup introduction completes into login', (tester) async {
    await openIntroduction(tester);
    expect(find.text('Chăm sóc bé dễ dàng hơn'), findsOneWidget);
    await tester.ensureVisible(find.text('Tiếp tục'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Đồng hành cùng bé mỗi ngày'), findsOneWidget);
    await tester.ensureVisible(find.text('Bắt đầu'));
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng bạn trở lại'), findsOneWidget);
  });
  testWidgets(
    'completion persists while introduction remains visible on restart',
    (tester) async {
      await openIntroduction(tester);
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu'));
      await tester.tap(find.text('Bắt đầu'));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'track_children_onboarding_completed',
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox());
      await openIntroduction(tester);
      expect(find.text('Chăm sóc bé dễ dàng hơn'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('login validates and authenticates shared parent fixture', (
    tester,
  ) async {
    var loggedIn = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onSignUp: () {},
          onBack: () {},
          onLoginSuccess: () => loggedIn = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'demo@trackchildren.vn',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(loggedIn, false);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      DemoStore.password,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(loggedIn, true);
    expect(DemoStore.instance.parent['email'], 'demo@trackchildren.vn');
  });
  testWidgets('signup role selection uses current parent roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(onLogin: () {}, onChildProfilePreview: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Người giám hộ khác'));
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mẹ')).selected,
      true,
    );
    await tester.tap(find.text('Người giám hộ khác'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Người giám hộ khác'),
          )
          .selected,
      true,
    );
    expect(find.text('Đây có phải lần đầu bạn có con?'), findsNothing);
  });
  testWidgets('signup OTP creates local account and requests child form', (
    tester,
  ) async {
    var openChild = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(
          onLogin: () {},
          onChildProfilePreview: () => openChild = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final values = [
      'Phụ huynh thử',
      'parent_test',
      'new.parent@example.test',
      '0900000003',
      'Testing123',
      'Testing123',
    ];
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    }
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Xác thực OTP'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '123456',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();
    expect(openChild, true);
    expect(DemoStore.instance.parent['email'], 'new.parent@example.test');
    expect(DemoStore.instance.children, isEmpty);
  });
  testWidgets('standalone Home presents its preview and shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'An')),
    );
    await tester.pumpAndSettle();
    expect(find.text('An'), findsOneWidget);
    for (final label in [
      'Lượng sữa',
      'Tiêm chủng',
      'Mọc răng',
      'Hoạt động',
      'Nhật ký',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.scrollUntilVisible(
      find.text('Cân nặng'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chưa có số đo'), findsWidgets);
    expect(find.text('12,5 kg'), findsNothing);
    expect(find.text('85 cm'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Chưa có nhật ký'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chưa có nhật ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
