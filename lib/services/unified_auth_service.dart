import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../core/constants/supabase_config.dart';
import '../models/auth_state.dart';
import '../models/profile.dart';
import 'auth_service.dart';
import 'directory_service.dart';
import 'feed_service.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

/// Unified Authentication & Onboarding Notifier
/// Provides a reactive, clean architecture state manager for the
/// Email/Phone unified auth screen, OTP verification, and multi-step onboarding.
class UnifiedAuthService extends ChangeNotifier {
  static final UnifiedAuthService _instance = UnifiedAuthService._internal();
  factory UnifiedAuthService() => _instance;
  UnifiedAuthService._internal() {
    _init();
  }

  static const String _onboardingStepKey = 'wbhs_onboarding_step';
  static const String _onboardingCompleteKey = 'wbhs_onboarding_completed';

  SupabaseClient get _client => SupabaseService.client;
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  UnifiedAuthState _state = const UnifiedAuthState();
  UnifiedAuthState get state => _state;

  Timer? _countdownTimer;

  void _setState(UnifiedAuthState newState) {
    _state = newState;
    notifyListeners();
  }

  void _init() {
    if (SupabaseService.isInitialized) {
      final user = _client.auth.currentUser;
      if (user != null) {
        _setState(_state.copyWith(
          status: UnifiedAuthStatus.authenticated,
          user: user,
          email: user.email,
        ));
      }

      _client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          _setState(_state.copyWith(
            status: UnifiedAuthStatus.authenticated,
            user: session.user,
            email: session.user.email,
          ));
        } else if (data.event == AuthChangeEvent.signedOut) {
          _setState(const UnifiedAuthState(status: UnifiedAuthStatus.initial));
        }
      });
    }
  }

  void setAuthMode({required bool isEmailMode}) {
    _setState(_state.copyWith(
      isEmailMode: isEmailMode,
      clearError: true,
    ));
  }

  /// Sends a 6-digit SMS OTP to the given phone number
  Future<bool> sendPhoneOtp({required String formattedPhone}) async {
    final cleanPhone = formattedPhone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    _setState(_state.copyWith(
      status: UnifiedAuthStatus.loading,
      clearError: true,
    ));

    try {
      if (SupabaseService.isInitialized) {
        await _client.auth.signInWithOtp(
          phone: cleanPhone,
        );
      } else {
        // Mock fallback for preview & development without active SMS gateway
        await Future.delayed(const Duration(milliseconds: 600));
      }

      _startResendCountdown();
      _setState(_state.copyWith(
        status: UnifiedAuthStatus.otpSent,
        phoneNumber: cleanPhone,
        resendCountdown: 60,
      ));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        status: UnifiedAuthStatus.error,
        errorMessage: _formatErrorMessage(e),
      ));
      return false;
    }
  }

  /// Verifies the 6-digit OTP code received via SMS
  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    _setState(_state.copyWith(
      status: UnifiedAuthStatus.loading,
      clearError: true,
    ));

    try {
      if (SupabaseService.isInitialized) {
        final response = await _client.auth.verifyOTP(
          phone: phone,
          token: token.trim(),
          type: OtpType.sms,
        );

        final user = response.user;
        if (user != null) {
          await _authService.ensureProfileExists(
            userId: user.id,
            phone: phone,
          );
        }
      } else {
        // Mock validation for test & offline environments
        await Future.delayed(const Duration(milliseconds: 600));
      }

      _countdownTimer?.cancel();

      // Check onboarding requirement
      final needsOnboarding = await _checkNeedsOnboarding();
      _setState(_state.copyWith(
        status: needsOnboarding
            ? UnifiedAuthStatus.onboardingRequired
            : UnifiedAuthStatus.authenticated,
        user: SupabaseService.currentUser,
      ));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        status: UnifiedAuthStatus.error,
        errorMessage: _formatErrorMessage(e),
      ));
      return false;
    }
  }

  /// Resends the SMS verification code if cooldown has expired
  Future<bool> resendPhoneOtp() async {
    if (_state.phoneNumber == null || !_state.canResendOtp) return false;
    return await sendPhoneOtp(formattedPhone: _state.phoneNumber!);
  }

  /// Handles Email & Password Registration
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    int? gradYear,
    String? phone,
  }) async {
    _setState(_state.copyWith(
      status: UnifiedAuthStatus.loading,
      clearError: true,
    ));

    try {
      if (SupabaseService.isInitialized) {
        await _authService.signUpWithPassword(
          email: email.trim(),
          password: password,
          firstName: firstName,
          lastName: lastName,
          gradYear: gradYear,
          phone: phone,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
      }

      final needsOnboarding = await _checkNeedsOnboarding();
      _setState(_state.copyWith(
        status: needsOnboarding
            ? UnifiedAuthStatus.onboardingRequired
            : UnifiedAuthStatus.authenticated,
        user: SupabaseService.currentUser,
        email: email.trim(),
      ));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        status: UnifiedAuthStatus.error,
        errorMessage: _formatErrorMessage(e),
      ));
      return false;
    }
  }

  /// Handles Email & Password Login
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setState(_state.copyWith(
      status: UnifiedAuthStatus.loading,
      clearError: true,
    ));

    try {
      if (SupabaseService.isInitialized) {
        await _authService.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
      }

      final needsOnboarding = await _checkNeedsOnboarding();
      _setState(_state.copyWith(
        status: needsOnboarding
            ? UnifiedAuthStatus.onboardingRequired
            : UnifiedAuthStatus.authenticated,
        user: SupabaseService.currentUser,
        email: email.trim(),
      ));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        status: UnifiedAuthStatus.error,
        errorMessage: _formatErrorMessage(e),
      ));
      return false;
    }
  }

  /// Handles Google or Apple Social OAuth
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    _setState(_state.copyWith(
      status: UnifiedAuthStatus.loading,
      clearError: true,
    ));

    try {
      if (SupabaseService.isInitialized) {
        await _client.auth.signInWithOAuth(
          provider,
          redirectTo: SupabaseConfig.authCallbackUrl,
        );
      }
    } catch (e) {
      _setState(_state.copyWith(
        status: UnifiedAuthStatus.error,
        errorMessage: _formatErrorMessage(e),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Onboarding State Persistence
  // ---------------------------------------------------------------------------

  /// Persists current onboarding step to SharedPreferences
  Future<void> saveOnboardingStep(int step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_onboardingStepKey, step);
      _setState(_state.copyWith(onboardingStep: step));
    } catch (_) {}
  }

  /// Retrieves persisted onboarding step so user resumes seamlessly
  Future<int> getSavedOnboardingStep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final step = prefs.getInt(_onboardingStepKey) ?? 0;
      _setState(_state.copyWith(onboardingStep: step));
      return step;
    } catch (_) {
      return 0;
    }
  }

  /// Completes the multi-step onboarding sequence
  Future<void> completeOnboarding({
    required String fullName,
    String? avatarUrl,
    required List<String> interests,
    String? house,
    int? gradYear,
  }) async {
    _setState(_state.copyWith(status: UnifiedAuthStatus.loading));
    try {
      final names = fullName.trim().split(' ');
      final firstName = names.isNotEmpty ? names.first : 'Old';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : 'Boy';

      final placeholderAvatar = Profile.generatePlaceholderAvatar(
        firstName: firstName,
        lastName: lastName,
      );

      final finalAvatar = (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          ? avatarUrl.trim()
          : placeholderAvatar;

      if (SupabaseService.isInitialized) {
        await _profileService.updateProfile(
          firstName: firstName,
          lastName: lastName,
          avatarUrl: finalAvatar,
          house: house ?? 'Don',
          gradYear: gradYear ?? DateTime.now().year,
          headline: interests.isNotEmpty ? interests.join(' • ') : 'Waitaki Old Boy',
        );

        await _profileService.completeOnboarding(
          house: house ?? 'Don',
          gradYear: gradYear ?? DateTime.now().year,
          city: 'New Zealand',
          headline: interests.isNotEmpty ? interests.join(' • ') : 'Waitaki Old Boy',
          industry: interests.isNotEmpty ? interests.first : 'General',
          avatarUrl: finalAvatar,
        );
      }

      // Mark locally completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingStepKey);
      await prefs.setBool(_onboardingCompleteKey, true);

      _setState(_state.copyWith(
        status: UnifiedAuthStatus.authenticated,
        onboardingStep: 0,
      ));
    } catch (e) {
      _setState(_state.copyWith(
        status: UnifiedAuthStatus.error,
        errorMessage: _formatErrorMessage(e),
      ));
    }
  }

  Future<bool> _checkNeedsOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_onboardingCompleteKey) == true) {
        return false;
      }
      return await _profileService.shouldShowOnboarding();
    } catch (_) {
      return false;
    }
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    int count = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      count--;
      if (count <= 0) {
        timer.cancel();
        _setState(_state.copyWith(resendCountdown: 0));
      } else {
        _setState(_state.copyWith(resendCountdown: count));
      }
    });
  }

  String _formatErrorMessage(dynamic error) {
    final str = error.toString();
    if (str.contains('rate limit') || str.contains('429')) {
      return 'Too many attempts. Please wait 60 seconds before trying again.';
    }
    if (str.contains('Invalid OTP') || str.contains('invalid token')) {
      return 'Invalid verification code. Please check your SMS and try again.';
    }
    if (error is AuthException) {
      return error.message;
    }
    return str.replaceAll('Exception:', '').trim();
  }

  Future<void> signOut() async {
    _countdownTimer?.cancel();
    ProfileService.invalidateCache();
    DirectoryService.invalidateConnectionsCache();
    FeedService.clearCache();
    if (SupabaseService.isInitialized) {
      await _client.auth.signOut();
    }
    _setState(const UnifiedAuthState(status: UnifiedAuthStatus.initial));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
