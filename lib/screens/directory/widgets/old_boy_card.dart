import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/connection.dart';
import '../../../models/profile.dart';

class OldBoyCard extends StatelessWidget {
  final Profile profile;
  final ConnectionStatus connectionStatus;
  final bool isSelf;
  final bool isConnecting;
  final VoidCallback? onConnectPressed;
  final VoidCallback? onTapProfile;

  const OldBoyCard({
    super.key,
    required this.profile,
    required this.connectionStatus,
    this.isSelf = false,
    this.isConnecting = false,
    this.onConnectPressed,
    this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTapProfile,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    AppColors.brand(context).withValues(alpha: 0.12),
                backgroundImage:
                    (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(profile.avatarUrl!)
                    : null,
                child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                    ? Text(
                        profile.initials,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand(context),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.fullName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.gradYear != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand(context).withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              DateFormatter.shortGradYear(profile.gradYear),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brand(context),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (profile.headline != null &&
                        profile.headline!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        profile.headline!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.subtext(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (profile.bio != null &&
                        profile.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        profile.bio!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.subtext(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (profile.city != null &&
                        profile.city!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.muted(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            profile.city!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Action button
              _buildActionButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isSelf) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardMuted(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'You',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted(context),
          ),
        ),
      );
    }

    switch (connectionStatus) {
      case ConnectionStatus.accepted:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check, size: 14, color: AppColors.success),
              SizedBox(width: 4),
              Text(
                'Connected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              SizedBox(width: 4),
              Text(
                'Pending',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.rejected:
      case ConnectionStatus.none:
        return OutlinedButton.icon(
          onPressed: isConnecting ? null : onConnectPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          icon: isConnecting
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : const Icon(Icons.person_add_alt_1_outlined, size: 14),
          label: const Text('Connect'),
        );
    }
  }
}

/// Backward compatibility alias
typedef AlumniCard = OldBoyCard;
