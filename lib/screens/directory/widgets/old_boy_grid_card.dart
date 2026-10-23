import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/connection.dart';
import '../../../models/profile.dart';

class OldBoyGridCard extends StatelessWidget {
  final Profile profile;
  final ConnectionStatus connectionStatus;
  final bool isSelf;
  final bool isConnecting;
  final VoidCallback? onConnectPressed;
  final VoidCallback? onTapProfile;

  const OldBoyGridCard({
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapProfile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Accent Ribbon
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navyDark, AppColors.navyPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: (profile.bannerUrl != null &&
                        profile.bannerUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(profile.bannerUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.35),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 12,
                    top: 6,
                    child: Icon(
                      Icons.school_outlined,
                      size: 34,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  if (profile.house != null && profile.house!.isNotEmpty)
                    Positioned(
                      left: 12,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${profile.house} House',
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Avatar & Identity Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  // Overlapping Avatar
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.08),
                          backgroundImage: (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(profile.avatarUrl!)
                              : null,
                          child: (profile.avatarUrl == null ||
                                  profile.avatarUrl!.isEmpty)
                              ? Text(
                                  profile.initials,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.navyPrimary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Negative space offset compensation
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Column(
                      children: [
                        // Full Name
                        Text(
                          profile.fullName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),

                        // Grad Year Tag
                        if (profile.gradYear != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Class of ${profile.gradYear}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.goldDark,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 16),

                        const SizedBox(height: 6),

                        // Headline or Bio excerpt
                        if (profile.headline != null &&
                            profile.headline!.trim().isNotEmpty)
                          Text(
                            profile.headline!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (profile.bio != null &&
                            profile.bio!.trim().isNotEmpty)
                          Text(
                            profile.bio!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          const Text(
                            'Waitaki Boys\' High School Old Boy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                          ),

                        const SizedBox(height: 6),

                        // City Location
                        if (profile.city != null &&
                            profile.city!.trim().isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  profile.city!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox(height: 14),

                        const SizedBox(height: 12),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: _buildActionButton(),
                        ),
                      ],
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

  Widget _buildActionButton() {
    if (isSelf) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Your Profile',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    switch (connectionStatus) {
      case ConnectionStatus.accepted:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check, size: 14, color: AppColors.success),
              SizedBox(width: 5),
              Text(
                'Connected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              SizedBox(width: 5),
              Text(
                'Pending Request',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.rejected:
      case ConnectionStatus.none:
        return ElevatedButton.icon(
          onPressed: isConnecting ? null : onConnectPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navyPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 9),
            visualDensity: VisualDensity.compact,
          ),
          icon: isConnecting
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add_alt_1, size: 15),
          label: const Text(
            'Connect',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
        );
    }
  }
}
