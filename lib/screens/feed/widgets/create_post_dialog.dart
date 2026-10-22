import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/profile.dart';
import '../../../services/feed_service.dart';
import '../../../services/profile_service.dart';

class CreatePostDialog extends StatefulWidget {
  const CreatePostDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CreatePostDialog(),
    );
  }

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _feedService = FeedService();
  final _profileService = ProfileService();
  final _contentController = TextEditingController();
  final _picker = ImagePicker();

  Profile? _currentProfile;
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await _profileService.getCurrentProfile();
    if (mounted) {
      setState(() => _currentProfile = p);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final name = file.name;
        final ext = name.contains('.') ? name.split('.').last : 'jpg';

        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageExt = ext;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _handlePublish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImageBytes == null) {
      SnackbarHelper.showError(context, 'Please add some text or an image');
      return;
    }

    setState(() => _isPosting = true);

    try {
      await _feedService.createPost(
        content: content,
        imageBytes: _selectedImageBytes,
        imageExt: _selectedImageExt,
      );

      if (mounted) {
        Navigator.pop(context, true);
        SnackbarHelper.showSuccess(
          context,
          'Post shared with Old Boys network!',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to publish post: $e');
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _currentProfile;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.navyPrimary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Share with Old Boys Network',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context, false),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(height: 24),

            // Author Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.1),
                  backgroundImage: (profile?.avatarUrl != null &&
                          profile!.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(profile.avatarUrl!)
                      : null,
                  child: (profile?.avatarUrl == null ||
                          profile!.avatarUrl!.isEmpty)
                      ? Text(
                          profile?.initials ?? 'OB',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.fullName ?? 'Waitakian',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.public,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Visible to all Old Boys',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content Editor
            TextField(
              controller: _contentController,
              maxLines: 6,
              minLines: 4,
              autofocus: true,
              style: const TextStyle(fontSize: 15, height: 1.5),
              decoration: const InputDecoration(
                hintText:
                    'What would you like to share? (e.g. career news, milestone, school memories, or upcoming get-togethers)...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),

            // Image Preview if picked
            if (_selectedImageBytes != null) ...[
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      width: double.infinity,
                      child: Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black.withValues(alpha: 0.65),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedImageBytes = null;
                            _selectedImageExt = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Bottom Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Add Photo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    _contentController.text += ' #Reunion2026';
                  },
                  icon: const Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: AppColors.goldDark,
                  ),
                  label: const Text(
                    'Reunion',
                    style: TextStyle(color: AppColors.goldDark),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isPosting ? null : _handlePublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Publish Post',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
