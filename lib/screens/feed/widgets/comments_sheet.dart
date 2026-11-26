import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/post_comment.dart';
import '../../../services/feed_service.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onCommentAdded;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.onCommentAdded,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _feedService = FeedService();
  final _commentController = TextEditingController();
  List<PostComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final list = await _feedService.getComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _commentController.clear();

    try {
      final newComment = await _feedService.addComment(
        postId: widget.postId,
        content: text,
      );
      setState(() {
        _comments.add(newComment);
      });
      widget.onCommentAdded();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to post comment: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lineDarker(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments (${_comments.length})',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),

          // Comments List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brand(context),
                    ),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Text(
                      'No comments yet. Start the conversation!',
                      style: TextStyle(
                        color: AppColors.muted(context),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      final author = comment.author;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.brand(context).withValues(
                              alpha: 0.12,
                            ),
                            backgroundImage:
                                (author?.avatarUrl != null &&
                                    author!.avatarUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(author.avatarUrl!)
                                : null,
                            child:
                                (author?.avatarUrl == null ||
                                    author!.avatarUrl!.isEmpty)
                                ? Text(
                                    author?.initials ?? 'OB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brand(context),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cardMuted(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.line(context)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        author?.fullName ?? 'Old Boy',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: AppColors.heading(context),
                                        ),
                                      ),
                                      Text(
                                        DateFormatter.timeAgo(
                                          comment.createdAt,
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (author?.gradYear != null) ...[
                                    Text(
                                      DateFormatter.formatGradYear(
                                        author?.gradYear,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.danger(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    comment.content,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.body(context),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Comment Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border(top: BorderSide(color: AppColors.line(context))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Add a thought...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.line(context)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _handleSendComment,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
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
