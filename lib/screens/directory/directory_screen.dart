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
  int? _selectedGradYear;
  Timer? _debounce;

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
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadDirectory();
    });
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
        // Refresh connection status
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
    final currentUserId = SupabaseService.currentUserId;

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
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              // Search & Filter Box
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: AppColors.surface,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by name, profession, or company...',
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
                    const SizedBox(height: 10),
                    // Quick Year Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All Years', null),
                          _buildFilterChip('2024', 2024),
                          _buildFilterChip('2023', 2023),
                          _buildFilterChip('2020', 2020),
                          _buildFilterChip('2015', 2015),
                          _buildFilterChip('2010', 2010),
                          _buildFilterChip('2005', 2005),
                          _buildFilterChip('2000', 2000),
                          _buildFilterChip('1990', 1990),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Old Boys List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDirectory,
                  color: AppColors.navyPrimary,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.navyPrimary,
                          ),
                        )
                      : _errorMessage != null
                      ? Center(
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
                        )
                      : _oldBoys.isEmpty
                      ? Center(
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
                                  _searchController.text.isNotEmpty ||
                                          _selectedGradYear != null
                                      ? 'No Old Boys found matching your search.'
                                      : 'No registered Old Boys yet.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_searchController.text.isEmpty &&
                                    _selectedGradYear == null) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'As Old Boys create accounts on the network, they will appear here.',
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
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _oldBoys.length,
                          itemBuilder: (context, index) {
                            final profile = _oldBoys[index];
                            final profileKey = profile.userId ?? profile.id;
                            final isSelf =
                                profileKey == currentUserId ||
                                profile.id == currentUserId;
                            final conn =
                                _myConnections[profileKey] ??
                                _myConnections[profile.id];
                            final status =
                                conn?.status ?? ConnectionStatus.none;

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
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int? year) {
    final isSelected = _selectedGradYear == year;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedGradYear = selected ? year : null;
          });
          _loadDirectory();
        },
        selectedColor: AppColors.navyPrimary.withValues(alpha: 0.12),
        checkmarkColor: AppColors.navyPrimary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.navyPrimary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.navyPrimary : AppColors.border,
          ),
        ),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
