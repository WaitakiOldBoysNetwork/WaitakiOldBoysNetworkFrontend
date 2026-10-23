import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/connection.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../services/directory_service.dart';
import '../../services/feed_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../profile/profile_screen.dart';
import 'widgets/create_post_dialog.dart';
import 'widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToDirectory;
  final VoidCallback? onNavigateToNetwork;

  const FeedScreen({
    super.key,
    this.onNavigateToProfile,
    this.onNavigateToDirectory,
    this.onNavigateToNetwork,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _feedService = FeedService();
  final _profileService = ProfileService();
  final _directoryService = DirectoryService();

  List<Post> _posts = [];
  Profile? _currentProfile;
  List<Profile> _suggestedOldBoys = [];
  Map<String, Connection> _myConnections = {};
  final Set<String> _connectingIds = {};

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
        _directoryService.searchOldBoys(limit: 12),
        _directoryService.getMyConnections(),
      ]);

      if (mounted) {
        final allProfiles = results[2] as List<Profile>;
        final conns = results[3] as Map<String, Connection>;
        final curId = SupabaseService.currentUserId;

        // Filter suggestions to old boys not yet connected and not self
        final suggestions = allProfiles.where((p) {
          final id = p.userId ?? p.id;
          if (id == curId || p.id == curId) return false;
          final conn = conns[id] ?? conns[p.id];
          return conn == null || conn.status == ConnectionStatus.none;
        }).take(4).toList();

        setState(() {
          _posts = results[0] as List<Post>;
          _currentProfile = results[1] as Profile?;
          _suggestedOldBoys = suggestions;
          _myConnections = conns;
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
    final created = await CreatePostDialog.show(context);
    if (created == true) {
      _loadData();
    }
  }

  Future<void> _handleConnect(Profile profile) async {
    final targetId = profile.userId ?? profile.id;
    setState(() => _connectingIds.add(targetId));

    try {
      await _directoryService.sendConnectionRequest(targetId);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Connection request sent to ${profile.fullName}!',
        );
        final conns = await _directoryService.getMyConnections();
        setState(() {
          _myConnections = conns;
          _suggestedOldBoys.removeWhere((p) => (p.userId ?? p.id) == targetId);
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to connect: $e');
      }
    } finally {
      if (mounted) setState(() => _connectingIds.remove(targetId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          final showRight = constraints.maxWidth >= 700;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.navyPrimary,
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                              color: AppColors.navyPrimary),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildErrorView()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Left Column (Desktop Profile & Heritage)
                                if (isWide) ...[
                                  SizedBox(
                                    width: 250,
                                    child: Column(
                                      children: [
                                        _buildLeftProfileCard(),
                                        const SizedBox(height: 16),
                                        _buildHeritageLinksCard(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                ],

                                // 2. Center Column (Composer & Feed Stream)
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildDesktopComposerCard(),
                                      const SizedBox(height: 16),
                                      if (_posts.isEmpty)
                                        _buildEmptyFeedCard()
                                      else
                                        ..._posts.map(
                                          (post) => PostCard(
                                            key: ValueKey(post.id),
                                            post: post,
                                            onPostUpdated: _loadData,
                                            onPostDeleted: () {
                                              setState(() {
                                                _posts.removeWhere(
                                                    (p) => p.id == post.id);
                                              });
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 3. Right Column (Desktop Recommendations & Notices)
                                if (showRight) ...[
                                  const SizedBox(width: 20),
                                  SizedBox(
                                    width: 280,
                                    child: Column(
                                      children: [
                                        _buildRightSuggestionsCard(),
                                        const SizedBox(height: 16),
                                        _buildNoticeboardCard(),
                                        const SizedBox(height: 16),
                                        _buildDesktopFooter(),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Left Column: User Profile Card
  Widget _buildLeftProfileCard() {
    final profile = _currentProfile;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Navy Banner
          Container(
            height: 68,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navyDark, AppColors.navyPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: widget.onNavigateToProfile,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 34,
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navyPrimary,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile?.fullName ?? 'Waitakian Old Boy',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  if (profile?.gradYear != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Class of ${profile!.gradYear}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ),
                  ],
                  if (profile?.headline != null &&
                      profile!.headline!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      profile.headline!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Quick stats
                  InkWell(
                    onTap: widget.onNavigateToNetwork,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'My Network',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_myConnections.length}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onNavigateToProfile,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('View Full Profile'),
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

  // Left Column: Heritage Links Card
  Widget _buildHeritageLinksCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.navyPrimary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waitaki Heritage',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Cultores Mentium • Est. 1883\nOamaru, North Otago',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _buildQuickLink(
              icon: Icons.people_outline,
              label: 'Browse Directory',
              onTap: widget.onNavigateToDirectory,
            ),
            _buildQuickLink(
              icon: Icons.history_edu,
              label: 'School Archives & Museum',
              onTap: () {
                SnackbarHelper.showSuccess(
                  context,
                  'Waitaki Archives portal coming soon!',
                );
              },
            ),
            _buildQuickLink(
              icon: Icons.event_available,
              label: 'Upcoming WBHS Reunions',
              onTap: () {
                SnackbarHelper.showSuccess(
                  context,
                  'Annual Old Boys Reunion: October 2026',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLink({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.navyPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // Center Column: Desktop Composer Card
  Widget _buildDesktopComposerCard() {
    final profile = _currentProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                Expanded(
                  child: InkWell(
                    onTap: _openCreatePost,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Share an update, news, or milestone with fellow Old Boys...',
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
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: _openCreatePost,
                    icon: const Icon(
                      Icons.image_outlined,
                      size: 19,
                      color: AppColors.navyPrimary,
                    ),
                    label: const Text(
                      'Photo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openCreatePost,
                    icon: const Icon(
                      Icons.event_note_outlined,
                      size: 19,
                      color: AppColors.goldDark,
                    ),
                    label: const Text(
                      'Reunion / Event',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openCreatePost,
                    icon: const Icon(
                      Icons.article_outlined,
                      size: 19,
                      color: AppColors.crimson,
                    ),
                    label: const Text(
                      'Achievement',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Right Column: Suggested Old Boys
  Widget _buildRightSuggestionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Old Boys to Connect With',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: widget.onNavigateToDirectory,
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_suggestedOldBoys.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'All caught up with suggestions!',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              ..._suggestedOldBoys.map(
                (p) => _buildSuggestionItem(p),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(Profile profile) {
    final targetId = profile.userId ?? profile.id;
    final isConnecting = _connectingIds.contains(targetId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: targetId,
                    initialProfile: profile,
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.08),
              backgroundImage: (profile.avatarUrl != null &&
                      profile.avatarUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(profile.avatarUrl!)
                  : null,
              child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                  ? Text(
                      profile.initials,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyPrimary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          userId: targetId,
                          initialProfile: profile,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    profile.fullName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (profile.gradYear != null)
                  Text(
                    'Class of ${profile.gradYear}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (profile.headline != null && profile.headline!.isNotEmpty)
                  Text(
                    profile.headline!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 28,
                  child: OutlinedButton.icon(
                    onPressed: isConnecting ? null : () => _handleConnect(profile),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: isConnecting
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(Icons.person_add_alt_1, size: 13),
                    label: const Text(
                      'Connect',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
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

  // Right Column: Noticeboard
  Widget _buildNoticeboardCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.campaign_rounded,
                  color: AppColors.crimson,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'WBHS Noticeboard',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildNoticeItem(
              title: '2026 Annual Oamaru Reunion',
              snippet:
                  'Join Old Boys at the Hall of Memories on 24-26 October. Registration opens next month.',
              badge: 'Featured',
            ),
            const Divider(height: 16),
            _buildNoticeItem(
              title: 'WBHS Rector\'s Term Update',
              snippet:
                  'Academic excellence, 1st XV rugby results, and heritage campus upgrades.',
              badge: 'School News',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeItem({
    required String title,
    required String snippet,
    required String badge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.navyPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.navyPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.navyDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          snippet,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  // Right Column: Desktop Footer
  Widget _buildDesktopFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Amor Patriae Nostra Lex',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.navyMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '© 2026 Waitaki Boys\' High School Old Boys\' Association. All rights reserved.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFeedCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.mark_chat_unread_outlined,
                size: 54,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Posts on the Network Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Be the first to share a post, school memory, or reunion update with fellow Old Boys!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openCreatePost,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create First Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.crimson),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Feed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
