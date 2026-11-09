import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_config.dart';
import '../models/profile.dart';
import 'directory_service.dart';
import 'feed_service.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

/// Result of checking an email or phone number against existing accounts and onboarding state.
class AccountStatusResult {
  final bool hasAccount;
  final bool onboardingCompleted;
  final int onboardingStep;
  final String? email;
  final String? phone;
  final String? userId;

  const AccountStatusResult({
    required this.hasAccount,
    required this.onboardingCompleted,
    this.onboardingStep = 1,
    this.email,
    this.phone,
    this.userId,
  });
}

class AuthService {
  SupabaseClient get _client => SupabaseService.client;

  Stream<AuthState> get authStateChanges =>
      SupabaseService.isInitialized
          ? _client.auth.onAuthStateChange
          : const Stream.empty();

  User? get currentUser =>
      SupabaseService.isInitialized ? _client.auth.currentUser : null;

  static bool isEmailInput(String input) {
    return input.trim().contains('@');
  }

  static bool isPhoneInput(String input) {
    final clean = input.trim().replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return clean.length >= 7 && RegExp(r'^[0-9]+$').hasMatch(clean);
  }

  static bool isValidEmailOrPhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    if (isEmailInput(trimmed)) {
      return trimmed.contains('@') && trimmed.contains('.');
    }
    return isPhoneInput(trimmed);
  }

  /// Checks account existence and onboarding completion status by matching either email or phone.
  Future<AccountStatusResult> checkAccountAndOnboardingStatus(
    String identifier,
  ) async {
    final clean = identifier.trim();
    final isEmail = isEmailInput(clean);

    if (clean.isEmpty || !SupabaseService.isInitialized) {
      return AccountStatusResult(
        hasAccount: false,
        onboardingCompleted: false,
        email: isEmail && clean.isNotEmpty ? clean : null,
        phone: !isEmail && clean.isNotEmpty ? clean : null,
      );
    }

    try {
      List<dynamic> res;
      if (isEmail) {
        res = await _client
            .from('profiles')
            .select('*')
            .or('email.ilike.$clean,Email.ilike.$clean')
            .limit(1);
      } else {
        final cleanDigits = clean.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        final filters = <String>[
          'phone.ilike.$clean',
          '"Phone".ilike.$clean',
          if (cleanDigits != clean) ...[
            'phone.ilike.$cleanDigits',
            '"Phone".ilike.$cleanDigits',
          ],
        ];
        if (cleanDigits.startsWith('0') && cleanDigits.length > 1) {
          final altIntl = '+64${cleanDigits.substring(1)}';
          filters.add('phone.ilike.$altIntl');
          filters.add('"Phone".ilike.$altIntl');
        } else if (cleanDigits.startsWith('+64') && cleanDigits.length > 3) {
          final altLocal = '0${cleanDigits.substring(3)}';
          filters.add('phone.ilike.$altLocal');
          filters.add('"Phone".ilike.$altLocal');
        }
        res = await _client
            .from('profiles')
            .select('*')
            .or(filters.join(','))
            .limit(1);
      }

      if (res.isEmpty) {
        return AccountStatusResult(
          hasAccount: false,
          onboardingCompleted: false,
          email: isEmail ? clean : null,
          phone: !isEmail ? clean : null,
        );
      }

      final row = res.first as Map<String, dynamic>;
      final userId = (row['user_id'] ?? row['id'])?.toString();
      final matchedEmail = (row['email'] ?? row['Email'])?.toString().trim();
      final matchedPhone = (row['phone'] ?? row['Phone'])?.toString().trim();

      bool isCompleted = row['is_onboarded'] == true ||
          row['onboarding_completed'] == true ||
          row['is_onboarded'] == 'true' ||
          row['onboarding_completed'] == 'true';

      if (!isCompleted && userId != null && userId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('sp_onboarding_completed_$userId') == true) {
          isCompleted = true;
        }
      }

      if (!isCompleted) {
        final hasName =
            (row['first_name']?.toString().trim().isNotEmpty ?? false) ||
                (row['Name']?.toString().trim().isNotEmpty ?? false);
        final hasAge = row['age'] != null || row['Age'] != null;
        final hasPhone = matchedPhone != null && matchedPhone.isNotEmpty;
        final hasHouse =
            (row['house']?.toString().trim().isNotEmpty ?? false) ||
                (row['House']?.toString().trim().isNotEmpty ?? false);

        if ((hasName && hasAge && hasPhone) || (hasName && hasHouse)) {
          isCompleted = true;
        }
      }

      final step = int.tryParse(row['onboarding_step']?.toString() ?? '') ?? 1;

      return AccountStatusResult(
        hasAccount: true,
        onboardingCompleted: isCompleted,
        onboardingStep: step,
        email: (matchedEmail != null && matchedEmail.isNotEmpty)
            ? matchedEmail
            : (isEmail ? clean : null),
        phone: (matchedPhone != null && matchedPhone.isNotEmpty)
            ? matchedPhone
            : (!isEmail ? clean : null),
        userId: userId,
      );
    } catch (_) {
      return AccountStatusResult(
        hasAccount: false,
        onboardingCompleted: false,
        email: isEmail ? clean : null,
        phone: !isEmail ? clean : null,
      );
    }
  }

  /// Checks whether an email address or phone number exists in the database.
  Future<bool> checkEmailExists(String identifier) async {
    final status = await checkAccountAndOnboardingStatus(identifier);
    return status.hasAccount;
  }

  /// Checks if a user has completed onboarding (without requiring graduation year).
  Future<bool> checkOnboardingCompleted(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('sp_onboarding_completed_$userId') == true) {
        return true;
      }

      if (!SupabaseService.isInitialized) return false;
      final res = await _client
          .from('profiles')
          .select('*')
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
        final hasName =
            (res['first_name']?.toString().trim().isNotEmpty ?? false) ||
                (res['Name']?.toString().trim().isNotEmpty ?? false);
        final hasAge = res['age'] != null || res['Age'] != null;
        final phone = (res['phone'] ?? res['Phone'])?.toString().trim();
        final hasPhone = phone != null && phone.isNotEmpty;
        final house = (res['house'] ?? res['House'])?.toString().trim();
        final hasHouse = house != null && house.isNotEmpty;

        if ((hasName && hasAge && hasPhone) || (hasName && hasHouse)) {
          await prefs.setBool('sp_onboarding_completed_$userId', true);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves user's last saved onboarding step
  Future<int> getUserOnboardingStep(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localStep = prefs.getInt('sp_onboarding_step_$userId');
      if (localStep != null && localStep >= 1) {
        return localStep;
      }

      if (!SupabaseService.isInitialized) return 1;
      final res = await _client
          .from('profiles')
          .select('id, user_id, onboarding_step')
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();

      if (res != null) {
        final step = int.tryParse(res['onboarding_step']?.toString() ?? '');
        if (step != null && step >= 1) {
          return step;
        }
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final trimmed = email.trim();
    String? resolvedEmail = isEmailInput(trimmed) ? trimmed : null;
    String? resolvedPhone = !isEmailInput(trimmed) ? trimmed : null;

    if (resolvedEmail == null) {
      final status = await checkAccountAndOnboardingStatus(trimmed);
      if (status.email != null && status.email!.isNotEmpty) {
        resolvedEmail = status.email;
      }
    }

    final AuthResponse response;
    if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
      response = await _client.auth.signInWithPassword(
        email: resolvedEmail,
        password: password,
      );
    } else {
      final cleanPhone =
          (resolvedPhone ?? trimmed).replaceAll(RegExp(r'[\s\-\(\)]'), '');
      response = await _client.auth.signInWithPassword(
        phone: cleanPhone,
        password: password,
      );
    }

    final userId = response.user?.id;
    if (userId != null) {
      final meta = response.user?.userMetadata;
      await ensureProfileExists(
        userId: userId,
        email: response.user?.email ?? resolvedEmail,
        firstName: meta?['first_name']?.toString(),
        lastName: meta?['last_name']?.toString(),
        gradYear: meta?['grad_year'] != null
            ? int.tryParse(meta!['grad_year'].toString())
            : null,
        age: meta?['age'] != null
            ? int.tryParse(meta!['age'].toString())
            : null,
        phone: meta?['phone']?.toString() ?? resolvedPhone,
        sharePhoneOnProfile: meta?['share_phone_on_profile'] is bool
            ? meta!['share_phone_on_profile'] as bool
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
    int? age,
    String? phone,
    bool? sharePhoneOnProfile,
    bool? isOnboarded,
  }) async {
    final cleanEmail = email.trim();
    final cleanPhone = phone?.trim();
    var response = await _client.auth.signUp(
      email: cleanEmail,
      password: password,
      emailRedirectTo: SupabaseConfig.authCallbackUrl,
      data: {
        if (firstName != null) 'first_name': firstName.trim(),
        if (lastName != null) 'last_name': lastName.trim(),
        'grad_year': ?gradYear,
        'age': ?age,
        if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
        'share_phone_on_profile': ?sharePhoneOnProfile,
        'is_onboarded': ?isOnboarded,
      },
    );

    // Log in automatically if signUp did not immediately establish a session
    if (response.session == null && SupabaseService.isInitialized) {
      try {
        response = await _client.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
      } catch (_) {}
    }

    // Ensure profile row exists with the user's details immediately after signup
    final userId = response.user?.id ?? _client.auth.currentUser?.id;
    if (userId != null) {
      await ensureProfileExists(
        userId: userId,
        email: cleanEmail,
        firstName: firstName,
        lastName: lastName,
        gradYear: gradYear,
        age: age,
        phone: cleanPhone,
        sharePhoneOnProfile: sharePhoneOnProfile,
        isOnboarded: isOnboarded,
      );
    }

    return response;
  }

  /// Creates or updates the profile row so the user's name and details are persisted
  /// in the profiles table right after signup. Links pre-imported records
  /// if matching email or phone is found.
  Future<void> ensureProfileExists({
    required String userId,
    String? email,
    String? firstName,
    String? lastName,
    int? gradYear,
    int? age,
    String? phone,
    bool? sharePhoneOnProfile,
    bool? isOnboarded,
  }) async {
    try {
      final cleanPhone = phone?.trim();
      final cleanEmail = email?.trim();

      final updateFields = <String, dynamic>{
        'id': userId,
        'user_id': userId,
        if (firstName != null && firstName.trim().isNotEmpty)
          'first_name': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'last_name': lastName.trim(),
        'grad_year': ?gradYear,
        'age': ?age,
        if (cleanPhone != null && cleanPhone.isNotEmpty) ...{
          'phone': cleanPhone,
          'Phone': cleanPhone,
        },
        if (cleanEmail != null && cleanEmail.isNotEmpty) ...{
          'email': cleanEmail,
          'Email': cleanEmail,
        },
        'share_phone_on_profile': ?sharePhoneOnProfile,
        if (isOnboarded != null) ...{
          'is_onboarded': isOnboarded,
          'onboarding_completed': isOnboarded,
        },
      };

      // 1. Check if row exists for this userId
      final existingUserList = await _client
          .from('profiles')
          .select('id, user_id')
          .or('id.eq.$userId,user_id.eq.$userId')
          .limit(1);

      if (existingUserList.isNotEmpty) {
        try {
          await _client
              .from('profiles')
              .update(updateFields)
              .or('id.eq.$userId,user_id.eq.$userId');
        } catch (e) {
          if (e.toString().contains('share_phone_on_profile')) {
            updateFields.remove('share_phone_on_profile');
            await _client
                .from('profiles')
                .update(updateFields)
                .or('id.eq.$userId,user_id.eq.$userId');
          }
        }
        return;
      }

      final placeholderAvatar = Profile.generatePlaceholderAvatar(
        firstName: firstName,
        lastName: lastName,
      );

      // 2. Check if there's an UNCLAIMED pre-imported record with this email or phone that lacks a user_id
      final unclaimedFilters = <String>[
        if (cleanEmail != null && cleanEmail.isNotEmpty) ...[
          'email.ilike.$cleanEmail',
          'Email.ilike.$cleanEmail',
        ],
        if (cleanPhone != null && cleanPhone.isNotEmpty) ...[
          'phone.ilike.$cleanPhone',
          '"Phone".ilike.$cleanPhone',
        ],
      ];

      if (unclaimedFilters.isNotEmpty) {
        final unclaimedList = await _client
            .from('profiles')
            .select('id, user_id, Email, avatar_url, "Profile Photo"')
            .filter('user_id', 'is', 'null')
            .or(unclaimedFilters.join(','))
            .limit(1);

        if (unclaimedList.isNotEmpty) {
          final record = unclaimedList.first;
          final recordId = record['id'];
          final existingPhoto = record['avatar_url'] ?? record['Profile Photo'];
          final claimPayload = <String, dynamic>{
            ...updateFields,
            if (existingPhoto == null ||
                existingPhoto.toString().trim().isEmpty)
              'avatar_url': placeholderAvatar,
          };
          try {
            await _client
                .from('profiles')
                .update(claimPayload)
                .eq('id', recordId)
                .filter('user_id', 'is', 'null');
          } catch (e) {
            if (e.toString().contains('share_phone_on_profile')) {
              claimPayload.remove('share_phone_on_profile');
              await _client
                  .from('profiles')
                  .update(claimPayload)
                  .eq('id', recordId)
                  .filter('user_id', 'is', 'null');
            }
          }
          return;
        }
      }

      // 3. Insert new row strictly keyed to this authenticated user
      final insertPayload = <String, dynamic>{
        ...updateFields,
        'avatar_url': placeholderAvatar,
      };
      try {
        await _client.from('profiles').insert(insertPayload);
      } catch (e) {
        if (e.toString().contains('share_phone_on_profile')) {
          insertPayload.remove('share_phone_on_profile');
          await _client.from('profiles').insert(insertPayload);
        }
      }
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
