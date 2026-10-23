import 'package:flutter_test/flutter_test.dart';
import 'package:waitaki_network/models/post.dart';
import 'package:waitaki_network/models/profile.dart';

void main() {
  group('Post model - isAuthoredBy', () {
    test('returns true when authorId directly matches currentUserId', () {
      final post = Post(
        id: 'post-1',
        authorId: 'user-123',
        content: 'Hello Waitaki network!',
      );

      expect(post.isAuthoredBy('user-123'), isTrue);
      expect(post.isAuthoredBy('user-456'), isFalse);
    });

    test('returns true when post author profile userId matches currentUserId', () {
      final profile = Profile(
        id: 'profile-abc',
        userId: 'user-999',
        firstName: 'John',
        lastName: 'Doe',
      );
      final post = Post(
        id: 'post-2',
        authorId: 'profile-abc',
        content: 'Community update',
        author: profile,
      );

      expect(post.isAuthoredBy('user-999'), isTrue);
      expect(post.isAuthoredBy('profile-abc'), isTrue);
      expect(post.isAuthoredBy('other-user'), isFalse);
    });

    test('returns false when currentUserId is null or empty', () {
      final post = Post(
        id: 'post-3',
        authorId: 'user-123',
        content: 'Test content',
      );

      expect(post.isAuthoredBy(null), isFalse);
      expect(post.isAuthoredBy(''), isFalse);
    });
  });

  group('Post list deletion handling', () {
    test('removes post by id correctly from feed post list', () {
      final posts = [
        Post(id: 'post-1', authorId: 'user-1', content: 'Post 1'),
        Post(id: 'post-2', authorId: 'user-1', content: 'Post 2'),
        Post(id: 'post-3', authorId: 'user-2', content: 'Post 3'),
      ];

      posts.removeWhere((p) => p.id == 'post-2');

      expect(posts.length, equals(2));
      expect(posts.any((p) => p.id == 'post-2'), isFalse);
      expect(posts.first.id, equals('post-1'));
      expect(posts.last.id, equals('post-3'));
    });
  });
}
