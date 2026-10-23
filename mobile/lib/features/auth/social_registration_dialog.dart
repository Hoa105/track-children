import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'parent_role.dart';

class SocialRegistrationDialog extends StatefulWidget {
  const SocialRegistrationDialog({
    required this.providerName,
    required this.account,
    super.key,
  });

  final String providerName;
  final Map<String, dynamic> account;

  @override
  State<SocialRegistrationDialog> createState() =>
      _SocialRegistrationDialogState();
}

class _SocialRegistrationDialogState extends State<SocialRegistrationDialog> {
  bool _accepted = false;
  bool _choosingRole = false;
  bool _loadingDocuments = false;
  ParentRole? _role;
  String? _error;

  Future<void> _readTerms() async {
    setState(() {
      _loadingDocuments = true;
      _error = null;
    });
    try {
      final documents = await AuthService.instance.documents();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Điều khoản và chính sách'),
          content: SizedBox(
            width: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final document in documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${switch (document['docType']) {
                        'terms' => 'Điều khoản sử dụng',
                        'privacy' => 'Chính sách quyền riêng tư',
                        'data_policy' => 'Chính sách dữ liệu',
                        _ => document['docType'],
                      }} — ${document['version']}\n${document['content']}',
                    ),
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
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingDocuments = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      _choosingRole
          ? 'Chọn vai trò với bé'
          : 'Tiếp tục với ${widget.providerName}',
    ),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(
              (widget.account['displayName'] as String?)?.trim().isNotEmpty ==
                      true
                  ? widget.account['displayName'] as String
                  : 'Tài khoản ${widget.providerName} đã chọn',
            ),
            subtitle: widget.account['email'] != null
                ? Text(widget.account['email'] as String)
                : null,
          ),
          const SizedBox(height: 12),
          if (!_choosingRole) ...[
            CheckboxListTile(
              key: const ValueKey('social-consent'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              title: const Text(
                'Tôi đồng ý với Điều khoản sử dụng và Chính sách quyền riêng tư',
              ),
            ),
            TextButton(
              onPressed: _loadingDocuments ? null : _readTerms,
              child: Text(
                _loadingDocuments
                    ? 'Đang tải điều khoản…'
                    : 'Đọc điều khoản và chính sách',
              ),
            ),
          ] else ...[
            const Text('Bạn có vai trò gì với bé?'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in ParentRole.values)
                  ChoiceChip(
                    label: Text(role.label),
                    selected: _role == role,
                    onSelected: (_) => setState(() => _role = role),
                  ),
              ],
            ),
          ],
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      if (_choosingRole)
        TextButton(
          onPressed: () => setState(() => _choosingRole = false),
          child: const Text('Quay lại'),
        ),
      FilledButton(
        onPressed:
            _loadingDocuments ||
                (!_choosingRole && !_accepted) ||
                (_choosingRole && _role == null)
            ? null
            : () {
                if (!_choosingRole) {
                  setState(() => _choosingRole = true);
                } else {
                  Navigator.pop(
                    context,
                    SocialRegistrationConsent(
                      relationship: _role!.registrationValue,
                    ),
                  );
                }
              },
        child: Text(_choosingRole ? 'Hoàn tất đăng ký' : 'Tiếp tục'),
      ),
    ],
  );
}
