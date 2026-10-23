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

  static User? get currentUser =>
      isInitialized ? client.auth.currentUser : null;

  static String? get currentUserId =>
      isInitialized ? client.auth.currentUser?.id : null;

  static bool get isAuthenticated =>
      isInitialized ? (client.auth.currentSession != null) : false;

  static Future<void> initialize() async {
    await SupabaseConfig.loadPersisted();

    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
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
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}
