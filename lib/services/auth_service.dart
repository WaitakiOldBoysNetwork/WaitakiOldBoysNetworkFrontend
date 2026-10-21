import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
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
      // 1. Check if there's a pre-imported record with this email that lacks a user_id
      if (email != null && email.isNotEmpty) {
        final existing = await _client
            .from('profiles')
            .select()
            .ilike('Email', email.trim())
            .maybeSingle();

        if (existing != null) {
          // Link this pre-imported record to the newly registered account
          await _client
              .from('profiles')
              .update({
                'id': userId,
                'user_id': userId,
                if (firstName != null && firstName.trim().isNotEmpty)
                  'first_name': firstName.trim(),
                if (lastName != null && lastName.trim().isNotEmpty)
                  'last_name': lastName.trim(),
                if (gradYear != null) 'grad_year': gradYear,
              })
              .ilike('Email', email.trim());
          return;
        }
      }

      await _client.from('profiles').upsert({
        'id': userId,
        'user_id': userId,
        'first_name': ?firstName?.trim(),
        'last_name': ?lastName?.trim(),
        'grad_year': ?gradYear,
      }, onConflict: 'id');
    } catch (_) {
      // Fallback direct upsert
      try {
        await _client.from('profiles').upsert({
          'id': userId,
          'user_id': userId,
          'first_name': ?firstName?.trim(),
          'last_name': ?lastName?.trim(),
          'grad_year': ?gradYear,
        }, onConflict: 'id');
      } catch (_) {}
    }
  }

  Future<void> sendMagicLink({required String email}) async {
    await _client.auth.signInWithOtp(email: email.trim());
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
