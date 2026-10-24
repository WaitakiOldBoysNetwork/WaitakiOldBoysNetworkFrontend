import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class ProfileService {
  SupabaseClient get _client => SupabaseService.client;

  // In-memory cache for the current user's profile to prevent redundant REST calls on navigation
  static Profile? _cachedCurrentProfile;
  static String? _cachedUserId;
  static DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 3);

  // In-memory set of user IDs who have completed or skipped onboarding during this app run
  static final Set<String> _onboardingCompletedUsers = {};

  /// Explicitly clear in-memory profile cache and user tracking
  static void invalidateCache() {
    _cachedCurrentProfile = null;
    _cachedUserId = null;
    _cacheTimestamp = null;
    _onboardingCompletedUsers.clear();
  }

  /// Mark onboarding completed in memory
  static void markOnboardingCompleted(String userId) {
    _onboardingCompletedUsers.add(userId);
  }

  /// Reset in-memory onboarding completion tracking (for logout or tests)
  static void resetOnboardingMemory() {
    _onboardingCompletedUsers.clear();
  }

  @visibleForTesting
  static String? get cachedUserId => _cachedUserId;

  @visibleForTesting
  static Profile? get cachedCurrentProfile => _cachedCurrentProfile;

  @visibleForTesting
  static void setCachedProfileForTest(Profile? profile, String? userId) {
    _cachedCurrentProfile = profile;
    _cachedUserId = userId;
    _cacheTimestamp = DateTime.now();
  }

  Future<Profile?> getCurrentProfile({bool forceRefresh = false}) async {
    if (!SupabaseService.isInitialized) return null;
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      invalidateCache();
      return null;
    }

    // Strictly ensure in-memory cache belongs to the exact currently authenticated userId
    if (!forceRefresh &&
        _cachedCurrentProfile != null &&
        _cachedUserId == userId &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedCurrentProfile;
    }

    try {
      // Query profiles strictly matching current authenticated user's ID
      // Order by updated_at descending and take 1 to gracefully handle legacy duplicates
      final response = await _client
          .from('profiles')
          .select(
            'id, user_id, first_name, last_name, headline, bio, house, grad_year, city, industry, company, avatar_url, banner_url, open_to_helping, looking_for, phone, email',
          )
          .or('user_id.eq.$userId,id.eq.$userId')
          .order('updated_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        var profile = Profile.fromJson(response.first);
        // Fallback banner check from user metadata or SharedPreferences if column not populated
        if (profile.bannerUrl == null || profile.bannerUrl!.isEmpty) {
          final fallbackBanner = await _getFallbackBanner(userId);
          if (fallbackBanner != null && fallbackBanner.isNotEmpty) {
            profile = profile.copyWith(bannerUrl: fallbackBanner);
          }
        }
        _cachedCurrentProfile = profile;
        _cachedUserId = userId;
        _cacheTimestamp = DateTime.now();
        return profile;
      }

      // If no row exists yet (e.g. freshly created auth user before trigger completes),
      // build a placeholder profile from auth metadata
      final authUser = SupabaseService.currentUser;
      final meta = authUser?.userMetadata;
      final fallbackBanner = await _getFallbackBanner(userId);
      final placeholder = Profile(
        id: userId,
        userId: userId,
        firstName: meta?['first_name']?.toString() ?? '',
        lastName: meta?['last_name']?.toString() ?? '',
        headline: meta?['headline']?.toString(),
        city: meta?['city']?.toString(),
        house: meta?['house']?.toString(),
        industry: meta?['industry']?.toString(),
        company: meta?['company']?.toString(),
        bio: meta?['bio']?.toString(),
        phone: meta?['phone']?.toString(),
        email: authUser?.email,
        bannerUrl: fallbackBanner,
        gradYear: meta?['grad_year'] != null
            ? int.tryParse(meta!['grad_year'].toString())
            : null,
      );
      _cachedCurrentProfile = placeholder;
      _cachedUserId = userId;
      _cacheTimestamp = DateTime.now();
      return placeholder;
    } catch (e) {
      // Never return another user's cached profile on error
      if (_cachedCurrentProfile != null && _cachedUserId == userId) {
        return _cachedCurrentProfile;
      }
      return null;
    }
  }

  Future<Profile?> getProfileById(String id) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final response = await _client
          .from('profiles')
          .select(
            'id, user_id, first_name, last_name, headline, bio, house, grad_year, city, industry, company, avatar_url, banner_url, open_to_helping, looking_for, phone, email',
          )
          .or('id.eq.$id,user_id.eq.$id')
          .order('updated_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        var profile = Profile.fromJson(response.first);
        final currentUserId = SupabaseService.currentUserId;
        if ((profile.bannerUrl == null || profile.bannerUrl!.isEmpty) &&
            currentUserId != null &&
            (id == currentUserId || profile.userId == currentUserId)) {
          final fallbackBanner = await _getFallbackBanner(currentUserId);
          if (fallbackBanner != null && fallbackBanner.isNotEmpty) {
            profile = profile.copyWith(bannerUrl: fallbackBanner);
          }
        }
        return profile;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getFallbackBanner(String userId) async {
    final metaBanner =
        SupabaseService.currentUser?.userMetadata?['banner_url']?.toString();
    if (metaBanner != null && metaBanner.isNotEmpty) {
      return metaBanner;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('sp_user_banner_$userId');
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? headline,
    int? gradYear,
    String? city,
    String? house,
    String? industry,
    String? company,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    String? openToHelping,
    String? lookingFor,
    String? phone,
    int? age,
    int? onboardingStep,
    bool? isOnboarded,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final cleanFirst = firstName.trim();
    final cleanLast = lastName.trim();
    final fullName = '$cleanFirst $cleanLast'.trim();

    final data = <String, dynamic>{
      'user_id': userId,
      'first_name': cleanFirst,
      'last_name': cleanLast,
      'Name': fullName,
      'headline': headline?.trim(),
      'What are you up to': headline?.trim(),
      'grad_year': gradYear,
      'Year left School': gradYear,
      'city': city?.trim(),
      'Region': city?.trim(),
      'house': house?.trim(),
      'House': house?.trim(),
      'industry': industry?.trim(),
      'Industry': industry?.trim(),
      'company': company?.trim(),
      'Company / Organisation': company?.trim(),
      'bio': bio?.trim(),
      'Short Bio': bio?.trim(),
      'Full Bio': bio?.trim(),
      if (phone != null) ...{
        'phone': phone.trim().isEmpty ? null : phone.trim(),
        'Phone': phone.trim().isEmpty ? null : phone.trim(),
      },
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
        'avatar_url': avatarUrl.trim(),
      if (openToHelping != null) ...{
        'open_to_helping': openToHelping.trim(),
        'Open to helping': openToHelping.trim(),
      },
      if (lookingFor != null) ...{
        'looking_for': lookingFor.trim(),
        'Looking for': lookingFor.trim(),
      },
      'age': ?age,
      'onboarding_step': ?onboardingStep,
      if (isOnboarded != null) ...{
        'is_onboarded': isOnboarded,
        'onboarding_completed': isOnboarded,
      },
    };

    if (bannerUrl != null) {
      data['banner_url'] = bannerUrl.trim().isEmpty ? null : bannerUrl.trim();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (onboardingStep != null) {
        await prefs.setInt('sp_onboarding_step_$userId', onboardingStep);
      }
      if (isOnboarded != null) {
        await prefs.setBool('sp_onboarding_completed_$userId', isOnboarded);
        if (isOnboarded) markOnboardingCompleted(userId);
      }
    } catch (_) {}

    // Invalidate cached profile so subsequent immediate reads won't return stale data
    invalidateCache();

    // Also persist in auth user metadata for fast responsive fallback
    try {
      await _client.auth.updateUser(UserAttributes(
        data: {
          'first_name': cleanFirst,
          'last_name': cleanLast,
          'headline': headline?.trim(),
          'grad_year': gradYear,
          'city': city?.trim(),
          'house': house?.trim(),
          'industry': industry?.trim(),
          'company': company?.trim(),
          'bio': bio?.trim(),
          if (phone != null)
            'phone': phone.trim().isEmpty ? null : phone.trim(),
          if (openToHelping != null) 'open_to_helping': openToHelping.trim(),
          if (lookingFor != null) 'looking_for': lookingFor.trim(),
          if (bannerUrl != null)
            'banner_url': bannerUrl.trim().isEmpty ? null : bannerUrl.trim(),
        },
      ));
    } catch (_) {}

    // Check if a profile row exists strictly matching this user's id or user_id
    final existingList = await _client
        .from('profiles')
        .select('id, user_id')
        .or('id.eq.$userId,user_id.eq.$userId')
        .limit(1);

    final existing = existingList.isNotEmpty ? existingList.first : null;

    try {
      if (existing != null) {
        await _client
            .from('profiles')
            .update(data)
            .or('id.eq.$userId,user_id.eq.$userId');
        invalidateCache();
        return;
      }

      // Check if there's an UNCLAIMED pre-imported record matching current user's email
      // Strictly require user_id IS NULL to prevent claiming or overwriting another user's record!
      final userEmail = SupabaseService.currentUser?.email;
      if (userEmail != null && userEmail.trim().isNotEmpty) {
        final unclaimedList = await _client
            .from('profiles')
            .select('id, user_id, Email')
            .filter('user_id', 'is', 'null')
            .ilike('Email', userEmail.trim())
            .limit(1);

        if (unclaimedList.isNotEmpty) {
          final targetRecordId = unclaimedList.first['id'];
          await _client
              .from('profiles')
              .update({
                'id': userId,
                'user_id': userId,
                ...data,
              })
              .eq('id', targetRecordId)
              .filter('user_id', 'is', 'null');
          invalidateCache();
          return;
        }
      }

      // Otherwise insert a new profile row strictly keyed to this authenticated user
      if (!data.containsKey('avatar_url') ||
          data['avatar_url'] == null ||
          data['avatar_url'].toString().trim().isEmpty) {
        data['avatar_url'] = Profile.generatePlaceholderAvatar(
          firstName: cleanFirst,
          lastName: cleanLast,
        );
      }
      await _client.from('profiles').insert({
        'id': userId,
        'user_id': userId,
        ...data,
      });
      invalidateCache();
    } catch (e) {
      // If banner_url column does not exist in the database table yet, retry without banner_url
      if (e.toString().contains('banner_url') && data.containsKey('banner_url')) {
        data.remove('banner_url');
        if (existing != null) {
          await _client
              .from('profiles')
              .update(data)
              .or('id.eq.$userId,user_id.eq.$userId');
          invalidateCache();
          return;
        }
        await _client.from('profiles').insert({
          'id': userId,
          'user_id': userId,
          ...data,
        });
        invalidateCache();
        return;
      }
      rethrow;
    }
  }

  /// Onboarding completion workflow
  Future<void> completeOnboarding({
    required String house,
    required int gradYear,
    required String city,
    required String headline,
    required String industry,
    String? company,
    String? bio,
    String? avatarUrl,
    bool openToHelping = true,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    // 1. Immediately flag onboarding completed in memory and SharedPreferences
    // so any concurrent checks (e.g. from auth state listeners) immediately know it's completed.
    markOnboardingCompleted(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sp_onboarding_completed_$userId', true);
    } catch (_) {}

    // Prefer the authenticated user's own auth metadata first to guarantee identity
    final meta = SupabaseService.currentUser?.userMetadata;
    final metaFirst = meta?['first_name']?.toString().trim();
    final metaLast = meta?['last_name']?.toString().trim();

    final currentProfile = await getCurrentProfile();
    final isOwnProfile = currentProfile != null &&
        (currentProfile.id == userId || currentProfile.userId == userId);

    final firstName = (metaFirst != null && metaFirst.isNotEmpty)
        ? metaFirst
        : (isOwnProfile ? (currentProfile.firstName ?? '').trim() : '');
    final lastName = (metaLast != null && metaLast.isNotEmpty)
        ? metaLast
        : (isOwnProfile ? (currentProfile.lastName ?? '').trim() : '');

    final avatarToSave = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : (currentProfile?.avatarUrl != null && currentProfile!.avatarUrl!.isNotEmpty)
            ? currentProfile.avatarUrl
            : Profile.generatePlaceholderAvatar(
                firstName: firstName,
                lastName: lastName,
              );

    await updateProfile(
      firstName: firstName.isNotEmpty ? firstName : 'Old',
      lastName: lastName.isNotEmpty ? lastName : 'Boy',
      avatarUrl: avatarToSave,
      house: house,
      gradYear: gradYear,
      city: city,
      headline: headline,
      industry: industry,
      company: company,
      bio: bio,
      openToHelping: openToHelping ? 'true' : null,
    );

    // Ensure SharedPreferences flag is saved
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sp_onboarding_completed_$userId', true);
    } catch (_) {}
  }

  /// User skips onboarding for now
  Future<void> skipOnboarding() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    markOnboardingCompleted(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sp_onboarding_completed_$userId', true);
    } catch (_) {}
  }

  /// Check whether current user should be presented with onboarding flow
  Future<bool> shouldShowOnboarding() async {
    if (!SupabaseService.isInitialized) return false;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    // Check in-memory flag first for instantaneous response
    if (_onboardingCompletedUsers.contains(userId)) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool('sp_onboarding_completed_$userId');
      if (isCompleted == true) {
        _onboardingCompletedUsers.add(userId);
        return false;
      }

      final profile = await getCurrentProfile();
      if (profile == null) return true;

      // If user already has house, gradYear, and (city or headline or industry)
      final hasHouse =
          profile.house != null && profile.house!.trim().isNotEmpty;
      final hasGradYear = profile.gradYear != null;
      final hasLocationOrCareer = (profile.city != null &&
              profile.city!.trim().isNotEmpty) ||
          (profile.headline != null && profile.headline!.trim().isNotEmpty) ||
          (profile.industry != null && profile.industry!.trim().isNotEmpty);

      if (hasHouse && hasGradYear && hasLocationOrCareer) {
        _onboardingCompletedUsers.add(userId);
        await prefs.setBool('sp_onboarding_completed_$userId', true);
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> uploadAvatar(Uint8List imageBytes, String fileExtension) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final filePath = '${SupabaseConfig.avatarFolder}/${userId}_$timestamp.$cleanExt';

    // Upload to Supabase Storage 'media' bucket
    await _client.storage.from(SupabaseConfig.storageBucket).uploadBinary(
          filePath,
          imageBytes,
          fileOptions: FileOptions(
            contentType: 'image/$cleanExt',
            upsert: true,
          ),
        );

    final publicUrl = _client.storage
        .from(SupabaseConfig.storageBucket)
        .getPublicUrl(filePath);

    final avatarData = {
      'user_id': userId,
      'avatar_url': publicUrl,
    };

    // Check if profile exists and update, or insert
    final existing = await _client
        .from('profiles')
        .select('id')
        .or('id.eq.$userId,user_id.eq.$userId')
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('profiles')
          .update(avatarData)
          .or('id.eq.$userId,user_id.eq.$userId');
    } else {
      await _client.from('profiles').insert({
        'id': userId,
        ...avatarData,
      });
    }
    invalidateCache();

    return publicUrl;
  }

  Future<String> uploadBanner(Uint8List imageBytes, String fileExtension) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final filePath = '${SupabaseConfig.bannerFolder}/${userId}_$timestamp.$cleanExt';

    // Upload to Supabase Storage 'media' bucket
    await _client.storage.from(SupabaseConfig.storageBucket).uploadBinary(
          filePath,
          imageBytes,
          fileOptions: FileOptions(
            contentType: 'image/$cleanExt',
            upsert: true,
          ),
        );

    final publicUrl = _client.storage
        .from(SupabaseConfig.storageBucket)
        .getPublicUrl(filePath);

    // 1. Persist in Auth user metadata
    try {
      await _client.auth.updateUser(UserAttributes(
        data: {'banner_url': publicUrl},
      ));
    } catch (_) {}

    // 2. Persist in SharedPreferences local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sp_user_banner_$userId', publicUrl);
    } catch (_) {}

    // 3. Update profiles table (if banner_url column exists)
    final bannerData = {
      'user_id': userId,
      'banner_url': publicUrl,
    };

    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('profiles')
            .update(bannerData)
            .or('id.eq.$userId,user_id.eq.$userId');
      } else {
        await _client.from('profiles').insert({
          'id': userId,
          ...bannerData,
        });
      }
    } catch (_) {
      // Gracefully continue if banner_url column does not exist in table yet;
      // fallback in userMetadata & SharedPreferences ensures it persists seamlessly.
    }
    invalidateCache();

    return publicUrl;
  }

  Future<void> removeBanner() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    // 1. Clear from Auth user metadata
    try {
      await _client.auth.updateUser(UserAttributes(
        data: {'banner_url': null},
      ));
    } catch (_) {}

    // 2. Clear from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sp_user_banner_$userId');
    } catch (_) {}

    // 3. Clear from profiles table
    try {
      await _client
          .from('profiles')
          .update({'banner_url': null})
          .or('id.eq.$userId,user_id.eq.$userId');
    } catch (_) {}
    invalidateCache();
  }

  /// Permanently deletes the current user's profile, content, connections, and account.
  Future<void> deleteAccount() async {
    invalidateCache();
    if (!SupabaseService.isInitialized) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('No authenticated user found');

    // 1. Attempt secure server-side RPC deletion
    try {
      await _client.rpc('delete_user_account');
    } catch (_) {
      // 2. Client-side fallback cleanup in case RPC is not yet applied
      try {
        await _client.from('post_comments').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _client.from('post_likes').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _client.from('posts').delete().eq('author_id', userId);
      } catch (_) {}
      try {
        await _client
            .from('connections')
            .delete()
            .or('requester_id.eq.$userId,recipient_id.eq.$userId');
      } catch (_) {}
      try {
        await _client
            .from('profiles')
            .delete()
            .or('id.eq.$userId,user_id.eq.$userId');
      } catch (_) {}
    }

    // 3. Clear local device preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sp_user_banner_$userId');
      await prefs.remove('user_banner_$userId');
      await prefs.remove('sp_onboarding_completed_$userId');
      await prefs.remove('onboarding_skipped_$userId');
    } catch (_) {}

    _onboardingCompletedUsers.remove(userId);
    invalidateCache();

    // 4. Sign out
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
