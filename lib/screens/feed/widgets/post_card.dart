import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/post.dart';
import '../../../models/post_comment.dart';
import '../../../models/profile.dart';
import '../../../services/feed_service.dart';
import '../../../services/profile_service.dart';
import '../../profile/profile_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;

  const PostCard({super.key, required this.post, this.onPostUpdated});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _feedService = FeedService();
  final _profileService = ProfileService();
  final _commentController = TextEditingController();

  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLiking = false;

  // Desktop Inline Comments
  bool _showInlineComments = false;
  bool _isLoadingComments = false;
  bool _isSubmittingComment = false;
  List<PostComment> _comments = [];
  Profile? _currentProfile;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.isLikedByMe != widget.post.isLikedByMe ||
        oldWidget.post.likesCount != widget.post.likesCount ||
        oldWidget.post.commentsCount != widget.post.commentsCount) {
      _isLiked = widget.post.isLikedByMe;
      _likesCount = widget.post.likesCount;
      _commentsCount = widget.post.commentsCount;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleToggleLike() async {
    if (_isLiking) return;
    setState(() {
      _isLiking = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await _feedService.toggleLike(
        postId: widget.post.id,
        currentlyLiked: !_isLiked,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
        SnackbarHelper.showError(context, 'Unable to like: $e');
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _toggleComments() async {
    setState(() {
      _showInlineComments = !_showInlineComments;
    });

    if (_showInlineComments && _comments.isEmpty) {
      setState(() => _isLoadingComments = true);
      try {
        final results = await Future.wait([
          _feedService.getComments(widget.post.id),
          _profileService.getCurrentProfile(),
        ]);
        if (mounted) {
          setState(() {
            _comments = results[0] as List<PostComment>;
            _currentProfile = results[1] as Profile?;
            _isLoadingComments = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingComments = false);
        }
      }
    }
  }

  Future<void> _handleSubmitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmittingComment = true);
    try {
      final newComment = await _feedService.addComment(
        postId: widget.post.id,
        content: text,
      );
      _commentController.clear();

      if (mounted) {
        setState(() {
          _comments.add(newComment.copyWith(author: _currentProfile));
          _commentsCount += 1;
        });
        widget.onPostUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to post comment: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  void _navigateToAuthorProfile(Profile? author) {
    if (author == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: author.userId ?? author.id,
          initialProfile: author,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post.author;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                InkWell(
                  onTap: () => _navigateToAuthorProfile(author),
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.08),
                    backgroundImage: (author?.avatarUrl != null &&
                            author!.avatarUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(author.avatarUrl!)
                        : null,
                    child: (author?.avatarUrl == null || author!.avatarUrl!.isEmpty)
                        ? Text(
                            author?.initials ?? 'OB',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyPrimary,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Headline
                Expanded(
                  child: InkWell(
                    onTap: () => _navigateToAuthorProfile(author),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                author?.fullName ?? 'Waitakian Old Boy',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navyDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (author?.gradYear != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.goldAccent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.goldAccent.withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  DateFormatter.shortGradYear(author?.gradYear),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.goldDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (author?.headline != null &&
                            author!.headline!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            author.headline!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          DateFormatter.timeAgo(widget.post.createdAt),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Post Content
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SelectableText(
                widget.post.content,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

          // 3. Media Image
          if (widget.post.imageUrl != null &&
              widget.post.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              child: CachedNetworkImage(
                imageUrl: widget.post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 260,
                  color: AppColors.surfaceMuted,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 140,
                  color: AppColors.surfaceMuted,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ],

          // 4. Metrics Row
          if (_likesCount > 0 || _commentsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_likesCount > 0)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.likeActive,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_likesCount ${_likesCount == 1 ? 'like' : 'likes'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  if (_commentsCount > 0)
                    InkWell(
                      onTap: _toggleComments,
                      child: Text(
                        '$_commentsCount ${_commentsCount == 1 ? 'comment' : 'comments'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const Divider(height: 1),

          // 5. Desktop Interaction Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like Button
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _handleToggleLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: _isLiked
                                ? AppColors.likeActive
                                : AppColors.likeInactive,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Like',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isLiked
                                  ? AppColors.likeActive
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Comment Toggle Button
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _toggleComments,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showInlineComments
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: _showInlineComments
                                ? AppColors.navyPrimary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Comment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _showInlineComments
                                  ? AppColors.navyPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 6. Desktop Inline Comments Section
          if (_showInlineComments) ...[
            const Divider(height: 1),
            Container(
              color: AppColors.surfaceMuted,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Comment input box
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.1),
                        backgroundImage: (_currentProfile?.avatarUrl != null &&
                                _currentProfile!.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(_currentProfile!.avatarUrl!)
                            : null,
                        child: (_currentProfile?.avatarUrl == null ||
                                _currentProfile!.avatarUrl!.isEmpty)
                            ? Text(
                                _currentProfile?.initials ?? 'OB',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navyPrimary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _handleSubmitComment(),
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: const InputDecoration(
                                    hintText: 'Add a thought or reply...',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: _isSubmittingComment
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        size: 18,
                                        color: AppColors.navyPrimary,
                                      ),
                                onPressed: _isSubmittingComment
                                    ? null
                                    : _handleSubmitComment,
                                tooltip: 'Post comment',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Comments list
                  if (_isLoadingComments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                    )
                  else if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        'No comments yet. Be the first to start the conversation!',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ..._comments.map((c) => _buildCommentItem(c)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(PostComment comment) {
    final cAuthor = comment.author;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.1),
            backgroundImage:
                (cAuthor?.avatarUrl != null && cAuthor!.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(cAuthor.avatarUrl!)
                    : null,
            child: (cAuthor?.avatarUrl == null || cAuthor!.avatarUrl!.isEmpty)
                ? Text(
                    cAuthor?.initials ?? 'OB',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        cAuthor?.fullName ?? 'Old Boy',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.navyDark,
                        ),
                      ),
                      if (cAuthor?.gradYear != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          DateFormatter.shortGradYear(cAuthor?.gradYear),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.goldDark,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        DateFormatter.timeAgo(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension PostCommentCopyWith on PostComment {
  PostComment copyWith({Profile? author}) {
    return PostComment(
      id: id,
      postId: postId,
      userId: userId,
      content: content,
      createdAt: createdAt,
      author: author ?? this.author,
    );
  }
}
