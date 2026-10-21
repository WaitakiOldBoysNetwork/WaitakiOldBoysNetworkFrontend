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

    final data = {
      'user_id': userId,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'headline': headline?.trim(),
      'grad_year': gradYear,
      'city': city?.trim(),
    };

    // Upsert into public.profiles
    await _client.from('profiles').upsert(
      {
        'id': userId,
        ...data,
      },
      onConflict: 'id',
    );
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

    // Save avatar_url to profiles table
    await _client.from('profiles').upsert(
      {
        'id': userId,
        'user_id': userId,
        'avatar_url': publicUrl,
      },
      onConflict: 'id',
    );

    return publicUrl;
  }
}
