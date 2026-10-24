import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/connection.dart';
import '../../models/profile.dart';
import '../../services/directory_service.dart';
import '../../services/supabase_service.dart';
import '../profile/profile_screen.dart';
import 'widgets/old_boy_card.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _directoryService = DirectoryService();
  final _searchController = TextEditingController();

  List<Profile> _oldBoys = [];
  Map<String, Connection> _myConnections = {};
  final Set<String> _connectingIds = {};

  bool _isLoading = true;
  String? _errorMessage;

  // Active filters
  String? _selectedHouse;
  int? _selectedGradYear;
  int? _selectedAge;

  Timer? _debounce;

  static final int _currentYear = DateTime.now().year;
  static final List<int> _gradYears = List.generate(
    _currentYear - 1960 + 1,
    (index) => _currentYear - index,
  );
  static final List<int> _ages = List.generate(
    100 - 13 + 1,
    (index) => 13 + index,
  );

  static const List<String> _wbhsHouses = [
    'Don',
    'Founders',
    'Forrester',
    'Lee',
    'Harkness',
    'Milner',
    'Sutherland',
  ];

  bool get _hasActiveFilters =>
      _selectedHouse != null ||
      _selectedGradYear != null ||
      _selectedAge != null ||
      _searchController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadDirectory();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedHouse = null;
      _selectedGradYear = null;
      _selectedAge = null;
      _searchController.clear();
    });
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _directoryService.searchOldBoys(
          query: _searchController.text.trim(),
          gradYear: _selectedGradYear,
          house: _selectedHouse,
          age: _selectedAge,
        ),
        _directoryService.getMyConnections(),
      ]);

      if (mounted) {
        setState(() {
          _oldBoys = results[0] as List<Profile>;
          _myConnections = results[1] as Map<String, Connection>;
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
        final updatedConns = await _directoryService.getMyConnections();
        setState(() {
          _myConnections = updatedConns;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to send request: $e');
      }
    } finally {
      if (mounted) setState(() => _connectingIds.remove(targetId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Old Boys Directory',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Search & Filter Box
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Search Bar (Live Debounced Search Querying Member Names)
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search member names...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadDirectory();
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Row Directly Below Search
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // House Filter Dropdown
                          _buildHouseFilterChip(),
                          const SizedBox(width: 8),

                          // Graduation Year Filter Dropdown
                          _buildGradYearFilterChip(),
                          const SizedBox(width: 8),

                          // Age Filter Dropdown
                          _buildAgeFilterChip(),

                          // Clear Filters Button (When any filter is active)
                          if (_hasActiveFilters) ...[
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _clearFilters,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.crimson.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.crimson.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_off_outlined,
                                      size: 15,
                                      color: AppColors.crimson,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Clear Filters',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.crimson,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Results Grid / List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDirectory,
                  color: AppColors.navyPrimary,
                  child: _buildResultsView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.navyPrimary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.crimson,
              ),
              const SizedBox(height: 12),
              Text('Error: $_errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDirectory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_oldBoys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              Text(
                _hasActiveFilters
                    ? 'No Old Boys found matching your search and filter criteria.'
                    : 'No registered Old Boys yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear active filters'),
                ),
              ] else ...[
                const SizedBox(height: 6),
                const Text(
                  'As Old Boys join the network, they will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final currentUserId = SupabaseService.currentUserId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        if (isWide) {
          // Responsive 2-column Results Grid
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _oldBoys.length,
            itemBuilder: (context, index) => _buildCard(index, currentUserId),
          );
        }

        // Single Column Results List on narrow mobile screens
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _oldBoys.length,
          itemBuilder: (context, index) => _buildCard(index, currentUserId),
        );
      },
    );
  }

  Widget _buildCard(int index, String? currentUserId) {
    final profile = _oldBoys[index];
    final profileKey = profile.userId ?? profile.id;
    final isSelf = profileKey == currentUserId || profile.id == currentUserId;
    final conn = _myConnections[profileKey] ?? _myConnections[profile.id];
    final status = conn?.status ?? ConnectionStatus.none;

    return OldBoyCard(
      profile: profile,
      connectionStatus: status,
      isSelf: isSelf,
      isConnecting: _connectingIds.contains(profileKey),
      onConnectPressed: () => _handleConnect(profile),
      onTapProfile: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              userId: profile.userId ?? profile.id,
              initialProfile: profile,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHouseFilterChip() {
    final hasSelection = _selectedHouse != null;
    return PopupMenuButton<String?>(
      tooltip: 'Filter by House',
      onSelected: (val) {
        setState(() {
          _selectedHouse = val;
        });
        _loadDirectory();
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text('All Houses', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const PopupMenuDivider(),
        ..._wbhsHouses.map(
          (house) => PopupMenuItem<String?>(
            value: house,
            child: Text('$house House'),
          ),
        ),
      ],
      child: _buildFilterBadge(
        icon: Icons.shield_outlined,
        label: _selectedHouse != null ? '$_selectedHouse House' : 'House',
        isActive: hasSelection,
      ),
    );
  }

  Widget _buildGradYearFilterChip() {
    final hasSelection = _selectedGradYear != null;
    return PopupMenuButton<int?>(
      tooltip: 'Filter by Graduation Year',
      onSelected: (val) {
        setState(() {
          _selectedGradYear = val;
        });
        _loadDirectory();
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem<int?>(
          value: null,
          child: Text('All Years', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const PopupMenuDivider(),
        ..._gradYears.take(45).map(
          (year) => PopupMenuItem<int?>(
            value: year,
            child: Text('Class of $year'),
          ),
        ),
      ],
      child: _buildFilterBadge(
        icon: Icons.school_outlined,
        label: _selectedGradYear != null ? 'Class of $_selectedGradYear' : 'Grad Year',
        isActive: hasSelection,
      ),
    );
  }

  Widget _buildAgeFilterChip() {
    final hasSelection = _selectedAge != null;
    return PopupMenuButton<int?>(
      tooltip: 'Filter by Age',
      onSelected: (val) {
        setState(() {
          _selectedAge = val;
        });
        _loadDirectory();
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem<int?>(
          value: null,
          child: Text('All Ages', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const PopupMenuDivider(),
        ..._ages.map(
          (age) => PopupMenuItem<int?>(
            value: age,
            child: Text('$age years old'),
          ),
        ),
      ],
      child: _buildFilterBadge(
        icon: Icons.cake_outlined,
        label: _selectedAge != null ? 'Age: $_selectedAge' : 'Age',
        isActive: hasSelection,
      ),
    );
  }

  Widget _buildFilterBadge({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.navyPrimary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.navyPrimary : AppColors.border,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isActive ? AppColors.navyPrimary : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppColors.navyPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: isActive ? AppColors.navyPrimary : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
