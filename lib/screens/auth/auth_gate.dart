import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../services/auth_service.dart';
import '../../services/directory_service.dart';
import '../../services/feed_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../home_navigation_screen.dart';
import '../onboarding/onboarding_wizard_screen.dart';
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
  StreamSubscription<AuthState>? _authSubscription;

  Session? _session;
  String? _currentUserId;
  bool _isLoading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    if (_isConfigured && SupabaseService.isInitialized) {
      _initAuth();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onConfigured() {
    setState(() {
      _isConfigured = true;
      _isLoading = true;
    });
    _initAuth();
  }

  void _initAuth() {
    final currentSession = SupabaseService.client.auth.currentSession;
    _handleSessionUpdate(currentSession, isInitial: true);

    _authSubscription =
        SupabaseService.client.auth.onAuthStateChange.listen((data) {
      _handleAuthEvent(data.event, data.session);
    });
  }

  void _handleAuthEvent(AuthChangeEvent event, Session? session) {
    if (event == AuthChangeEvent.signedOut || session == null) {
      ProfileService.invalidateCache();
      DirectoryService.invalidateConnectionsCache();
      FeedService.clearCache();
      if (mounted) {
        setState(() {
          _session = null;
          _currentUserId = null;
          _needsOnboarding = false;
          _isLoading = false;
        });
      }
      return;
    }

    // Only re-evaluate onboarding when user identity changes
    if (_currentUserId != session.user.id) {
      ProfileService.invalidateCache();
      DirectoryService.invalidateConnectionsCache();
      FeedService.clearCache();
      _handleSessionUpdate(session);
    } else {
      // Same user updated metadata or refreshed token: keep current navigation flow intact
      _session = session;
    }
  }

  Future<void> _handleSessionUpdate(Session? session,
      {bool isInitial = false}) async {
    if (session == null) {
      if (mounted) {
        setState(() {
          _session = null;
          _currentUserId = null;
          _needsOnboarding = false;
          _isLoading = false;
        });
      }
      return;
    }

    final userId = session.user.id;
    _session = session;
    _currentUserId = userId;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Ensure profile row exists with user name once per sign-in
    _backfillProfileIfNeeded(session.user);

    // Check whether onboarding should be shown for this user
    try {
      final needs = await _profileService.shouldShowOnboarding();
      if (mounted && _currentUserId == userId) {
        setState(() {
          _needsOnboarding = needs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && _currentUserId == userId) {
        setState(() {
          _needsOnboarding = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Ensures the profile row exists with user_id and links any pre-imported record
  Future<void> _backfillProfileIfNeeded(User user) async {
    try {
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

  void _onOnboardingCompleted() {
    if (mounted) {
      setState(() {
        _needsOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured || !SupabaseService.isInitialized) {
      return SetupScreen(onConfigured: _onConfigured);
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.navyPrimary,
          ),
        ),
      );
    }

    if (_session != null) {
      if (_needsOnboarding) {
        return OnboardingWizardScreen(
          onCompleted: _onOnboardingCompleted,
        );
      }
      return const HomeNavigationScreen(initialIndex: 1);
    }

    return const AuthScreen();
  }
}
