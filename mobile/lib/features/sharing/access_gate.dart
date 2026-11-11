import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Thay nội dung một mục khi người được chia sẻ không có quyền xem (F23).
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key, required this.section});

  /// Tên mục, vd. "nhật ký", "lịch tiêm chủng".
  final String section;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 44,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Bạn chưa được cấp quyền xem $section của bé',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhờ chủ hồ sơ cấp quyền trong mục Chia sẻ hồ sơ bé.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

/// Dải thông báo khi chỉ được xem: các nút thêm / sửa / xóa đã được ẩn.
class ReadOnlyNotice extends StatelessWidget {
  const ReadOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('read-only-notice'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Bạn chỉ có quyền xem mục này.',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
