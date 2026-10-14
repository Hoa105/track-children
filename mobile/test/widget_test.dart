import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/main.dart';

void main() {
  testWidgets('first launch can skip onboarding and open welcome', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pumpAndSettle();

    expect(find.text('Chăm sóc bé dễ dàng hơn'), findsOneWidget);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();

    expect(find.text('Cùng con lớn lên\nmỗi ngày'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsOneWidget);
  });

  testWidgets('completed onboarding stays complete after app restart', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();

    expect(find.text('Cùng con lớn lên\nmỗi ngày'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pumpAndSettle();

    expect(find.text('Cùng con lớn lên\nmỗi ngày'), findsOneWidget);
    expect(find.text('Chăm sóc bé dễ dàng hơn'), findsNothing);
  });

  testWidgets(
    'welcome opens login and login validates without authenticating',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'track_children_onboarding_completed': true,
      });

      await tester.pumpWidget(const TrackChildrenApp());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đăng nhập'));
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Chào mừng bạn trở lại'), findsOneWidget);
      expect(find.text('Email hoặc số điện thoại'), findsOneWidget);

      await tester.ensureVisible(find.text('Đăng nhập'));
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng nhập email hoặc số điện thoại.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'parent@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'sample-password',
      );
      await tester.ensureVisible(find.text('Đăng nhập'));
      await tester.tap(find.text('Đăng nhập'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(
        find.text('Đăng nhập chưa được kết nối trong bản xem trước giao diện.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'sign up keeps choices blank and hides parent question for caregiver',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'track_children_onboarding_completed': true,
      });

      await tester.pumpWidget(const TrackChildrenApp());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tạo tài khoản'));
      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn là người đồng hành nào?'), findsOneWidget);
      expect(find.text('Đây có phải lần đầu bạn có con?'), findsNothing);
      expect(find.text('Vui lòng chọn mối quan hệ.'), findsNothing);

      await tester.tap(find.text('Mẹ'));
      await tester.pumpAndSettle();
      expect(find.text('Đây có phải lần đầu bạn có con?'), findsOneWidget);
      expect(find.text('Vui lòng chọn Có hoặc Không.'), findsNothing);

      await tester.tap(find.text('Bảo mẫu'));
      await tester.pumpAndSettle();
      expect(find.text('Đây có phải lần đầu bạn có con?'), findsNothing);
    },
  );

  testWidgets('valid sign up preview opens child profile form', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'track_children_onboarding_completed': true,
    });

    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pumpAndSettle();
    final welcomeSignUpButton = find.widgetWithText(
      OutlinedButton,
      'Tạo tài khoản',
    );
    await tester.ensureVisible(welcomeSignUpButton);
    await tester.tap(welcomeSignUpButton);
    await tester.pumpAndSettle();

    final createAccountButton = find.widgetWithText(
      FilledButton,
      'Tạo tài khoản',
    );
    await tester.tap(find.text('Bảo mẫu'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Người chăm bé');
    await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'preview-password',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Xem giao diện hồ sơ bé'));
    await tester.tap(find.text('Xem giao diện hồ sơ bé'));
    await tester.pumpAndSettle();

    expect(find.text('Thêm hồ sơ bé mới'), findsOneWidget);
    expect(find.text('Tên bé'), findsOneWidget);
    expect(find.text('Ngày sinh'), findsOneWidget);
    expect(find.text('Giới tính'), findsOneWidget);
  });

  testWidgets('home presents preview data and shortcuts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'An')),
    );

    expect(find.text('An'), findsOneWidget);
    expect(find.text('Lượng sữa'), findsOneWidget);
    expect(find.text('Tiêm chủng'), findsOneWidget);
    expect(find.text('Mọc răng'), findsOneWidget);
    expect(find.text('Hoạt động'), findsOneWidget);
    expect(find.text('Nhật ký'), findsNWidgets(2));
    expect(find.text('Dữ liệu xem trước'), findsOneWidget);
    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Cân nặng'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('Cân nặng'), findsOneWidget);
    expect(find.text('Chiều cao'), findsOneWidget);
    expect(find.text('8,1 kg', findRichText: true), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Búp măng khép kín'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('Búp măng khép kín'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cữ sữa buổi sáng'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('Cữ sữa buổi sáng'), findsOneWidget);
    expect(find.text('Cùng bé nghe nhạc'), findsOneWidget);
    expect(find.text('15 kg'), findsNothing);
  });
}
