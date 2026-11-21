import '../../services/demo_store.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';

enum _OwnershipChoice { transfer, deleteWithAccount }

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late final Map<String, _OwnershipChoice?> _choices =
      DemoStore.instance.signedIn
      ? {
          for (final c in DemoStore.instance.children)
            c['full_name'] as String: null,
        }
      : {'Bé An': null};

  Future<void> _continue() async {
    if (_choices.values.any((choice) => choice == null)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SettingsColors.surface,
        title: const Text(
          'Xác nhận yêu cầu xóa tài khoản',
          style: TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Bạn đã chọn cách xử lý các hồ sơ trẻ. Tiếp tục sẽ gửi yêu cầu xóa tài khoản.',
          style: TextStyle(color: SettingsColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: SettingsColors.textSecondary,
            ),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB44545),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yêu cầu xóa tài khoản chưa được kết nối dịch vụ.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SettingsColors.background,
    appBar: AppBar(
      backgroundColor: SettingsColors.background,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
      title: const Text(
        'Xóa tài khoản và dữ liệu',
        style: TextStyle(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFAA5A3B),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Trước khi gửi yêu cầu xóa tài khoản, hãy chọn cách xử lý quyền sở hữu từng hồ sơ trẻ.',
                            style: TextStyle(
                              height: 1.45,
                              color: SettingsColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'HỒ SƠ TRẺ ĐANG QUẢN LÝ',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: SettingsColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final childName in _choices.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OwnershipCard(
                        name: childName,
                        choice: _choices[childName],
                        onChanged: (choice) =>
                            setState(() => _choices[childName] = choice),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed:
                          _choices.values.every((choice) => choice != null)
                          ? _continue
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB44545),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Tiếp tục xóa tài khoản'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Bạn vẫn có thể quay lại nếu chưa muốn tiếp tục.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SettingsColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OwnershipCard extends StatelessWidget {
  const _OwnershipCard({
    required this.name,
    required this.choice,
    required this.onChanged,
  });

  final String name;
  final _OwnershipChoice? choice;
  final ValueChanged<_OwnershipChoice> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SettingsColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SettingsColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: SettingsColors.iconBackground,
              child: Icon(
                Icons.child_care_rounded,
                color: SettingsColors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: SettingsColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Chuyển quyền quản lý'),
              selected: choice == _OwnershipChoice.transfer,
              selectedColor: SettingsColors.accent,
              backgroundColor: SettingsColors.surface,
              labelStyle: TextStyle(
                color: SettingsColors.textPrimary,
                fontWeight: choice == _OwnershipChoice.transfer
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
              side: const BorderSide(color: SettingsColors.border),
              showCheckmark: false,
              onSelected: (_) => onChanged(_OwnershipChoice.transfer),
            ),
            ChoiceChip(
              label: const Text('Xóa hồ sơ cùng tài khoản'),
              selected: choice == _OwnershipChoice.deleteWithAccount,
              selectedColor: SettingsColors.accent,
              backgroundColor: SettingsColors.surface,
              labelStyle: TextStyle(
                color: SettingsColors.textPrimary,
                fontWeight: choice == _OwnershipChoice.deleteWithAccount
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
              side: const BorderSide(color: SettingsColors.border),
              showCheckmark: false,
              onSelected: (_) => onChanged(_OwnershipChoice.deleteWithAccount),
            ),
          ],
        ),
      ],
    ),
  );
}
