import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/constants/app_colors.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/directory_service.dart';
import '../services/profile_service.dart';
import 'directory/directory_screen.dart';
import 'feed/feed_screen.dart';
import 'feed/widgets/create_post_dialog.dart';
import 'network/connections_screen.dart';
import 'profile/profile_screen.dart';

class HomeNavigationScreen extends StatefulWidget {
  const HomeNavigationScreen({super.key});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;
  int _pendingCount = 0;
  bool _isCollapsed = false;
  Profile? _currentProfile;

  final _directoryService = DirectoryService();
  final _profileService = ProfileService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkPendingRequests();
    _loadProfile();
  }

  Future<void> _checkPendingRequests() async {
    try {
      final pending = await _directoryService.getPendingRequestsForMe();
      if (mounted) {
        setState(() {
          _pendingCount = pending.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();
      if (mounted && profile != null) {
        setState(() => _currentProfile = profile);
      }
    } catch (_) {}
  }

  void _navigateToIndex(int index) {
    setState(() => _currentIndex = index);
    if (index == 2) {
      _checkPendingRequests();
    }
    if (index == 3) {
      _loadProfile();
    }
  }

  Future<void> _openCreatePost() async {
    final created = await CreatePostDialog.show(context);
    if (created == true) {
      _navigateToIndex(0);
    }
  }

  Future<void> _confirmSignOut() async {
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
                color: AppColors.crimson.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.crimson,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of the Waitaki Old Boys Network?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
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
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isAutoCompact = screenWidth < 768;
    final isCompact = isAutoCompact || _isCollapsed;

    final screens = [
      FeedScreen(
        onNavigateToProfile: () => _navigateToIndex(3),
        onNavigateToDirectory: () => _navigateToIndex(1),
        onNavigateToNetwork: () => _navigateToIndex(2),
      ),
      const DirectoryScreen(),
      const ConnectionsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 1. Clean Left Sidebar
          _buildSidebar(isCompact, isAutoCompact),

          // 2. Main View
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isCompact, bool isAutoCompact) {
    final sidebarWidth = isCompact ? 76.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyPrimary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Branding: "Waitaki Old Boys Network"
          _buildTopBranding(isCompact, isAutoCompact),

          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // 2. Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(
                  index: 0,
                  title: 'Feed',
                  icon: Icons.feed_outlined,
                  activeIcon: Icons.feed_rounded,
                  isCompact: isCompact,
                ),
                _buildNavItem(
                  index: 1,
                  title: 'Directory',
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_alt_rounded,
                  isCompact: isCompact,
                ),
                _buildNavItem(
                  index: 2,
                  title: 'My Network',
                  icon: Icons.handshake_outlined,
                  activeIcon: Icons.handshake_rounded,
                  badgeCount: _pendingCount,
                  isCompact: isCompact,
                ),
                _buildNavItem(
                  index: 3,
                  title: 'My Profile',
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  isCompact: isCompact,
                ),

                const SizedBox(height: 16),

                // 3. Quick Action: Share Post
                if (!isCompact)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ElevatedButton.icon(
                      onPressed: _openCreatePost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 19,
                        color: AppColors.goldAccent,
                      ),
                      label: const Text(
                        'Share Post',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Tooltip(
                      message: 'Share Post',
                      child: IconButton.filled(
                        onPressed: _openCreatePost,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.navyPrimary,
                          foregroundColor: AppColors.goldAccent,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. User Profile Footer
          _buildUserFooter(isCompact),
        ],
      ),
    );
  }

  Widget _buildTopBranding(bool isCompact, bool isAutoCompact) {
    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Tooltip(
              message: 'Waitaki Old Boys Network',
              child: InkWell(
                onTap: () => _navigateToIndex(0),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navyDark, AppColors.navyPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navyPrimary.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.school_rounded,
                      color: AppColors.goldAccent,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            if (!isAutoCompact) ...[
              const SizedBox(height: 6),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Expand sidebar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => setState(() => _isCollapsed = false),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 16),
      child: Row(
        children: [
          // WBHS Crest Logo Container
          InkWell(
            onTap: () => _navigateToIndex(0),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navyDark, AppColors.navyPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navyPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.school_rounded,
                  color: AppColors.goldAccent,
                  size: 23,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Brand Title: "Waitaki Old Boys Network"
          Expanded(
            child: InkWell(
              onTap: () => _navigateToIndex(0),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Waitaki Old Boys',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyDark,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: const [
                      Text(
                        'Network',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '• Est. 1883',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Collapse Toggle Button
          if (!isAutoCompact)
            IconButton(
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              tooltip: 'Collapse sidebar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => setState(() => _isCollapsed = true),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
    required IconData activeIcon,
    required bool isCompact,
    int? badgeCount,
  }) {
    final isSelected = _currentIndex == index;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.navyPrimary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment:
            isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Badge(
            isLabelVisible: (badgeCount ?? 0) > 0,
            label: Text('$badgeCount'),
            backgroundColor: AppColors.crimson,
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.navyPrimary : AppColors.textSecondary,
              size: 21,
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.navyDark : AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if ((badgeCount ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.crimson,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: isCompact
          ? Tooltip(
              message: title,
              child: InkWell(
                onTap: () => _navigateToIndex(index),
                borderRadius: BorderRadius.circular(10),
                child: content,
              ),
            )
          : InkWell(
              onTap: () => _navigateToIndex(index),
              borderRadius: BorderRadius.circular(10),
              child: content,
            ),
    );
  }

  Widget _buildUserFooter(bool isCompact) {
    final profile = _currentProfile;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: isCompact
          ? Center(
              child: Tooltip(
                message: profile?.fullName ?? 'My Profile',
                child: InkWell(
                  onTap: () => _navigateToIndex(3),
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 17,
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
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyPrimary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            )
          : Row(
              children: [
                InkWell(
                  onTap: () => _navigateToIndex(3),
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 18,
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
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _navigateToIndex(3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile?.fullName ?? 'Waitakian Old Boy',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile?.gradYear != null
                              ? 'Class of ${profile!.gradYear}'
                              : 'Alumni Network',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account Menu',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 19,
                    color: AppColors.textMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  offset: const Offset(0, -96),
                  onSelected: (val) {
                    if (val == 'profile') {
                      _navigateToIndex(3);
                    } else if (val == 'signout') {
                      _confirmSignOut();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem<String>(
                      value: 'profile',
                      height: 38,
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 17,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 10),
                          Text('My Profile', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem<String>(
                      value: 'signout',
                      height: 38,
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 17,
                            color: AppColors.crimson,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.crimson,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
