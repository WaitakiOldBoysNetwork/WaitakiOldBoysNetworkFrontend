import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../services/directory_service.dart';
import 'directory/directory_screen.dart';
import 'feed/feed_screen.dart';
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
  final _directoryService = DirectoryService();

  @override
  void initState() {
    super.initState();
    _checkPendingRequests();
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

  void _navigateToIndex(int index) {
    setState(() => _currentIndex = index);
    if (index == 2) {
      _checkPendingRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      FeedScreen(onNavigateToProfile: () => _navigateToIndex(3)),
      const DirectoryScreen(),
      const ConnectionsScreen(),
      const ProfileScreen(),
    ];

    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // Side NavigationRail for Desktop / Web
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _navigateToIndex,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.navyPrimary.withValues(alpha: 0.12),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navyPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: AppColors.goldAccent,
                    size: 26,
                  ),
                ),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.feed_outlined),
                  selectedIcon: Icon(Icons.feed, color: AppColors.navyPrimary),
                  label: Text('Feed'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(
                    Icons.people,
                    color: AppColors.navyPrimary,
                  ),
                  label: Text('Directory'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: _pendingCount > 0,
                    label: Text('$_pendingCount'),
                    backgroundColor: AppColors.crimson,
                    child: const Icon(Icons.handshake_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _pendingCount > 0,
                    label: Text('$_pendingCount'),
                    backgroundColor: AppColors.crimson,
                    child: const Icon(
                      Icons.handshake,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                  label: const Text('Network'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(
                    Icons.person,
                    color: AppColors.navyPrimary,
                  ),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: screens),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet Bottom NavigationBar
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToIndex,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.feed_outlined),
            selectedIcon: Icon(Icons.feed, color: AppColors.navyPrimary),
            label: 'Feed',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.navyPrimary),
            label: 'Directory',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _pendingCount > 0,
              label: Text('$_pendingCount'),
              backgroundColor: AppColors.crimson,
              child: const Icon(Icons.handshake_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _pendingCount > 0,
              label: Text('$_pendingCount'),
              backgroundColor: AppColors.crimson,
              child: const Icon(Icons.handshake, color: AppColors.navyPrimary),
            ),
            label: 'Network',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.navyPrimary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
