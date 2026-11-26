import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/connection.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../models/school_notice.dart';
import '../../services/directory_service.dart';
import '../../services/feed_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../legal/legal_screens.dart';
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
  List<SchoolNotice> _notices = SchoolNotice.defaultNotices;

  bool _isLoading = true;
  bool _showAllNoticesMobile = false;
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

    _loadSchoolNotices();

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

  Future<void> _loadSchoolNotices() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final response = await SupabaseService.client
          .from('school_notices')
          .select('id, title, snippet, badge, url, image_url, published_at')
          .order('published_at', ascending: false)
          .limit(5);

      if (mounted && response.isNotEmpty) {
        setState(() {
          _notices = response
              .map<SchoolNotice>((item) => SchoolNotice.fromJson(item))
              .toList();
        });
      }
    } catch (_) {
      // Gracefully retains SchoolNotice.defaultNotices
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        SnackbarHelper.showError(context, 'Could not open link: $url');
      }
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open link: $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = Responsive.isMobileWidth(constraints.maxWidth);
          final isWide = constraints.maxWidth >= 1000;
          final showRight = constraints.maxWidth >= 700;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.brand(context),
                child: _isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                              color: AppColors.brand(context)),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildErrorView()
                        : SingleChildScrollView(
                            padding: isMobile
                                ? const EdgeInsets.fromLTRB(12, 12, 12, 88)
                                : const EdgeInsets.symmetric(
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
                                      isMobile
                                          ? _buildMobileComposerCard()
                                          : _buildDesktopComposerCard(),
                                      SizedBox(height: isMobile ? 12 : 16),
                                      if (!showRight) ...[
                                        _buildNoticeboardCard(compact: isMobile),
                                        SizedBox(height: isMobile ? 12 : 16),
                                        if (isMobile &&
                                            _suggestedOldBoys.isNotEmpty) ...[
                                          _buildMobileSuggestionsStrip(),
                                          const SizedBox(height: 12),
                                        ],
                                      ],
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
                                      if (isMobile) ...[
                                        const SizedBox(height: 12),
                                        _buildMobileFooterCard(),
                                      ],
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
                        border:
                            Border.all(color: AppColors.card(context), width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor:
                            AppColors.brand(context).withValues(alpha: 0.12),
                        backgroundImage: (profile?.avatarUrl != null &&
                                profile!.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(profile.avatarUrl!)
                            : null,
                        child: (profile?.avatarUrl == null ||
                                profile!.avatarUrl!.isEmpty)
                            ? Text(
                                profile?.initials ?? 'OB',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brand(context),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.heading(context),
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.isDark(context)
                              ? AppColors.goldAccent
                              : AppColors.goldDark,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subtext(context),
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
                          Text(
                            'My Network',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.subtext(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_myConnections.length}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand(context),
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
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.brand(context),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waitaki Heritage',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.heading(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Quanti Est Sapere • Est. 1883\nOamaru, North Otago',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.subtext(context),
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
              icon: Icons.public,
              label: 'Official WBHS Website',
              onTap: () => _openUrl('https://www.waitakibhs.school.nz'),
              isExternal: true,
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
    bool isExternal = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.brand(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.body(context),
                ),
              ),
            ),
            Icon(
              isExternal ? Icons.open_in_new : Icons.chevron_right,
              size: isExternal ? 13 : 16,
              color: AppColors.muted(context),
            ),
          ],
        ),
      ),
    );
  }

  // Center Column: Compact Mobile Composer Card
  Widget _buildMobileComposerCard() {
    final profile = _currentProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onNavigateToProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppColors.brand(context).withValues(alpha: 0.12),
                backgroundImage: (profile?.avatarUrl != null &&
                        profile!.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(profile.avatarUrl!)
                    : null,
                child: (profile?.avatarUrl == null ||
                        profile!.avatarUrl!.isEmpty)
                    ? Text(
                        profile?.initials ?? 'OB',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand(context),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _openCreatePost,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardMuted(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.line(context)),
                  ),
                  child: Text(
                    'Share an update with Old Boys...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _openCreatePost,
              tooltip: 'Share Photo',
              icon: Icon(
                Icons.image_outlined,
                color: AppColors.brand(context),
                size: 22,
              ),
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
                  backgroundColor:
                      AppColors.brand(context).withValues(alpha: 0.12),
                  backgroundImage: (profile?.avatarUrl != null &&
                          profile!.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(profile.avatarUrl!)
                      : null,
                  child: (profile?.avatarUrl == null ||
                          profile!.avatarUrl!.isEmpty)
                      ? Text(
                          profile?.initials ?? 'OB',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand(context),
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
                        color: AppColors.cardMuted(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.line(context)),
                      ),
                      child: Text(
                        'Share an update, news, or milestone with fellow Old Boys...',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.muted(context),
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
                    icon: Icon(
                      Icons.image_outlined,
                      size: 19,
                      color: AppColors.brand(context),
                    ),
                    label: const Text(
                      'Photo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openCreatePost,
                    icon: Icon(
                      Icons.event_note_outlined,
                      size: 19,
                      color: AppColors.isDark(context)
                          ? AppColors.goldAccent
                          : AppColors.goldDark,
                    ),
                    label: const Text(
                      'Reunion / Event',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openCreatePost,
                    icon: Icon(
                      Icons.article_outlined,
                      size: 19,
                      color: AppColors.danger(context),
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
                Expanded(
                  child: Text(
                    'Old Boys to Connect With',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.heading(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: widget.onNavigateToDirectory,
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_suggestedOldBoys.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'All caught up with suggestions!',
                  style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
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
              backgroundColor:
                  AppColors.brand(context).withValues(alpha: 0.12),
              backgroundImage: (profile.avatarUrl != null &&
                      profile.avatarUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(profile.avatarUrl!)
                  : null,
              child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                  ? Text(
                      profile.initials,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand(context),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (profile.gradYear != null)
                  Text(
                    'Class of ${profile.gradYear}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.isDark(context)
                          ? AppColors.goldAccent
                          : AppColors.goldDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (profile.headline != null && profile.headline!.isNotEmpty)
                  Text(
                    profile.headline!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.subtext(context),
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

  // Mobile Horizontal Suggested Old Boys Strip
  Widget _buildMobileSuggestionsStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Old Boys to Connect With',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heading(context),
                ),
              ),
              InkWell(
                onTap: widget.onNavigateToDirectory,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestedOldBoys.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final profile = _suggestedOldBoys[index];
              final targetId = profile.userId ?? profile.id;
              final isConnecting = _connectingIds.contains(targetId);

              return SizedBox(
                width: 160,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
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
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.brand(context)
                                .withValues(alpha: 0.12),
                            backgroundImage: (profile.avatarUrl != null &&
                                    profile.avatarUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(profile.avatarUrl!)
                                : null,
                            child: (profile.avatarUrl == null ||
                                    profile.avatarUrl!.isEmpty)
                                ? Text(
                                    profile.initials,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brand(context),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profile.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (profile.gradYear != null)
                            Text(
                              'Class of ${profile.gradYear}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.isDark(context)
                                    ? AppColors.goldAccent
                                    : AppColors.goldDark,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                            )
                          else if (profile.headline != null &&
                              profile.headline!.isNotEmpty)
                            Text(
                              profile.headline!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.subtext(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 28,
                            child: OutlinedButton(
                              onPressed: isConnecting
                                  ? null
                                  : () => _handleConnect(profile),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: isConnecting
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    )
                                  : const Text(
                                      'Connect',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Right Column: Noticeboard
  Widget _buildNoticeboardCard({bool compact = false}) {
    final visibleCount =
        compact && !_showAllNoticesMobile && _notices.length > 2
            ? 2
            : _notices.length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.campaign_rounded,
                  color: AppColors.danger(context),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'WBHS Noticeboard',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.heading(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _openUrl('https://hail.to/waitaki-boys-high-school'),
                  borderRadius: BorderRadius.circular(4),
                  child: Tooltip(
                    message: 'Open WBHS on Hail.to',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'hail.to',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand(context),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.open_in_new,
                            size: 11,
                            color: AppColors.brand(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < visibleCount; i++) ...[
              if (i > 0) const Divider(height: 16),
              _buildNoticeItem(
                title: _notices[i].title,
                snippet: _notices[i].snippet,
                badge: _notices[i].badge,
                url: _notices[i].url,
              ),
            ],
            if (compact && _notices.length > 2) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllNoticesMobile = !_showAllNoticesMobile;
                    });
                  },
                  icon: Icon(
                    _showAllNoticesMobile
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _showAllNoticesMobile
                        ? 'Show less'
                        : 'Show all (${_notices.length})',
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _openUrl('https://hail.to/waitaki-boys-high-school'),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.brand(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.brand(context).withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.newspaper_rounded,
                      size: 14,
                      color: AppColors.brand(context),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Browse all articles on Hail.to',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new,
                      size: 11,
                      color: AppColors.brand(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFooterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.brand(context),
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waitaki Heritage • Quanti Est Sapere',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.heading(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildQuickLink(
              icon: Icons.public,
              label: 'Official WBHS Website',
              onTap: () => _openUrl('https://www.waitakibhs.school.nz'),
              isExternal: true,
            ),
            const Divider(height: 16),
            const LegalLinksFooter(
              textAlign: TextAlign.start,
              showPrefixText: false,
            ),
            const SizedBox(height: 6),
            Text(
              '© 2026 Waitaki Boys\' High School Old Boys\' Association.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted(context),
              ),
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
    String? url,
  }) {
    return InkWell(
      onTap: url != null ? () => _openUrl(url) : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brand(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand(context),
                    ),
                  ),
                ),
                if (url != null) ...[
                  const Spacer(),
                  Icon(
                    Icons.open_in_new,
                    size: 12,
                    color: AppColors.subtext(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              snippet,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.subtext(context),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Right Column: Desktop Footer
  Widget _buildDesktopFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quanti Est Sapere',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.muted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const LegalLinksFooter(
            textAlign: TextAlign.start,
            showPrefixText: false,
          ),
          const SizedBox(height: 6),
          Text(
            '© 2026 Waitaki Boys\' High School Old Boys\' Association. All rights reserved.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.muted(context),
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
              Icon(
                Icons.mark_chat_unread_outlined,
                size: 54,
                color: AppColors.muted(context),
              ),
              const SizedBox(height: 16),
              Text(
                'No Posts on the Network Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heading(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to share a post, school memory, or reunion update with fellow Old Boys!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.subtext(context),
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
            Icon(Icons.error_outline,
                size: 48, color: AppColors.danger(context)),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Feed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtext(context)),
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
