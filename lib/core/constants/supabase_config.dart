import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for Supabase Backend
class SupabaseConfig {
  // Can be provided via `--dart-define=SUPABASE_URL=...` or replaced directly here:
  static const String _defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qehluoctztbjgtijhjir.supabase.co',
  );

  static const String _defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlaGx1b2N0enRiamd0aWpoamlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MTk4NjUsImV4cCI6MjEwODE5NTg2NX0.BmLMMLDYZqHIjHGLOnuVvkXcTYzrgz_oI7-_J0jxp3c',
  );

  static const String _prefsUrlKey = 'sp_supabase_url';
  static const String _prefsKeyKey = 'sp_supabase_anon_key';
  static const String _prefsPublishableKey = 'sp_supabase_publishable_key';

  static String _activeUrl = _defaultUrl;
  static String _activeAnonKey = _defaultAnonKey;

  static String get url => _activeUrl;

  /// Supabase API Key (backward-compatible with both publishableKey and legacy anonKey)
  static String get publishableKey => _activeAnonKey;
  static String get anonKey => _activeAnonKey;

  /// Check whether credentials have been customized away from defaults
  static bool get isConfigured {
    final u = _activeUrl.trim();
    final k = _activeAnonKey.trim();
    return u.isNotEmpty &&
        !u.contains('your-project-ref') &&
        k.isNotEmpty &&
        !k.contains('your-publishable-key') &&
        !k.contains('your-anon-key');
  }

  /// Load persisted credentials from SharedPreferences if any
  static Future<void> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsUrlKey);
      final savedKey =
          prefs.getString(_prefsPublishableKey) ??
          prefs.getString(_prefsKeyKey);

      if (savedUrl != null && savedUrl.isNotEmpty) {
        _activeUrl = savedUrl;
      }
      if (savedKey != null && savedKey.isNotEmpty) {
        _activeAnonKey = savedKey;
      }
    } catch (_) {}
  }

  /// Save runtime credentials (allows setting in-app without rebuilding)
  static Future<void> saveRuntimeCredentials({
    required String url,
    String? anonKey,
    String? publishableKey,
  }) async {
    _activeUrl = url.trim();
    _activeAnonKey = (publishableKey ?? anonKey ?? _activeAnonKey).trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUrlKey, _activeUrl);
    await prefs.setString(_prefsKeyKey, _activeAnonKey);
    await prefs.setString(_prefsPublishableKey, _activeAnonKey);
  }

  // Storage Bucket Name (as defined in Supabase)
  static const String storageBucket = 'media';
  static const String avatarFolder = 'avatars';
  static const String postFolder = 'posts';
}
