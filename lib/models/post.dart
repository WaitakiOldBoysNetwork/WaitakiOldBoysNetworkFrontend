import 'profile.dart';

class Post {
  final String id;
  final String authorId;
  final String content;
  final String? imageUrl;
  final DateTime? createdAt;
  final Profile? author;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;

  Post({
    required this.id,
    required this.authorId,
    required this.content,
    this.imageUrl,
    this.createdAt,
    this.author,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
  });

  factory Post.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    // Author resolution
    Profile? authorProfile;
    if (json['author'] != null && json['author'] is Map<String, dynamic>) {
      authorProfile = Profile.fromJson(json['author'] as Map<String, dynamic>);
    } else if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      authorProfile = Profile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    // Likes count & isLikedByMe
    int likes = 0;
    bool liked = false;
    if (json['post_likes'] is List) {
      final likesList = json['post_likes'] as List;
      likes = likesList.length;
      if (currentUserId != null) {
        liked = likesList.any((l) =>
            l is Map && (l['user_id']?.toString() == currentUserId));
      }
    } else if (json['likes_count'] != null) {
      likes = int.tryParse(json['likes_count'].toString()) ?? 0;
      liked = json['is_liked'] == true;
    }

    // Comments count
    int comments = 0;
    if (json['post_comments'] is List) {
      comments = (json['post_comments'] as List).length;
    } else if (json['comments_count'] != null) {
      comments = int.tryParse(json['comments_count'].toString()) ?? 0;
    }

    return Post(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      author: authorProfile,
      likesCount: likes,
      commentsCount: comments,
      isLikedByMe: liked,
    );
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    Profile? author,
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}
