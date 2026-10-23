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
        title: const Text('Xác nhận yêu cầu xóa tài khoản'),
        content: const Text(
          'Bạn đã chọn cách xử lý các hồ sơ trẻ. Tiếp tục sẽ gửi yêu cầu xóa tài khoản.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
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
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Xóa tài khoản và dữ liệu'),
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
                            style: TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'HỒ SƠ TRẺ ĐANG QUẢN LÝ',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
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
                    style: TextStyle(color: AppColors.textSecondary),
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.child_care_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              onSelected: (_) => onChanged(_OwnershipChoice.transfer),
            ),
            ChoiceChip(
              label: const Text('Xóa hồ sơ cùng tài khoản'),
              selected: choice == _OwnershipChoice.deleteWithAccount,
              onSelected: (_) => onChanged(_OwnershipChoice.deleteWithAccount),
            ),
          ],
        ),
      ],
    ),
  );
}
