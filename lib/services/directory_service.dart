import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/connection.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class DirectoryService {
  final SupabaseClient _client = SupabaseService.client;

  /// Searches registered Old Boys who have accounts on the network
  Future<List<Profile>> searchOldBoys({
    String? query,
    int? gradYear,
    String? city,
    int limit = 100,
  }) async {
    // Only fetch users who have an active account on the network (user_id is not null)
    var req = _client.from('profiles').select().not('user_id', 'is', null);

    if (gradYear != null) {
      req = req.eq('grad_year', gradYear);
    }

    if (city != null && city.trim().isNotEmpty) {
      req = req.ilike('city', '%${city.trim()}%');
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      req = req.or(
        'first_name.ilike.%$q%,last_name.ilike.%$q%,headline.ilike.%$q%,Name.ilike.%$q%',
      );
    }

    final raw = await req.order('last_name', ascending: true).limit(limit);
    return raw
        .map<Profile>((j) => Profile.fromJson(j))
        .where((p) => p.userId != null && p.userId!.trim().isNotEmpty)
        .toList();
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
