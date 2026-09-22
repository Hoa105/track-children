import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/community_post.dart';
import '../../../services/service_locator.dart';
import 'companion_screen.dart';

/// List of community posts the user has bookmarked, opened from the
/// bookmark icon on [CompanionScreen]'s app bar. Reuses [PostCard] so a
/// saved post looks and behaves exactly like it does in the main feed
/// (unsaving here removes it from this list on the next load).
class CompanionSavedScreen extends StatefulWidget {
  const CompanionSavedScreen({super.key});

  @override
  State<CompanionSavedScreen> createState() => _CompanionSavedScreenState();
}

class _CompanionSavedScreenState extends State<CompanionSavedScreen> {
  List<CommunityPost>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posts = await ServiceLocator.communityService.getSavedPosts();
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết đã lưu')),
      body: posts == null
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? Center(child: Text('Chưa có bài viết nào được lưu.', style: AppTextStyles.bodySecondary))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => PostCard(
                    post: posts[i],
                    onLike: () => _toggleLike(posts[i]),
                    onComment: () => openCommentsSheet(context, posts[i], () => setState(() {})),
                    onShare: () => openShareSheet(context),
                    onSave: () => _toggleSave(posts[i]),
                  ),
                ),
    );
  }
}
