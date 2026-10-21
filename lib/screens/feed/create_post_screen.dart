import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/profile.dart';
import '../../services/feed_service.dart';
import '../../services/profile_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
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
      setState(() {
        _currentProfile = p;
      });
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _handlePublish,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.navyPrimary.withValues(
                              alpha: 0.1,
                            ),
                            backgroundImage:
                                (_currentProfile?.avatarUrl != null &&
                                    _currentProfile!.avatarUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(
                                    _currentProfile!.avatarUrl!,
                                  )
                                : null,
                            child:
                                (_currentProfile?.avatarUrl == null ||
                                    _currentProfile!.avatarUrl!.isEmpty)
                                ? Text(
                                    _currentProfile?.initials ?? 'OB',
                                    style: const TextStyle(
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
                                _currentProfile?.fullName ?? 'Old Boy',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.navyDark,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.public,
                                    size: 13,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Shared to Waitaki Alumni Network',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Text Field
                      TextField(
                        controller: _contentController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'Share an update, reunion news, or career milestone...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          fillColor: Colors.transparent,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected Image Preview
                      if (_selectedImageBytes != null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _selectedImageBytes!,
                                width: double.infinity,
                                height: 260,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImageExt = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Media Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _pickImage,
                      icon: const Icon(
                        Icons.image_outlined,
                        color: AppColors.navyPrimary,
                      ),
                      tooltip: 'Attach Image',
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedImageBytes != null
                          ? '1 Image attached'
                          : 'Add photos or documents to your post',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
