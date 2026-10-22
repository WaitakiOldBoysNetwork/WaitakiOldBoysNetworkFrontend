import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class ProfileService {
  final SupabaseClient _client = SupabaseService.client;

  Future<Profile?> getCurrentProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      // Profiles might match by id or user_id
      final response = await _client
          .from('profiles')
          .select()
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();

      if (response != null) {
        return Profile.fromJson(response);
      }

      // If no row exists yet (e.g. freshly created auth user before trigger completes),
      // build a placeholder profile from auth metadata
      final authUser = SupabaseService.currentUser;
      final meta = authUser?.userMetadata;
      return Profile(
        id: userId,
        userId: userId,
        firstName: meta?['first_name']?.toString() ?? '',
        lastName: meta?['last_name']?.toString() ?? '',
        gradYear: meta?['grad_year'] != null
            ? int.tryParse(meta!['grad_year'].toString())
            : null,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Profile?> getProfileById(String id) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .or('id.eq.$id,user_id.eq.$id')
          .maybeSingle();

      if (response != null) {
        return Profile.fromJson(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? headline,
    int? gradYear,
    String? city,
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
    };

    // 1. Check if a profile row exists matching this user's id or user_id
    final existing = await _client
        .from('profiles')
        .select('id, user_id')
        .or('id.eq.$userId,user_id.eq.$userId')
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('profiles')
          .update(data)
          .or('id.eq.$userId,user_id.eq.$userId');
      return;
    }

    // 2. Check if there's a pre-imported record matching current user's email
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
        return;
      }
    }

    // 3. Otherwise insert a new profile row
    await _client.from('profiles').insert({
      'id': userId,
      ...data,
    });
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

    return publicUrl;
  }
}
