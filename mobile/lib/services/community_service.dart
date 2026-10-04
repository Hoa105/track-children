import '../models/community_post.dart';

abstract class CommunityService {
  Future<List<CommunityPost>> getPosts();
  Future<void> addPost(CommunityPost post);
  Future<List<CommunityPost>> getSavedPosts();
}

/// In-memory only — no moderation/report pipeline. A static prototype of
/// the parent-community UI, not a production-ready feature (see companion
/// screen discussion on moderation cost before shipping this for real).
class MockCommunityService implements CommunityService {
  final List<CommunityPost> _posts = [
    CommunityPost(
      id: 'p1',
      authorName: 'Mẹ Hà',
      authorInitial: 'H',
      createdAt: DateTime(2026, 9, 18),
      content:
          'Con mình chậm nói, 2 tuổi mới bật từ đơn. Sau 6 tháng kiên trì đọc sách '
          'và hạn chế cho xem điện thoại thì bé đã nói được câu 3-4 từ. Đừng bỏ cuộc mẹ nhé!',
      hasPhoto: true,
      likeCount: 12,
      comments: [
        CommunityComment(
          id: 'c1',
          authorName: 'Mẹ Linh',
          authorInitial: 'L',
          content: 'Cảm ơn chị đã chia sẻ, em cũng đang lo lắng về bé nhà em.',
          createdAt: DateTime(2026, 9, 18, 14, 20),
        ),
      ],
    ),
    CommunityPost(
      id: 'p2',
      authorName: 'Bố Nam',
      authorInitial: 'N',
      createdAt: DateTime(2026, 9, 15),
      content:
          'Có ai có kinh nghiệm cho bé 18 tháng đi khám phát triển ở đâu uy tín '
          'không ạ? Bé nhà mình có vẻ chậm vận động tinh so với bạn cùng tuổi.',
      likeCount: 4,
      comments: const [],
    ),
    CommunityPost(
      id: 'p3',
      authorName: 'Mẹ Thu',
      authorInitial: 'T',
      createdAt: DateTime(2026, 9, 10),
      content:
          'Chia sẻ vài trò chơi vận động tinh mình hay làm với bé mỗi tối: xâu hạt, '
          'vò giấy, xếp hình. Bé rất thích và tiến bộ rõ sau vài tuần.',
      likeCount: 21,
      comments: [
        CommunityComment(
          id: 'c2',
          authorName: 'Mẹ Hà',
          authorInitial: 'H',
          content: 'Mình cũng sẽ thử cách này, cảm ơn chị!',
          createdAt: DateTime(2026, 9, 11, 9, 0),
        ),
      ],
    ),
  ];

  @override
  Future<List<CommunityPost>> getPosts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _posts.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> addPost(CommunityPost post) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _posts.insert(0, post);
  }

  @override
  Future<List<CommunityPost>> getSavedPosts() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _posts.where((p) => p.saved).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
