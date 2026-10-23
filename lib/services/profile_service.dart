import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class ProfileService {
  SupabaseClient get _client => SupabaseService.client;

  // In-memory cache for the current user's profile to prevent redundant REST calls on navigation
  static Profile? _cachedCurrentProfile;
  static DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 3);

  /// Explicitly clear in-memory profile cache
  static void invalidateCache() {
    _cachedCurrentProfile = null;
    _cacheTimestamp = null;
  }

  Future<Profile?> getCurrentProfile({bool forceRefresh = false}) async {
    if (!SupabaseService.isInitialized) return null;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    if (!forceRefresh &&
        _cachedCurrentProfile != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedCurrentProfile;
    }

    try {
      // Profiles might match by id or user_id
      final response = await _client
          .from('profiles')
          .select(
            'id, user_id, first_name, last_name, headline, bio, house, grad_year, city, industry, company, avatar_url, banner_url, open_to_helping, looking_for',
          )
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();

      if (response != null) {
        var profile = Profile.fromJson(response);
        // Fallback banner check from user metadata or SharedPreferences if column not populated
        if (profile.bannerUrl == null || profile.bannerUrl!.isEmpty) {
          final fallbackBanner = await _getFallbackBanner(userId);
          if (fallbackBanner != null && fallbackBanner.isNotEmpty) {
            profile = profile.copyWith(bannerUrl: fallbackBanner);
          }
        }
        _cachedCurrentProfile = profile;
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
        bannerUrl: fallbackBanner,
        gradYear: meta?['grad_year'] != null
            ? int.tryParse(meta!['grad_year'].toString())
            : null,
      );
      _cachedCurrentProfile = placeholder;
      _cacheTimestamp = DateTime.now();
      return placeholder;
    } catch (e) {
      return _cachedCurrentProfile;
    }
  }

  Future<Profile?> getProfileById(String id) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final response = await _client
          .from('profiles')
          .select(
            'id, user_id, first_name, last_name, headline, bio, house, grad_year, city, industry, company, avatar_url, banner_url, open_to_helping, looking_for',
          )
          .or('id.eq.$id,user_id.eq.$id')
          .maybeSingle();

      if (response != null) {
        var profile = Profile.fromJson(response);
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
    String? bannerUrl,
    String? openToHelping,
    String? lookingFor,
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
      if (openToHelping != null) ...{
        'open_to_helping': openToHelping.trim(),
        'Open to helping': openToHelping.trim(),
      },
      if (lookingFor != null) ...{
        'looking_for': lookingFor.trim(),
        'Looking for': lookingFor.trim(),
      },
    };

    if (bannerUrl != null) {
      data['banner_url'] = bannerUrl.trim().isEmpty ? null : bannerUrl.trim();
    }

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
          if (openToHelping != null) 'open_to_helping': openToHelping.trim(),
          if (lookingFor != null) 'looking_for': lookingFor.trim(),
          if (bannerUrl != null)
            'banner_url': bannerUrl.trim().isEmpty ? null : bannerUrl.trim(),
        },
      ));
    } catch (_) {}

    // Check if a profile row exists matching this user's id or user_id
    final existing = await _client
        .from('profiles')
        .select('id, user_id')
        .or('id.eq.$userId,user_id.eq.$userId')
        .maybeSingle();

    try {
      if (existing != null) {
        await _client
            .from('profiles')
            .update(data)
            .or('id.eq.$userId,user_id.eq.$userId');
        invalidateCache();
        return;
      }

      // Check if there's a pre-imported record matching current user's email
      final userEmail = SupabaseService.currentUser?.email;
      if (userEmail != null && userEmail.trim().isNotEmpty) {
        final byEmail = await _client
            .from('profiles')
            .select('id, Email')
            .ilike('Email', userEmail.trim())
            .maybeSingle();

        if (byEmail != null) {
          await _client
              .from('profiles')
              .update({
                'id': userId,
                ...data,
              })
              .ilike('Email', userEmail.trim());
          invalidateCache();
          return;
        }
      }

      // Otherwise insert a new profile row
      await _client.from('profiles').insert({
        'id': userId,
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
    bool openToHelping = true,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final currentProfile = await getCurrentProfile();
    final firstName = (currentProfile?.firstName ??
            SupabaseService.currentUser?.userMetadata?['first_name']
                ?.toString() ??
            '')
        .trim();
    final lastName = (currentProfile?.lastName ??
            SupabaseService.currentUser?.userMetadata?['last_name']
                ?.toString() ??
            '')
        .trim();

    await updateProfile(
      firstName: firstName.isNotEmpty ? firstName : 'Old',
      lastName: lastName.isNotEmpty ? lastName : 'Boy',
      house: house,
      gradYear: gradYear,
      city: city,
      headline: headline,
      industry: industry,
      company: company,
      bio: bio,
      openToHelping: openToHelping ? 'true' : null,
    );

    // Save completion flag in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sp_onboarding_completed_$userId', true);
    } catch (_) {}
  }

  /// User skips onboarding for now
  Future<void> skipOnboarding() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool('sp_onboarding_completed_$userId');
      if (isCompleted == true) return false;

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

    // 4. Sign out
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
