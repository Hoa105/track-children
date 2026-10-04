import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/illustration_placeholder.dart';
import '../../../models/community_post.dart';
import '../../../services/service_locator.dart';

/// "Góc đồng hành" now holds only the parent-community feed. Static UI
/// prototype: create post, like, comment and save all mutate an in-memory
/// mock service only — no moderation/report pipeline.
class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  List<CommunityPost>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posts = await ServiceLocator.communityService.getPosts();
    if (mounted) setState(() => _posts = posts);
  }

  void _toggleLike(CommunityPost post) {
    setState(() {
      post.liked = !post.liked;
      post.likeCount += post.liked ? 1 : -1;
    });
  }

  void _toggleSave(CommunityPost post) {
    setState(() => post.saved = !post.saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(post.saved ? 'Đã lưu bài viết' : 'Đã bỏ lưu bài viết')),
    );
  }

  void _openComments(CommunityPost post) => openCommentsSheet(context, post, () => setState(() {}));

  void _openShare(CommunityPost post) => openShareSheet(context);

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return AppShellScaffold(
      tab: AppTab.more,
      appBar: AppBar(
        title: const Text('Góc đồng hành'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Bài viết đã lưu',
            onPressed: () => context.push(AppRoutes.companionSaved),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await context.push(AppRoutes.communityCreatePost);
          _load();
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: posts == null
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? Center(child: Text('Chưa có bài viết nào.', style: AppTextStyles.bodySecondary))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => PostCard(
                    post: posts[i],
                    onLike: () => _toggleLike(posts[i]),
                    onComment: () => _openComments(posts[i]),
                    onShare: () => _openShare(posts[i]),
                    onSave: () => _toggleSave(posts[i]),
                  ),
                ),
    );
  }
}

/// Shared with [CompanionSavedScreen] so tapping "Bình luận" on a saved
/// post opens the same comments sheet as it does in the main feed.
void openCommentsSheet(BuildContext context, CommunityPost post, VoidCallback onCommentAdded) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
    ),
    builder: (context) => _CommentsSheet(post: post, onCommentAdded: onCommentAdded),
  );
}

/// Shared with [CompanionSavedScreen]; see [openCommentsSheet].
void openShareSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
    ),
    builder: (context) => const _ShareSheet(),
  );
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 1) return '${diff.inDays} ngày trước';
  if (diff.inHours >= 1) return '${diff.inHours} giờ trước';
  if (diff.inMinutes >= 1) return '${diff.inMinutes} phút trước';
  return 'Vừa xong';
}

/// Also reused by [CompanionSavedScreen] to render saved posts identically.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceGreen,
                child: Text(post.authorInitial,
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryDark)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName, style: AppTextStyles.titleMedium),
                    Text(_timeAgo(post.createdAt), style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(post.content, style: AppTextStyles.body),
          if (post.hasPhoto) ...[
            const SizedBox(height: AppSpacing.md),
            const IllustrationPlaceholder(label: 'ảnh phụ huynh chia sẻ', height: 140),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: '${post.likeCount}',
                  color: post.liked ? AppColors.danger : AppColors.textSecondary,
                  onTap: onLike,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.comments.length}',
                  color: AppColors.textSecondary,
                  onTap: onComment,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Chia sẻ',
                  color: AppColors.textSecondary,
                  onTap: onShare,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: 'Lưu',
                  color: post.saved ? AppColors.primaryDark : AppColors.textSecondary,
                  onTap: onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smallRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.onCommentAdded});

  final CommunityPost post;
  final VoidCallback onCommentAdded;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.post.comments.add(CommunityComment(
        id: 'c${DateTime.now().microsecondsSinceEpoch}',
        authorName: 'Bạn',
        authorInitial: 'B',
        content: text,
        createdAt: DateTime.now(),
      ));
      _controller.clear();
    });
    widget.onCommentAdded();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: AppRadius.pillRadius),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Bình luận', style: AppTextStyles.h3),
            ),
            Expanded(
              child: widget.post.comments.isEmpty
                  ? Center(child: Text('Chưa có bình luận nào.', style: AppTextStyles.bodySecondary))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: widget.post.comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final comment = widget.post.comments[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.surfaceGreen,
                              child: Text(comment.authorInitial,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment.authorName, style: AppTextStyles.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(comment.content, style: AppTextStyles.body),
                                  const SizedBox(height: 2),
                                  Text(_timeAgo(comment.createdAt), style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(hintText: 'Viết bình luận...'),
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

class _ShareSheet extends StatelessWidget {
  const _ShareSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chia sẻ bài viết', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.md),
            _shareOption(context, Icons.link_rounded, 'Sao chép liên kết', 'Đã sao chép liên kết bài viết'),
            _shareOption(context, Icons.chat_bubble_outline_rounded, 'Chia sẻ qua Zalo', 'Đã mở Zalo để chia sẻ'),
            _shareOption(context, Icons.facebook_rounded, 'Chia sẻ qua Facebook', 'Đã mở Facebook để chia sẻ'),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(BuildContext context, IconData icon, String label, String feedback) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryDark),
      title: Text(label, style: AppTextStyles.body),
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(feedback)));
      },
    );
  }
}
