class CommunityComment {
  final String id;
  final String authorName;
  final String authorInitial;
  final String content;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.authorName,
    required this.authorInitial,
    required this.content,
    required this.createdAt,
  });
}

class CommunityPost {
  final String id;
  final String authorName;
  final String authorInitial;
  final DateTime createdAt;
  final String content;
  final bool hasPhoto;
  int likeCount;
  bool liked;
  bool saved;
  final List<CommunityComment> comments;

  CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorInitial,
    required this.createdAt,
    required this.content,
    this.hasPhoto = false,
    this.likeCount = 0,
    this.liked = false,
    this.saved = false,
    List<CommunityComment>? comments,
  }) : comments = comments ?? [];
}
