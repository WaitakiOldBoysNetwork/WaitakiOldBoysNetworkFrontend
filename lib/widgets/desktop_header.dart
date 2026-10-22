import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/constants/app_colors.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';

class DesktopHeader extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final int pendingRequestsCount;
  final Profile? currentProfile;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onOpenCreatePost;
  final VoidCallback? onProfileUpdated;

  const DesktopHeader({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.pendingRequestsCount = 0,
    this.currentProfile,
    this.onSearch,
    this.onOpenCreatePost,
    this.onProfileUpdated,
  });

  @override
  State<DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends State<DesktopHeader> {
  final _searchController = TextEditingController();
  final _authService = AuthService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      widget.onSearch?.call(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.currentProfile;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                // 1. WBHS Brand Logo & Name
                InkWell(
                  onTap: () => widget.onNavigate(0),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.navyDark, AppColors.navyPrimary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navyPrimary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.school_rounded,
                              color: AppColors.goldAccent,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Waitaki Old Boys',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navyDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Row(
                              children: const [
                                Text(
                                  'Alumni Network',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.crimson,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '• Oamaru, NZ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // 2. Global Search Bar (Desktop)
                Expanded(
                  child: Container(
                    height: 40,
                    constraints: const BoxConstraints(maxWidth: 380),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submitSearch(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        hintText: 'Search Old Boys, years, companies...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 19,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onSearch?.call('');
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // 3. Navigation Links
                _buildNavItem(
                  index: 0,
                  label: 'Feed',
                  icon: Icons.newspaper_outlined,
                  activeIcon: Icons.newspaper,
                ),
                _buildNavItem(
                  index: 1,
                  label: 'Directory',
                  icon: Icons.people_alt_outlined,
                  activeIcon: Icons.people_alt,
                ),
                _buildNavItem(
                  index: 2,
                  label: 'My Network',
                  icon: Icons.handshake_outlined,
                  activeIcon: Icons.handshake,
                  badgeCount: widget.pendingRequestsCount,
                ),
                _buildNavItem(
                  index: 3,
                  label: 'My Profile',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                ),

                const SizedBox(width: 12),
                const SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    color: AppColors.border,
                    thickness: 1,
                  ),
                ),
                const SizedBox(width: 12),

                // 4. Quick Action "+ Share Post" Button
                ElevatedButton.icon(
                  onPressed: widget.onOpenCreatePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 17, color: AppColors.goldAccent),
                  label: const Text(
                    'Share Post',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // 5. User Profile Dropdown Menu
                PopupMenuButton<String>(
                  tooltip: 'Account Menu',
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onSelected: (val) async {
                    if (val == 'profile') {
                      widget.onNavigate(3);
                    } else if (val == 'directory') {
                      widget.onNavigate(1);
                    } else if (val == 'signout') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                            'Are you sure you want to sign out of the Waitaki Old Boys Network?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.crimson,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _authService.signOut();
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.fullName ?? 'Waitakian',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyDark,
                              fontSize: 14,
                            ),
                          ),
                          if (profile?.headline != null &&
                              profile!.headline!.isNotEmpty)
                            Text(
                              profile.headline!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const Divider(),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 18, color: AppColors.navyPrimary),
                          SizedBox(width: 10),
                          Text('My Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'directory',
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 18, color: AppColors.navyPrimary),
                          SizedBox(width: 10),
                          Text('Old Boys Directory'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'signout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 18, color: AppColors.crimson),
                          SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.crimson),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: AppColors.surfaceMuted,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
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
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            profile?.firstName ?? 'Account',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navyDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
  }) {
    final isSelected = widget.currentIndex == index;

    return InkWell(
      onTap: () => widget.onNavigate(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.navyPrimary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount'),
              backgroundColor: AppColors.crimson,
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected ? AppColors.navyPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.navyPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
