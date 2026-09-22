import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/community_post.dart';
import '../../../services/service_locator.dart';

class CommunityCreatePostScreen extends StatefulWidget {
  const CommunityCreatePostScreen({super.key});

  @override
  State<CommunityCreatePostScreen> createState() => _CommunityCreatePostScreenState();
}

class _CommunityCreatePostScreenState extends State<CommunityCreatePostScreen> {
  final _contentCtrl = TextEditingController();
  bool _hasPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _contentCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _contentCtrl.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final username = ServiceLocator.authService.currentUser.username;
    await ServiceLocator.communityService.addPost(CommunityPost(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      authorName: username,
      authorInitial: username.trim().isNotEmpty ? username.trim().substring(0, 1).toUpperCase() : '?',
      createdAt: DateTime.now(),
      content: _contentCtrl.text.trim(),
      hasPhoto: _hasPhoto,
    ));
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ với cộng đồng'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Hủy')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceGreen,
                    child: Text(
                      ServiceLocator.authService.currentUser.username.trim().isNotEmpty
                          ? ServiceLocator.authService.currentUser.username.trim().substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Đăng công khai cho cộng đồng phụ huynh', style: AppTextStyles.bodySecondary),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                hint: 'Chia sẻ kinh nghiệm, câu hỏi hoặc câu chuyện của bạn...',
                controller: _contentCtrl,
                maxLines: 6,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_hasPhoto)
                Stack(
                  children: [
                    const IllustrationPlaceholder(label: 'ảnh đã chọn', height: 140),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _hasPhoto = false),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.surface,
                          child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _hasPhoto = true),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Chụp ảnh'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _hasPhoto = true),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Thư viện'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amberSurfaceLight,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.amberBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.amberDark),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Bài viết sẽ hiển thị công khai với các phụ huynh khác. '
                        'Vui lòng không chia sẻ thông tin định danh của bé.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: _saving ? 'Đang đăng...' : 'Đăng bài',
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
