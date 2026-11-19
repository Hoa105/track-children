import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/auth/otp_status.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18);
  Map<String, dynamic> ticket(DateTime at) => {
    'expiresAt': at.add(const Duration(minutes: 5)).toIso8601String(),
    'resendAvailableAt': at.add(const Duration(seconds: 60)).toIso8601String(),
  };
  test('cooldown and exact expiry boundaries come from server deadlines', () {
    final data = ticket(now);
    expect(OtpTiming(data, now: now).resendIn, 60);
    expect(
      OtpTiming(data, now: now.add(const Duration(seconds: 60))).resendIn,
      0,
    );
    expect(
      OtpTiming(
        data,
        now: now.add(const Duration(seconds: 299)),
      ).canVerify('012345'),
      true,
    );
    expect(
      OtpTiming(
        data,
        now: now.add(const Duration(seconds: 300)),
      ).canVerify('012345'),
      false,
    );
    expect(OtpTiming(data, now: now).canVerify('12345'), false);
    expect(OtpTiming(null, now: now).canVerify('012345'), false);
  });
  testWidgets('cooldown shows one countdown without an expiry countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpStatus(
            ticket: ticket(DateTime.now()),
            busy: false,
            onResend: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Gửi lại sau'), findsOneWidget);
    expect(find.textContaining('Mã hết hạn sau'), findsNothing);
    expect(find.textContaining('Mã có hiệu lực'), findsNothing);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });
  testWidgets('resend becomes available before code expiry', (tester) async {
    var calls = 0;
    final data = ticket(DateTime.now().subtract(const Duration(seconds: 61)));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpStatus(ticket: data, busy: false, onResend: () => calls++),
        ),
      ),
    );
    expect(find.textContaining('Gửi lại sau'), findsNothing);
    expect(find.textContaining('Mã có hiệu lực'), findsOneWidget);
    await tester.tap(find.text('Gửi lại mã'));
    expect(calls, 1);
  });
  testWidgets('expired code offers a new code and no remaining-time counter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpStatus(
            ticket: ticket(DateTime.now().subtract(const Duration(minutes: 6))),
            busy: false,
            onResend: () {},
          ),
        ),
      ),
    );
    expect(
      find.text('Mã đã hết hạn. Vui lòng yêu cầu mã mới.'),
      findsOneWidget,
    );
    expect(find.text('Gửi mã mới'), findsOneWidget);
    expect(find.textContaining('Gửi lại sau'), findsNothing);
  });
}
