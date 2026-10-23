import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for Supabase Backend optimized for Desktop & Web
class SupabaseConfig {
  // Can be provided via `--dart-define=SUPABASE_URL=...` or replaced directly here:
  static const String _defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qehluoctztbjgtijhjir.supabase.co',
  );

  // Modern publishable key support with backward compatibility for legacy anon key
  static const String _defaultPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlaGx1b2N0enRiamd0aWpoamlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MTk4NjUsImV4cCI6MjEwODE5NTg2NX0.BmLMMLDYZqHIjHGLOnuVvkXcTYzrgz_oI7-_J0jxp3c',
    ),
  );

  static const String _prefsUrlKey = 'sp_supabase_url';
  static const String _prefsKeyKey = 'sp_supabase_anon_key';
  static const String _prefsPublishableKey = 'sp_supabase_publishable_key';

  static String _activeUrl = _sanitizeUrl(_defaultUrl);
  static String _activeKey = _defaultPublishableKey;

  /// Clean and normalize URL (trims whitespace and removes trailing slashes)
  static String _sanitizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Active Supabase Project URL
  static String get url => _activeUrl;

  /// Supabase API Key (backward-compatible with both publishableKey and legacy anonKey)
  static String get publishableKey => _activeKey;
  static String get anonKey => _activeKey;

  /// Check whether credentials have been customized away from placeholder defaults
  static bool get isConfigured {
    final u = _activeUrl.trim();
    final k = _activeKey.trim();
    return u.isNotEmpty &&
        !u.contains('your-project-ref') &&
        k.isNotEmpty &&
        !k.contains('your-publishable-key') &&
        !k.contains('your-anon-key');
  }

  /// Returns true if running in a web browser
  static bool get isWeb => kIsWeb;

  /// Returns true if running on native desktop (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Production web hosting URL on GitHub Pages
  static const String productionWebUrl = String.fromEnvironment(
    'APP_WEB_URL',
    defaultValue:
        'https://waitakioldboysnetwork.github.io/WaitakiOldBoysNetworkFrontend/',
  );

  /// Authentication callback / redirect URL for OAuth, Email Confirmation, and Magic Links.
  /// Strictly points to production GitHub Pages URL to prevent localhost redirect leaks.
  static String get authCallbackUrl => productionWebUrl;

  /// Load persisted credentials from SharedPreferences, with support for Web URL query parameter overrides
  static Future<void> loadPersisted() async {
    // 1. On Web, check if credentials were provided via URL query parameters (e.g. ?supabase_url=...&supabase_key=...)
    if (kIsWeb) {
      try {
        final queryParams = Uri.base.queryParameters;
        final queryUrl = queryParams['supabase_url'] ?? queryParams['url'];
        final queryKey = queryParams['supabase_publishable_key'] ??
            queryParams['supabase_key'] ??
            queryParams['publishable_key'] ??
            queryParams['key'];

        if (queryUrl != null && queryUrl.isNotEmpty) {
          _activeUrl = _sanitizeUrl(queryUrl);
        }
        if (queryKey != null && queryKey.isNotEmpty) {
          _activeKey = queryKey.trim();
        }

        // If credentials came via URL query parameters, save them to preferences as well
        if ((queryUrl != null && queryUrl.isNotEmpty) ||
            (queryKey != null && queryKey.isNotEmpty)) {
          await saveRuntimeCredentials(
            url: _activeUrl,
            publishableKey: _activeKey,
          );
          return;
        }
      } catch (_) {}
    }

    // 2. Load persisted credentials from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsUrlKey);
      final savedKey = prefs.getString(_prefsPublishableKey) ??
          prefs.getString(_prefsKeyKey);

      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _activeUrl = _sanitizeUrl(savedUrl);
      }
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _activeKey = savedKey.trim();
      }
    } catch (_) {
      // Safe fallback for web browsers in private/restricted mode where localStorage may fail
    }
  }

  /// Save runtime credentials (allows setting in-app or via setup screen without rebuilding)
  static Future<void> saveRuntimeCredentials({
    required String url,
    String? anonKey,
    String? publishableKey,
  }) async {
    _activeUrl = _sanitizeUrl(url);
    _activeKey = (publishableKey ?? anonKey ?? _activeKey).trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUrlKey, _activeUrl);
      await prefs.setString(_prefsKeyKey, _activeKey);
      await prefs.setString(_prefsPublishableKey, _activeKey);
    } catch (_) {
      // Safe fallback if local storage is restricted
    }
  }

  /// Storage Bucket and Folder Names
  static const String storageBucket = 'media';
  static const String avatarFolder = 'avatars';
  static const String bannerFolder = 'banners';
  static const String postFolder = 'posts';
}
