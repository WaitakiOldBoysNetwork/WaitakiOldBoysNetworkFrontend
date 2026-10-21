import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../services/feed_service.dart';
import '../../services/profile_service.dart';
import 'create_post_screen.dart';
import 'widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;

  const FeedScreen({super.key, this.onNavigateToProfile});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _feedService = FeedService();
  final _profileService = ProfileService();

  List<Post> _posts = [];
  Profile? _currentProfile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _feedService.getPosts(),
        _profileService.getCurrentProfile(),
      ]);

      if (mounted) {
        setState(() {
          _posts = results[0] as List<Post>;
          _currentProfile = results[1] as Profile?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePostScreen(),
        fullscreenDialog: true,
      ),
    );

    if (created == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.navyPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.school,
                color: AppColors.goldAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Waitaki Old Boys',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyDark,
                  ),
                ),
                Text(
                  'Alumni Feed',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: widget.onNavigateToProfile,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.1),
                backgroundImage:
                    (_currentProfile?.avatarUrl != null &&
                        _currentProfile!.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(_currentProfile!.avatarUrl!)
                    : null,
                child:
                    (_currentProfile?.avatarUrl == null ||
                        _currentProfile!.avatarUrl!.isEmpty)
                    ? Text(
                        _currentProfile?.initials ?? 'OB',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyPrimary,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePost,
        backgroundColor: AppColors.navyPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.navyPrimary,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.navyPrimary,
                    ),
                  )
                : _errorMessage != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppColors.crimson,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error Loading Feed',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _posts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Top Quick Composer Card
                        return _buildComposerCard();
                      }

                      final post = _posts[index - 1];
                      return PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onPostUpdated: _loadData,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposerCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.1),
                  backgroundImage:
                      (_currentProfile?.avatarUrl != null &&
                          _currentProfile!.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(_currentProfile!.avatarUrl!)
                      : null,
                  child:
                      (_currentProfile?.avatarUrl == null ||
                          _currentProfile!.avatarUrl!.isEmpty)
                      ? Text(
                          _currentProfile?.initials ?? 'OB',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _openCreatePost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Share an update with fellow Old Boys...',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: _openCreatePost,
                  icon: const Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: AppColors.navyPrimary,
                  ),
                  label: const Text('Photo'),
                ),
                TextButton.icon(
                  onPressed: _openCreatePost,
                  icon: const Icon(
                    Icons.event_note_outlined,
                    size: 18,
                    color: AppColors.goldDark,
                  ),
                  label: const Text('Event / Reunion'),
                ),
                TextButton.icon(
                  onPressed: _openCreatePost,
                  icon: const Icon(
                    Icons.article_outlined,
                    size: 18,
                    color: AppColors.crimson,
                  ),
                  label: const Text('Article'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
