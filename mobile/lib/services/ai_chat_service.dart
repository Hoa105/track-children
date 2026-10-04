import '../models/chat_message.dart';

/// Minimal stub for a future "Góc đồng hành" AI companion chat feature.
/// Not part of the prototype's screens, but requested as forward-looking
/// scaffolding — kept intentionally small (canned replies only).
abstract class AIChatService {
  Future<ChatMessage> sendMessage(String text);
}

class MockAIChatService implements AIChatService {
  static const _replies = [
    'Mẹ có thể quan sát bé trong 1 tuần rồi thử lại hoạt động gợi ý nhé.',
    'Đây là gợi ý tham khảo, mẹ nên trao đổi thêm với bác sĩ nếu còn lo lắng.',
    'Bé ở độ tuổi này thường tiến bộ khác nhau, mẹ đừng quá lo nhé!',
  ];
  int _i = 0;

  @override
  Future<ChatMessage> sendMessage(String text) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final reply = _replies[_i % _replies.length];
    _i++;
    return ChatMessage(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      text: reply,
      isFromUser: false,
      timestamp: DateTime.now(),
    );
  }
}
