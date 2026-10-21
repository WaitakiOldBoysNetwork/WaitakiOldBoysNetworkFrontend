import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/connection.dart';
import '../../services/directory_service.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _directoryService = DirectoryService();

  List<Connection> _pendingRequests = [];
  Map<String, Connection> _myConnections = {};
  bool _isLoading = true;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _directoryService.getPendingRequestsForMe(),
        _directoryService.getMyConnections(),
      ]);

      if (mounted) {
        setState(() {
          _pendingRequests = results[0] as List<Connection>;
          _myConnections = results[1] as Map<String, Connection>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResponse(
    String connectionId,
    ConnectionStatus status,
  ) async {
    setState(() => _processingIds.add(connectionId));

    try {
      await _directoryService.respondToConnectionRequest(
        connectionId: connectionId,
        status: status,
      );

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          status == ConnectionStatus.accepted
              ? 'Connection accepted!'
              : 'Request ignored.',
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update request: $e');
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(connectionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Network',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.navyPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.navyPrimary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Invitations'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.crimson,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Connections'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.navyPrimary,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [_buildPendingTab(), _buildConnectionsTab()],
                ),
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No pending connection requests',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.navyPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final conn = _pendingRequests[index];
          final requester = conn.requester;
          final isProcessing = _processingIds.contains(conn.id);

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.navyPrimary.withValues(
                      alpha: 0.08,
                    ),
                    backgroundImage:
                        (requester?.avatarUrl != null &&
                            requester!.avatarUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(requester.avatarUrl!)
                        : null,
                    child:
                        (requester?.avatarUrl == null ||
                            requester!.avatarUrl!.isEmpty)
                        ? Text(
                            requester?.initials ?? 'OB',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyPrimary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requester?.fullName ?? 'Old Boy Member',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyDark,
                          ),
                        ),
                        if (requester?.gradYear != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            DateFormatter.formatGradYear(requester?.gradYear),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.goldDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (requester?.headline != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            requester!.headline!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _handleResponse(
                                      conn.id,
                                      ConnectionStatus.accepted,
                                    ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: isProcessing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Accept'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _handleResponse(
                                      conn.id,
                                      ConnectionStatus.rejected,
                                    ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Ignore'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionsTab() {
    final acceptedList = _myConnections.values
        .where((c) => c.status == ConnectionStatus.accepted)
        .toList();

    if (acceptedList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.handshake_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No active connections yet.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Explore the Directory to connect with Old Boys!',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: acceptedList.length,
      itemBuilder: (context, index) {
        final conn = acceptedList[index];
        final otherProfile = conn.requester ?? conn.recipient;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.navyPrimary.withValues(
                    alpha: 0.08,
                  ),
                  backgroundImage:
                      (otherProfile?.avatarUrl != null &&
                          otherProfile!.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(otherProfile.avatarUrl!)
                      : null,
                  child:
                      (otherProfile?.avatarUrl == null ||
                          otherProfile!.avatarUrl!.isEmpty)
                      ? Text(
                          otherProfile?.initials ?? 'OB',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherProfile?.fullName ?? 'Connected Old Boy',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyDark,
                        ),
                      ),
                      if (otherProfile?.headline != null)
                        Text(
                          otherProfile!.headline!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
