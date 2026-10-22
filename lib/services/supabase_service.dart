import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_config.dart';

class SupabaseService {
  static bool get isInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static String? get currentUserId => client.auth.currentUser?.id;

  static bool get isAuthenticated => client.auth.currentSession != null;

  static Future<void> initialize() async {
    await SupabaseConfig.loadPersisted();

    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
    }
  }

  static Future<void> reinitializeWith({
    required String url,
    String? publishableKey,
    @Deprecated('Use publishableKey instead') String? anonKey,
  }) async {
    final key = (publishableKey ?? anonKey ?? '').trim();
    await SupabaseConfig.saveRuntimeCredentials(
      url: url,
      anonKey: key,
      publishableKey: key,
    );
    await Supabase.initialize(url: url, publishableKey: key);
  }
}
