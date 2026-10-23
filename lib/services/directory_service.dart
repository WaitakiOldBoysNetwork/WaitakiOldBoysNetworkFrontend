import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/connection.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class DirectoryService {
  SupabaseClient get _client => SupabaseService.client;

  /// Searches Old Boys across both registered accounts and imported records
  Future<List<Profile>> searchOldBoys({
    String? query,
    int? gradYear,
    String? city,
    int limit = 100,
  }) async {
    if (!SupabaseService.isInitialized) return [];
    var req = _client.from('profiles').select();

    if (gradYear != null) {
      req = req.or('grad_year.eq.$gradYear,"Year left School".eq.$gradYear');
    }

    if (city != null && city.trim().isNotEmpty) {
      final c = city.trim();
      req = req.or('city.ilike.%$c%,Region.ilike.%$c%');
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      req = req.or(
        'first_name.ilike.%$q%,last_name.ilike.%$q%,headline.ilike.%$q%,Name.ilike.%$q%,House.ilike.%$q%,Industry.ilike.%$q%',
      );
    }

    final raw = await req.limit(limit);
    final profiles = raw
        .map<Profile>((j) => Profile.fromJson(j))
        .where((p) => p.fullName.trim().isNotEmpty)
        .toList();

    // Sort: profiles with registered accounts first, then alphabetically
    profiles.sort((a, b) {
      final aHasUser = a.userId != null && a.userId!.trim().isNotEmpty;
      final bHasUser = b.userId != null && b.userId!.trim().isNotEmpty;
      if (aHasUser && !bHasUser) return -1;
      if (!aHasUser && bHasUser) return 1;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    return profiles;
  }

  /// Alias for backward compatibility
  Future<List<Profile>> searchAlumni({
    String? query,
    int? gradYear,
    String? city,
    int limit = 100,
  }) =>
      searchOldBoys(
        query: query,
        gradYear: gradYear,
        city: city,
        limit: limit,
      );

  Future<Map<String, Connection>> getMyConnections() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return {};

    final raw = await _client
        .from('connections')
        .select()
        .or('requester_id.eq.$userId,recipient_id.eq.$userId');

    final map = <String, Connection>{};
    for (final item in raw) {
      final conn = Connection.fromJson(item);
      final otherId = conn.requesterId == userId ? conn.recipientId : conn.requesterId;
      map[otherId] = conn;
    }
    return map;
  }

  Future<List<Connection>> getPendingRequestsForMe() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final raw = await _client
        .from('connections')
        .select()
        .eq('recipient_id', userId)
        .eq('status', 'pending');

    if (raw.isEmpty) return [];

    final requesterIds = raw
        .map((r) => r['requester_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    final profileMap = <String, Profile>{};
    if (requesterIds.isNotEmpty) {
      try {
        final profilesRes = await _client
            .from('profiles')
            .select()
            .filter('id', 'in', requesterIds);

        for (final p in profilesRes) {
          final profile = Profile.fromJson(p);
          profileMap[profile.id] = profile;
          if (profile.userId != null) profileMap[profile.userId!] = profile;
        }
      } catch (_) {}
    }

    return raw.map<Connection>((json) {
      final conn = Connection.fromJson(json);
      final requester = profileMap[conn.requesterId];
      return Connection(
        id: conn.id,
        requesterId: conn.requesterId,
        recipientId: conn.recipientId,
        status: conn.status,
        createdAt: conn.createdAt,
        updatedAt: conn.updatedAt,
        requester: requester,
      );
    }).toList();
  }

  Future<void> sendConnectionRequest(String recipientId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Must be logged in to connect');

    await _client.from('connections').insert({
      'requester_id': userId,
      'recipient_id': recipientId,
      'status': 'pending',
    });
  }

  Future<void> respondToConnectionRequest({
    required String connectionId,
    required ConnectionStatus status,
  }) async {
    await _client.from('connections').update({
      'status': status.toDbString(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', connectionId);
  }
}
