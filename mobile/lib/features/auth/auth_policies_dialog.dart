import 'package:flutter/material.dart';

/// Displays the server's policy text without exposing transport metadata.
class AuthPoliciesDialog extends StatelessWidget {
  const AuthPoliciesDialog({super.key, required this.documents});

  final List<Map<String, dynamic>> documents;

  String _title(Object? type) => switch (type) {
    'terms' => 'Điều khoản sử dụng',
    'privacy' => 'Chính sách quyền riêng tư',
    'data_policy' => 'Chính sách dữ liệu',
    _ => 'Thông tin chính sách',
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Điều khoản và chính sách'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final document in documents)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 16),
              title: Text(_title(document['docType'])),
              children: [
                for (final paragraph
                    in (document['content'] as String? ?? '').trim().split(
                      RegExp(r'\r?\n\s*\r?\n'),
                    ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableText(
                        paragraph,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(height: 1.6),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}
