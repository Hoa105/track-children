import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/chat_message.dart';
import '../../../services/service_locator.dart';

/// Minimal chat stub for a future AI companion feature. Not part of the
/// prototype's screens — kept intentionally small per the task's scaffolding
/// request rather than building a full chat UI.
class ChatStubScreen extends StatefulWidget {
  const ChatStubScreen({super.key});

  @override
  State<ChatStubScreen> createState() => _ChatStubScreenState();
}

class _ChatStubScreenState extends State<ChatStubScreen> {
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        id: 'u${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        isFromUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
      _sending = true;
    });
    final reply = await ServiceLocator.aiChatService.sendMessage(text);
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hỏi Mentor AI')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text('Đặt câu hỏi về sự phát triển của bé cho Mentor AI.',
                          textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        return Align(
                          alignment: m.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: m.isFromUser ? AppColors.primary : AppColors.surfaceGreenLighter,
                              borderRadius: AppRadius.mediumRadius,
                            ),
                            child: Text(m.text,
                                style: AppTextStyles.body.copyWith(color: m.isFromUser ? Colors.white : AppColors.textPrimary)),
                          ),
                        );
                      },
                    ),
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Nhập câu hỏi...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
