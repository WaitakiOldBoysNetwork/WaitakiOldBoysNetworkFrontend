import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/post.dart';
import '../../../services/feed_service.dart';
import 'comments_sheet.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;

  const PostCard({super.key, required this.post, this.onPostUpdated});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _feedService = FeedService();
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLiking = false;

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
        currentlyLiked: !_isLiked, // invert because we optimistically flipped
      );
    } catch (e) {
      // Revert if error
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

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: widget.post.id,
        onCommentAdded: () {
          setState(() {
            _commentsCount += 1;
          });
          widget.onPostUpdated?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post.author;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.navyPrimary.withValues(
                    alpha: 0.08,
                  ),
                  backgroundImage:
                      (author?.avatarUrl != null &&
                          author!.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(author.avatarUrl!)
                      : null,
                  child:
                      (author?.avatarUrl == null || author!.avatarUrl!.isEmpty)
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
                const SizedBox(width: 12),

                // Name & Headline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              author?.fullName ?? 'Old Boy Member',
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
                                color: AppColors.goldAccent.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.goldAccent.withValues(
                                    alpha: 0.5,
                                  ),
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
              ],
            ),
          ),

          // Post Content
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                widget.post.content,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

          // Post Media Image
          if (widget.post.imageUrl != null &&
              widget.post.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              child: CachedNetworkImage(
                imageUrl: widget.post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 220,
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

          // Metrics row (if likes or comments > 0)
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
                          '$_likesCount',
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
                    GestureDetector(
                      onTap: _openComments,
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

          // Interaction Bar
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

                // Comment Button
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openComments,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Comment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
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
        ],
      ),
    );
  }
}
