import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class FeedService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Post>> getPosts({int limit = 50}) async {
    final currentUserId = SupabaseService.currentUserId;

    // Fetch posts with nested likes and comments
    final rawPosts = await _client
        .from('posts')
        .select('*, post_likes(user_id), post_comments(id)')
        .order('created_at', ascending: false)
        .limit(limit);

    if (rawPosts.isEmpty) return [];

    // Collect all author IDs to query their profiles
    final authorIds = <String>{};
    for (final p in rawPosts) {
      final authorId = p['author_id']?.toString();
      if (authorId != null && authorId.isNotEmpty) {
        authorIds.add(authorId);
      }
    }

    final profileMap = <String, Profile>{};
    if (authorIds.isNotEmpty) {
      // First pass: try matching profiles by id
      try {
        final profilesRes = await _client
            .from('profiles')
            .select()
            .filter('id', 'in', authorIds.toList());

        for (final item in profilesRes) {
          final profile = Profile.fromJson(item);
          profileMap[profile.id] = profile;
          if (profile.userId != null) {
            profileMap[profile.userId!] = profile;
          }
        }
      } catch (_) {}

      // Second pass: for any author IDs not yet resolved, try by user_id
      final unresolvedIds = authorIds.where((id) => !profileMap.containsKey(id)).toList();
      if (unresolvedIds.isNotEmpty) {
        try {
          final profilesRes2 = await _client
              .from('profiles')
              .select()
              .filter('user_id', 'in', unresolvedIds);

          for (final item in profilesRes2) {
            final profile = Profile.fromJson(item);
            profileMap[profile.id] = profile;
            if (profile.userId != null) {
              profileMap[profile.userId!] = profile;
            }
          }
        } catch (_) {}
      }
    }

    return rawPosts.map<Post>((json) {
      final post = Post.fromJson(json, currentUserId: currentUserId);
      final matchedProfile = profileMap[post.authorId];
      if (matchedProfile != null) {
        return post.copyWith(author: matchedProfile);
      }
      return post;
    }).toList();
  }

  Future<Post> createPost({
    required String content,
    Uint8List? imageBytes,
    String? imageExt,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Must be logged in to post');

    String? imageUrl;
    if (imageBytes != null && imageExt != null) {
      final cleanExt = imageExt.replaceAll('.', '').toLowerCase();
      final path =
          '${SupabaseConfig.postFolder}/${userId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

      await _client.storage.from(SupabaseConfig.storageBucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: FileOptions(
              contentType: 'image/$cleanExt',
              upsert: true,
            ),
          );

      imageUrl = _client.storage
          .from(SupabaseConfig.storageBucket)
          .getPublicUrl(path);
    }

    final response = await _client
        .from('posts')
        .insert({
          'author_id': userId,
          'content': content.trim(),
          'image_url': imageUrl,
        })
        .select()
        .single();

    return Post.fromJson(response, currentUserId: userId);
  }

  Future<void> deletePost({
    required String postId,
    String? imageUrl,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Must be logged in to delete post');

    // 1. Delete post row from Supabase
    // Cascade constraints automatically clean up likes and comments.
    // Supabase RLS enforces that users can only delete their own posts.
    await _client.from('posts').delete().eq('id', postId);

    // 2. Best-effort cleanup of associated storage media if present
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final uri = Uri.tryParse(imageUrl);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final bucketIndex =
              uri.pathSegments.indexOf(SupabaseConfig.storageBucket);
          if (bucketIndex != -1 &&
              bucketIndex + 1 < uri.pathSegments.length) {
            final filePath =
                uri.pathSegments.sublist(bucketIndex + 1).join('/');
            await _client
                .storage
                .from(SupabaseConfig.storageBucket)
                .remove([filePath]);
          }
        }
      } catch (_) {
        // Storage cleanup failures shouldn't prevent successful post deletion UX
      }
    }
  }

  Future<void> toggleLike({
    required String postId,
    required bool currentlyLiked,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Must be logged in to like');

    if (currentlyLiked) {
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } else {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  Future<List<PostComment>> getComments(String postId) async {
    final rawComments = await _client
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    if (rawComments.isEmpty) return [];

    final userIds = rawComments
        .map((c) => c['user_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final profileMap = <String, Profile>{};
    if (userIds.isNotEmpty) {
      // First pass: try matching by id
      try {
        final profilesRes = await _client
            .from('profiles')
            .select()
            .filter('id', 'in', userIds);

        for (final p in profilesRes) {
          final profile = Profile.fromJson(p);
          profileMap[profile.id] = profile;
          if (profile.userId != null) profileMap[profile.userId!] = profile;
        }
      } catch (_) {}

      // Second pass: try by user_id for any unresolved
      final unresolvedIds = userIds.where((id) => !profileMap.containsKey(id)).toList();
      if (unresolvedIds.isNotEmpty) {
        try {
          final profilesRes2 = await _client
              .from('profiles')
              .select()
              .filter('user_id', 'in', unresolvedIds);

          for (final p in profilesRes2) {
            final profile = Profile.fromJson(p);
            profileMap[profile.id] = profile;
            if (profile.userId != null) profileMap[profile.userId!] = profile;
          }
        } catch (_) {}
      }
    }

    return rawComments.map<PostComment>((json) {
      final comment = PostComment.fromJson(json);
      final author = profileMap[comment.userId];
      return PostComment(
        id: comment.id,
        postId: comment.postId,
        userId: comment.userId,
        content: comment.content,
        createdAt: comment.createdAt,
        author: author,
      );
    }).toList();
  }

  Future<PostComment> addComment({
    required String postId,
    required String content,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Must be logged in to comment');

    final response = await _client
        .from('post_comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'content': content.trim(),
        })
        .select()
        .single();

    return PostComment.fromJson(response);
  }
}
