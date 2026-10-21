import 'profile.dart';

class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime? createdAt;
  final Profile? author;

  PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.createdAt,
    this.author,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    Profile? authorProfile;
    if (json['author'] != null && json['author'] is Map<String, dynamic>) {
      authorProfile = Profile.fromJson(json['author'] as Map<String, dynamic>);
    } else if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      authorProfile = Profile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    return PostComment(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      author: authorProfile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'user_id': userId,
      'content': content,
    };
  }
}
