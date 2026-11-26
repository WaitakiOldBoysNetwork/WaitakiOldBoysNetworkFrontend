import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/post.dart';
import '../../../models/post_comment.dart';
import '../../../models/profile.dart';
import '../../../services/feed_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/supabase_service.dart';
import '../../profile/profile_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;
  final VoidCallback? onPostDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.onPostUpdated,
    this.onPostDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _feedService = FeedService();
  final _profileService = ProfileService();
  final _commentController = TextEditingController();

  bool _isDeleting = false;

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

  void _copyPostText() {
    if (widget.post.content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.post.content));
    SnackbarHelper.showSuccess(context, 'Post text copied to clipboard');
  }

  Future<void> _confirmAndDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger(ctx).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger(ctx),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.heading(ctx),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(
            color: AppColors.subtext(ctx),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.subtext(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _feedService.deletePost(
        postId: widget.post.id,
        imageUrl: widget.post.imageUrl,
      );
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Post deleted');
        widget.onPostDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        SnackbarHelper.showError(context, 'Failed to delete post: $e');
      }
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
    final currentUserId = SupabaseService.currentUserId;
    final isMyPost = widget.post.isAuthoredBy(currentUserId);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isDeleting ? 0.5 : 1.0,
      child: IgnorePointer(
        ignoring: _isDeleting,
        child: Card(
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
                    backgroundColor:
                        AppColors.brand(context).withValues(alpha: 0.12),
                    backgroundImage: (author?.avatarUrl != null &&
                            author!.avatarUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(author.avatarUrl!)
                        : null,
                    child: (author?.avatarUrl == null || author!.avatarUrl!.isEmpty)
                        ? Text(
                            author?.initials ?? 'OB',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand(context),
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
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heading(context),
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.isDark(context)
                                        ? AppColors.goldAccent
                                        : AppColors.goldDark,
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
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.subtext(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          DateFormatter.timeAgo(widget.post.createdAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Post options menu (Delete for author, Copy text)
                if (isMyPost || widget.post.content.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  if (_isDeleting)
                    Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.danger(context),
                        ),
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      tooltip: 'Post options',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.muted(context),
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.line(context)),
                      ),
                      offset: const Offset(0, 36),
                      onSelected: (val) {
                        if (val == 'delete') {
                          _confirmAndDeletePost();
                        } else if (val == 'copy') {
                          _copyPostText();
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (widget.post.content.isNotEmpty)
                          PopupMenuItem<String>(
                            value: 'copy',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: AppColors.subtext(context),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Copy text',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.body(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isMyPost) ...[
                          if (widget.post.content.isNotEmpty)
                            const PopupMenuDivider(height: 1),
                          PopupMenuItem<String>(
                            value: 'delete',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: AppColors.danger(context),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Delete post',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ],
            ),
          ),

          // 2. Post Content
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SelectableText(
                widget.post.content,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: AppColors.body(context),
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
                  color: AppColors.cardMuted(context),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand(context),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 140,
                  color: AppColors.cardMuted(context),
                  child: Center(
                    child: Icon(Icons.broken_image, color: AppColors.muted(context)),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.subtext(context),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext(context),
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
                                : AppColors.subtext(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Like',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isLiked
                                  ? AppColors.likeActive
                                  : AppColors.subtext(context),
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
                                ? AppColors.brand(context)
                                : AppColors.subtext(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Comment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _showInlineComments
                                  ? AppColors.brand(context)
                                  : AppColors.subtext(context),
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
              color: AppColors.cardMuted(context),
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
                        backgroundColor:
                            AppColors.brand(context).withValues(alpha: 0.12),
                        backgroundImage: (_currentProfile?.avatarUrl != null &&
                                _currentProfile!.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(_currentProfile!.avatarUrl!)
                            : null,
                        child: (_currentProfile?.avatarUrl == null ||
                                _currentProfile!.avatarUrl!.isEmpty)
                            ? Text(
                                _currentProfile?.initials ?? 'OB',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brand(context),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.line(context)),
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
                                    : Icon(
                                        Icons.send_rounded,
                                        size: 18,
                                        color: AppColors.brand(context),
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand(context),
                        ),
                      ),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        'No comments yet. Be the first to start the conversation!',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted(context),
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
    ),
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
            backgroundColor: AppColors.brand(context).withValues(alpha: 0.12),
            backgroundImage:
                (cAuthor?.avatarUrl != null && cAuthor!.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(cAuthor.avatarUrl!)
                    : null,
            child: (cAuthor?.avatarUrl == null || cAuthor!.avatarUrl!.isEmpty)
                ? Text(
                    cAuthor?.initials ?? 'OB',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand(context),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        cAuthor?.fullName ?? 'Old Boy',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.heading(context),
                        ),
                      ),
                      if (cAuthor?.gradYear != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          DateFormatter.shortGradYear(cAuthor?.gradYear),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.isDark(context)
                                ? AppColors.goldAccent
                                : AppColors.goldDark,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        DateFormatter.timeAgo(comment.createdAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    comment.content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.body(context),
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
