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
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authCallbackUrl,
      data: {
        if (firstName != null) 'first_name': firstName.trim(),
        if (lastName != null) 'last_name': lastName.trim(),
        'grad_year': ?gradYear,
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
  }) async {
    try {
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
