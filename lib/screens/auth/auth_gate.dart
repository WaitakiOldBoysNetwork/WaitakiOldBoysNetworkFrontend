import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../home_navigation_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../setup/setup_screen.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isConfigured = SupabaseConfig.isConfigured;
  final _profileService = ProfileService();

  void _onConfigured() {
    setState(() {
      _isConfigured = true;
    });
  }

  /// Ensures the profile row exists with user_id and links any pre-imported record
  Future<void> _backfillProfileIfNeeded() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      final meta = user.userMetadata;
      final firstName = meta?['first_name']?.toString();
      final lastName = meta?['last_name']?.toString();
      final gradYear = meta?['grad_year'] != null
          ? int.tryParse(meta!['grad_year'].toString())
          : null;

      await AuthService().ensureProfileExists(
        userId: user.id,
        email: user.email,
        firstName: firstName,
        lastName: lastName,
        gradYear: gradYear,
      );
    } catch (_) {
      // Non-fatal — the profile will be fixed on next profile update
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured || !SupabaseService.isInitialized) {
      return SetupScreen(onConfigured: _onConfigured);
    }

    return StreamBuilder<AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // If connecting or initial wait
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.navyPrimary,
              ),
            ),
          );
        }

        final session = snapshot.data?.session ??
            SupabaseService.client.auth.currentSession;

        if (session != null) {
          // Fire-and-forget: ensure profile row has name data
          _backfillProfileIfNeeded();

          // Check whether onboarding should be shown for this user
          return FutureBuilder<bool>(
            future: _profileService.shouldShowOnboarding(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.navyPrimary,
                    ),
                  ),
                );
              }

              final needsOnboarding = onboardingSnapshot.data ?? false;
              if (needsOnboarding) {
                return OnboardingScreen(
                  onCompleted: () {
                    setState(() {});
                  },
                );
              }

              return const HomeNavigationScreen();
            },
          );
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
