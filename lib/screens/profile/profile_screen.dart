import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/connection.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/directory_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final Profile? initialProfile;

  const ProfileScreen({super.key, this.userId, this.initialProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();
  final _directoryService = DirectoryService();
  final _picker = ImagePicker();

  Profile? _profile;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;
  bool _isConnecting = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.none;

  bool get _isSelf {
    final currentUserId = SupabaseService.currentUserId;
    if (widget.userId == null && widget.initialProfile == null) return true;
    final targetId = widget.userId ?? widget.initialProfile?.userId ?? widget.initialProfile?.id;
    return targetId != null && targetId == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _isLoading = false;
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final targetId = widget.userId ?? widget.initialProfile?.userId ?? widget.initialProfile?.id;

    if (_isSelf || targetId == null) {
      try {
        final p = await _profileService.getCurrentProfile();
        if (mounted) {
          setState(() {
            _profile = p ?? _profile;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      try {
        final results = await Future.wait([
          _profileService.getProfileById(targetId),
          _directoryService.getMyConnections(),
        ]);

        final fetchedProfile = results[0] as Profile?;
        final conns = results[1] as Map<String, Connection>;

        if (mounted) {
          setState(() {
            if (fetchedProfile != null) {
              _profile = fetchedProfile;
            }
            final key = _profile?.userId ?? _profile?.id ?? targetId;
            final conn = conns[key] ?? conns[_profile?.id];
            _connectionStatus = conn?.status ?? ConnectionStatus.none;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleConnect() async {
    final target = _profile;
    if (target == null) return;
    final targetId = target.userId ?? target.id;

    setState(() => _isConnecting = true);
    try {
      await _directoryService.sendConnectionRequest(targetId);
      if (mounted) {
        setState(() {
          _connectionStatus = ConnectionStatus.pending;
        });
        SnackbarHelper.showSuccess(
          context,
          'Connection request sent to ${target.fullName}!',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to connect: $e');
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingAvatar = true);

      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';

      final publicUrl = await _profileService.uploadAvatar(bytes, ext);

      if (mounted) {
        setState(() {
          if (_profile != null) {
            _profile = _profile!.copyWith(avatarUrl: publicUrl);
          }
        });
        SnackbarHelper.showSuccess(context, 'Avatar updated!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to upload avatar: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickAndUploadBanner() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingBanner = true);

      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';

      final publicUrl = await _profileService.uploadBanner(bytes, ext);

      if (mounted) {
        setState(() {
          if (_profile != null) {
            _profile = _profile!.copyWith(bannerUrl: publicUrl);
          }
        });
        SnackbarHelper.showSuccess(context, 'Banner updated!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to upload banner: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  Future<void> _handleRemoveBanner() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Banner'),
        content: const Text(
          'Reset your banner back to the default Waitaki Boys\' heritage theme?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploadingBanner = true);
    try {
      await _profileService.removeBanner();
      if (mounted) {
        setState(() {
          if (_profile != null) {
            _profile = _profile!.copyWith(bannerUrl: '');
          }
        });
        SnackbarHelper.showSuccess(context, 'Banner reset to default theme');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to remove banner: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  void _showBannerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.navyPrimary,
              ),
              title: const Text('Upload new banner photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadBanner();
              },
            ),
            if (_profile?.bannerUrl != null && _profile!.bannerUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.crimson,
                ),
                title: const Text(
                  'Remove banner photo',
                  style: TextStyle(color: AppColors.crimson),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleRemoveBanner();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.navyPrimary),
        ),
      );
    }

    final profile = _profile;
    final isSelf = _isSelf;
    final canGoBack = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          isSelf ? 'My Profile' : (profile?.fullName ?? 'Old Boy Profile'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (isSelf)
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign Out',
              onPressed: _handleSignOut,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Banner & Avatar Card
                Card(
                  margin: const EdgeInsets.all(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Navy & Gold / Custom Photo Banner
                      Container(
                        height: 145,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.navyDark, AppColors.navyPrimary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Custom Banner Image if set
                            if (profile?.bannerUrl != null &&
                                profile!.bannerUrl!.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: profile.bannerUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.navyDark,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.navyDark,
                                        AppColors.navyPrimary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),

                            // Vignette overlay for contrast and depth
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.25),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),

                            // Waitaki Crest Watermark
                            if (profile?.bannerUrl == null ||
                                profile!.bannerUrl!.isEmpty)
                              Positioned(
                                right: 20,
                                top: 20,
                                child: Icon(
                                  Icons.school,
                                  size: 80,
                                  color: AppColors.goldAccent.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),

                            // Edit Banner Button (for profile owner)
                            if (isSelf)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isUploadingBanner
                                        ? null
                                        : _showBannerOptions,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isUploadingBanner)
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          else
                                            const Icon(
                                              Icons.camera_alt_outlined,
                                              size: 15,
                                              color: Colors.white,
                                            ),
                                          const SizedBox(width: 6),
                                          Text(
                                            (profile?.bannerUrl != null &&
                                                    profile!.bannerUrl!.isNotEmpty)
                                                ? 'Edit Banner'
                                                : 'Add Banner',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Avatar & Details
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -45),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Avatar
                                  Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.surface,
                                            width: 4,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 46,
                                          backgroundColor: AppColors.navyPrimary
                                              .withValues(alpha: 0.1),
                                          backgroundImage:
                                              (profile?.avatarUrl != null &&
                                                  profile!
                                                      .avatarUrl!
                                                      .isNotEmpty)
                                              ? CachedNetworkImageProvider(
                                                  profile.avatarUrl!,
                                                )
                                              : null,
                                          child:
                                              (profile?.avatarUrl == null ||
                                                  profile!.avatarUrl!.isEmpty)
                                              ? Text(
                                                  profile?.initials ?? 'OB',
                                                  style: const TextStyle(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.navyPrimary,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                      if (isSelf)
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: _isUploadingAvatar
                                                ? null
                                                : _pickAndUploadAvatar,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(
                                                color: AppColors.navyPrimary,
                                                shape: BoxShape.circle,
                                              ),
                                              child: _isUploadingAvatar
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.camera_alt,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  // Action Button (Edit or Connect)
                                  if (isSelf)
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        if (profile != null) {
                                          final updated = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditProfileScreen(
                                                profile: profile,
                                              ),
                                            ),
                                          );
                                          if (updated == true) {
                                            _loadProfile();
                                          }
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Edit Profile'),
                                    )
                                  else
                                    _buildOtherUserActionButton(),
                                ],
                              ),
                            ),

                            // Name & Badges
                            Transform.translate(
                              offset: const Offset(0, -25),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          profile?.fullName ?? 'Old Boy',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.navyDark,
                                          ),
                                        ),
                                      ),
                                      if (profile?.gradYear != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.goldAccent
                                                .withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppColors.goldAccent
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Text(
                                            DateFormatter.formatGradYear(
                                              profile?.gradYear,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.goldDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (profile?.headline != null &&
                                      profile!.headline!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      profile.headline!,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        color: AppColors.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  if (profile?.city != null &&
                                      profile!.city!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          profile.city!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // About / Bio Card
                if (profile?.bio != null && profile!.bio!.trim().isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.person_outline,
                                    color: AppColors.navyPrimary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'About',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.navyDark,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelf)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  tooltip: 'Edit Bio',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    final updated = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditProfileScreen(
                                          profile: profile,
                                        ),
                                      ),
                                    );
                                    if (updated == true) _loadProfile();
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.bio!,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: AppColors.navyDark,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isSelf)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: InkWell(
                      onTap: () async {
                        if (profile != null) {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(profile: profile),
                            ),
                          );
                          if (updated == true) _loadProfile();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.navyPrimary.withValues(
                                  alpha: 0.08,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                color: AppColors.navyPrimary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Add a bio to your profile',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.navyDark,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Share your story, memories from WBHS, or what you\'re up to today.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Details & School Info Card
                if (profile != null) _buildProfileDetailsCard(profile),

                // Waitaki Heritage & Association Info Card
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.verified,
                              color: AppColors.goldAccent,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Waitaki Old Boys\' Association',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navyDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Waitaki Boys\' High School (Oamaru, New Zealand) was established in 1883. '
                          'As an Old Boy, you are connected to a worldwide fellowship of leaders, athletes, academics, and innovators.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.navyPrimary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Motto: Qaunti Est Sapere',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navyPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailsCard(Profile p) {
    final items = <Widget>[];

    if (p.house != null && p.house!.trim().isNotEmpty) {
      items.add(_buildInfoRow(Icons.shield_outlined, 'House', p.house!));
    }
    if (p.industry != null && p.industry!.trim().isNotEmpty) {
      items.add(_buildInfoRow(Icons.business_center_outlined, 'Industry', p.industry!));
    }
    if (p.company != null && p.company!.trim().isNotEmpty) {
      items.add(_buildInfoRow(Icons.apartment_outlined, 'Company', p.company!));
    }
    if (p.openToHelping != null && p.openToHelping!.trim().isNotEmpty && p.openToHelping != 'unchecked') {
      items.add(_buildInfoRow(Icons.volunteer_activism_outlined, 'Mentoring & Support', 'Open to helping fellow Old Boys'));
    }
    if (p.lookingFor != null && p.lookingFor!.trim().isNotEmpty) {
      items.add(_buildInfoRow(Icons.search_outlined, 'Looking For', p.lookingFor!));
    }
    if (p.email != null && p.email!.trim().isNotEmpty) {
      items.add(_buildInfoRow(Icons.email_outlined, 'Email', p.email!));
    }
    if (p.phone != null && p.phone!.trim().isNotEmpty) {
      items.add(_buildInfoRow(Icons.phone_outlined, 'Phone', p.phone!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.navyPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navyDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherUserActionButton() {
    switch (_connectionStatus) {
      case ConnectionStatus.accepted:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check, size: 16, color: AppColors.success),
              SizedBox(width: 6),
              Text(
                'Connected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.access_time_rounded, size: 16, color: AppColors.warning),
              SizedBox(width: 6),
              Text(
                'Request Pending',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.rejected:
      case ConnectionStatus.none:
        return ElevatedButton.icon(
          onPressed: _isConnecting ? null : _handleConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navyPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: _isConnecting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add_alt_1_rounded, size: 16),
          label: const Text('Connect'),
        );
    }
  }
}
