import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_config.dart';
import '../models/profile.dart';
import 'directory_service.dart';
import 'feed_service.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

class AuthService {
  SupabaseClient get _client => SupabaseService.client;

  Stream<AuthState> get authStateChanges =>
      SupabaseService.isInitialized
          ? _client.auth.onAuthStateChange
          : const Stream.empty();

  User? get currentUser =>
      SupabaseService.isInitialized ? _client.auth.currentUser : null;

  /// Checks whether an email address exists in the database.
  Future<bool> checkEmailExists(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !SupabaseService.isInitialized) return false;
    try {
      final res = await _client
          .from('profiles')
          .select('id, user_id, email, Email')
          .or('email.ilike.$cleanEmail,Email.ilike.$cleanEmail')
          .limit(1);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Checks if a user has completed onboarding
  Future<bool> checkOnboardingCompleted(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('sp_onboarding_completed_$userId') == true) {
        return true;
      }

      if (!SupabaseService.isInitialized) return false;
      final res = await _client
          .from('profiles')
          .select('id, user_id, is_onboarded, onboarding_step, house, grad_year')
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();

      if (res != null) {
        if (res['is_onboarded'] == true ||
            res['onboarding_completed'] == true ||
            res['is_onboarded'] == 'true' ||
            res['onboarding_completed'] == 'true') {
          await prefs.setBool('sp_onboarding_completed_$userId', true);
          return true;
        }
        final house = res['house']?.toString();
        final gradYear = res['grad_year'];
        if (house != null && house.trim().isNotEmpty && gradYear != null) {
          await prefs.setBool('sp_onboarding_completed_$userId', true);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves user's last saved onboarding step (defaults to Step 2 if account was created)
  Future<int> getUserOnboardingStep(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localStep = prefs.getInt('sp_onboarding_step_$userId');
      if (localStep != null && localStep >= 2 && localStep <= 3) {
        return localStep;
      }

      if (!SupabaseService.isInitialized) return 2;
      final res = await _client
          .from('profiles')
          .select('id, user_id, onboarding_step, first_name, last_name, house')
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();

      if (res != null) {
        final step = int.tryParse(res['onboarding_step']?.toString() ?? '');
        if (step != null && step >= 2 && step <= 3) {
          return step;
        }
        final hasName = res['first_name'] != null &&
            res['first_name'].toString().trim().isNotEmpty;
        final hasHouse = res['house'] != null &&
            res['house'].toString().trim().isNotEmpty;
        if (hasName && !hasHouse) return 3;
      }
      return 2;
    } catch (_) {
      return 2;
    }
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final userId = response.user?.id;
    if (userId != null) {
      final meta = response.user?.userMetadata;
      await ensureProfileExists(
        userId: userId,
        email: email.trim(),
        firstName: meta?['first_name']?.toString(),
        lastName: meta?['last_name']?.toString(),
        gradYear: meta?['grad_year'] != null
            ? int.tryParse(meta!['grad_year'].toString())
            : null,
        phone: meta?['phone']?.toString(),
      );
    }

    return response;
  }

  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    int? gradYear,
    String? phone,
  }) async {
    final cleanPhone = phone?.trim();
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authCallbackUrl,
      data: {
        if (firstName != null) 'first_name': firstName.trim(),
        if (lastName != null) 'last_name': lastName.trim(),
        'grad_year': ?gradYear,
        if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
      },
    );

    // Ensure profile row exists with the user's name immediately after signup
    final userId = response.user?.id;
    if (userId != null) {
      await ensureProfileExists(
        userId: userId,
        email: email.trim(),
        firstName: firstName,
        lastName: lastName,
        gradYear: gradYear,
        phone: cleanPhone,
      );
    }

    return response;
  }

  /// Creates or updates the profile row so the user's name is persisted
  /// in the profiles table right after signup. Links pre-imported records
  /// if matching email is found.
  Future<void> ensureProfileExists({
    required String userId,
    String? email,
    String? firstName,
    String? lastName,
    int? gradYear,
    String? phone,
  }) async {
    try {
      final cleanPhone = phone?.trim();
      // 1. Check if row exists for this userId
      final existingUserList = await _client
          .from('profiles')
          .select('id, user_id')
          .or('id.eq.$userId,user_id.eq.$userId')
          .limit(1);

      if (existingUserList.isNotEmpty) {
        await _client.from('profiles').update({
          'id': userId,
          'user_id': userId,
          if (firstName != null && firstName.trim().isNotEmpty)
            'first_name': firstName.trim(),
          if (lastName != null && lastName.trim().isNotEmpty)
            'last_name': lastName.trim(),
          'grad_year': ?gradYear,
          if (cleanPhone != null && cleanPhone.isNotEmpty) ...{
            'phone': cleanPhone,
            'Phone': cleanPhone,
          },
        }).or('id.eq.$userId,user_id.eq.$userId');
        return;
      }

      final placeholderAvatar = Profile.generatePlaceholderAvatar(
        firstName: firstName,
        lastName: lastName,
      );

      // 2. Check if there's an UNCLAIMED pre-imported record with this email that lacks a user_id
      // Strictly filter for user_id IS NULL to prevent hijacking or leaking another user's profile!
      if (email != null && email.isNotEmpty) {
        final unclaimedList = await _client
            .from('profiles')
            .select('id, user_id, Email, avatar_url, "Profile Photo"')
            .filter('user_id', 'is', 'null')
            .ilike('Email', email.trim())
            .limit(1);

        if (unclaimedList.isNotEmpty) {
          final record = unclaimedList.first;
          final recordId = record['id'];
          final existingPhoto = record['avatar_url'] ?? record['Profile Photo'];
          // Link this pre-imported record strictly by primary key and verify user_id is still null
          await _client
              .from('profiles')
              .update({
                'id': userId,
                'user_id': userId,
                if (firstName != null && firstName.trim().isNotEmpty)
                  'first_name': firstName.trim(),
                if (lastName != null && lastName.trim().isNotEmpty)
                  'last_name': lastName.trim(),
                'grad_year': ?gradYear,
                if (cleanPhone != null && cleanPhone.isNotEmpty) ...{
                  'phone': cleanPhone,
                  'Phone': cleanPhone,
                },
                if (existingPhoto == null || existingPhoto.toString().trim().isEmpty)
                  'avatar_url': placeholderAvatar,
              })
              .eq('id', recordId)
              .filter('user_id', 'is', 'null');
          return;
        }
      }

      // 3. Insert new row strictly keyed to this authenticated user
      await _client.from('profiles').insert({
        'id': userId,
        'user_id': userId,
        if (firstName != null && firstName.trim().isNotEmpty)
          'first_name': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'last_name': lastName.trim(),
        'grad_year': ?gradYear,
        if (cleanPhone != null && cleanPhone.isNotEmpty) ...{
          'phone': cleanPhone,
          'Phone': cleanPhone,
        },
        if (email != null && email.isNotEmpty) 'Email': email.trim(),
        'avatar_url': placeholderAvatar,
      });
    } catch (_) {}
  }

  Future<void> sendMagicLink({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: SupabaseConfig.authCallbackUrl,
    );
  }

  Future<void> signOut() async {
    // Explicitly reset all in-memory profile and connection data so nothing bleeds across accounts
    ProfileService.invalidateCache();
    DirectoryService.invalidateConnectionsCache();
    FeedService.clearCache();
    await _client.auth.signOut();
  }
}
