import 'package:flutter/material.dart';

/// Deadlines are supplied by the server; expiry and resend cooldown are distinct.
class OtpTiming {
  OtpTiming(Map<String, dynamic>? ticket, {DateTime? now})
    : expiresIn = _left(ticket, 'expiresAt', now ?? DateTime.now()),
      resendIn = _left(ticket, 'resendAvailableAt', now ?? DateTime.now());
  final int expiresIn, resendIn;
  bool get expired => expiresIn == 0;
  bool canVerify(String code) =>
      !expired && RegExp(r'^[0-9]{6}$').hasMatch(code);
  static int _left(Map<String, dynamic>? ticket, String key, DateTime now) {
    final date = DateTime.tryParse(ticket?[key]?.toString() ?? '');
    return date == null
        ? 0
        : (date.difference(now).inMilliseconds / 1000).ceil().clamp(0, 3600);
  }
}

class OtpStatus extends StatelessWidget {
  const OtpStatus({
    super.key,
    required this.ticket,
    required this.busy,
    required this.onResend,
  });
  final Map<String, dynamic>? ticket;
  final bool busy;
  final VoidCallback onResend;
  @override
  Widget build(BuildContext context) {
    final timing = OtpTiming(ticket);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timing.expired)
          const Text('Mã đã hết hạn. Vui lòng yêu cầu mã mới.')
        else if (timing.resendIn == 0)
          const Text('Mã có hiệu lực trong 5 phút kể từ lần gửi gần nhất.'),
        TextButton(
          onPressed: busy || timing.resendIn > 0 ? null : onResend,
          child: Text(
            timing.resendIn > 0
                ? 'Gửi lại sau ${timing.resendIn} giây'
                : timing.expired
                ? 'Gửi mã mới'
                : 'Gửi lại mã',
          ),
        ),
      ],
    );
  }
}
