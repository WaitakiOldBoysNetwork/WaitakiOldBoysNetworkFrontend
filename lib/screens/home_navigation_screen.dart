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
