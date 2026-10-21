import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for Supabase Backend
class SupabaseConfig {
  // Can be provided via `--dart-define=SUPABASE_URL=...` or replaced directly here:
  static const String _defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oalrktbzailfoeeptpvc.supabase.co',
  );

  static const String _defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hbHJrdGJ6YWlsZm9lZXB0cHZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1NjY1NDAsImV4cCI6MjEwODE0MjU0MH0.oUaHlvp0IuO9ILwcLjm9pLmMOfYR5wMSmsBI0q1P3-w',
  );

  static const String _prefsUrlKey = 'sp_supabase_url';
  static const String _prefsKeyKey = 'sp_supabase_anon_key';

  static String _activeUrl = _defaultUrl;
  static String _activeAnonKey = _defaultAnonKey;

  static String get url => _activeUrl;
  static String get anonKey => _activeAnonKey;

  /// Check whether credentials have been customized away from defaults
  static bool get isConfigured {
    final u = _activeUrl.trim();
    final k = _activeAnonKey.trim();
    return u.isNotEmpty &&
        !u.contains('your-project-ref') &&
        k.isNotEmpty &&
        !k.contains('your-anon-key');
  }

  /// Load persisted credentials from SharedPreferences if any
  static Future<void> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsUrlKey);
      final savedKey = prefs.getString(_prefsKeyKey);

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
    required String anonKey,
  }) async {
    _activeUrl = url.trim();
    _activeAnonKey = anonKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUrlKey, _activeUrl);
    await prefs.setString(_prefsKeyKey, _activeAnonKey);
  }

  // Storage Bucket Name (as defined in Supabase)
  static const String storageBucket = 'media';
  static const String avatarFolder = 'avatars';
  static const String postFolder = 'posts';
}
