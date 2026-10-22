import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waitaki_network/core/constants/supabase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SupabaseConfig', () {
    test('publishableKey and deprecated anonKey return matching value', () {
      expect(SupabaseConfig.publishableKey, isNotEmpty);
      // ignore: deprecated_member_use_from_same_package
      expect(SupabaseConfig.anonKey, equals(SupabaseConfig.publishableKey));
    });

    test('saveRuntimeCredentials updates publishableKey and writes to preferences', () async {
      const testUrl = 'https://exampleproject.supabase.co';
      const testKey = 'sb_publishable_test1234567890abcdef';

      await SupabaseConfig.saveRuntimeCredentials(
        url: testUrl,
        publishableKey: testKey,
      );

      expect(SupabaseConfig.url, equals(testUrl));
      expect(SupabaseConfig.publishableKey, equals(testKey));
      // ignore: deprecated_member_use_from_same_package
      expect(SupabaseConfig.anonKey, equals(testKey));
      expect(SupabaseConfig.isConfigured, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sp_supabase_url'), equals(testUrl));
      expect(prefs.getString('sp_supabase_publishable_key'), equals(testKey));
    });

    test('loadPersisted supports legacy sp_supabase_anon_key if publishable key is not set', () async {
      const legacyUrl = 'https://legacyproject.supabase.co';
      const legacyKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.legacy';

      SharedPreferences.setMockInitialValues({
        'sp_supabase_url': legacyUrl,
        'sp_supabase_anon_key': legacyKey,
      });

      await SupabaseConfig.loadPersisted();

      expect(SupabaseConfig.url, equals(legacyUrl));
      expect(SupabaseConfig.publishableKey, equals(legacyKey));
      // ignore: deprecated_member_use_from_same_package
      expect(SupabaseConfig.anonKey, equals(legacyKey));
    });

    test('loadPersisted prioritizes modern publishable key over legacy anon key', () async {
      const modernUrl = 'https://modernproject.supabase.co';
      const modernKey = 'sb_publishable_modern12345';
      const oldKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.old';

      SharedPreferences.setMockInitialValues({
        'sp_supabase_url': modernUrl,
        'sp_supabase_publishable_key': modernKey,
        'sp_supabase_anon_key': oldKey,
      });

      await SupabaseConfig.loadPersisted();

      expect(SupabaseConfig.url, equals(modernUrl));
      expect(SupabaseConfig.publishableKey, equals(modernKey));
    });
  });
}
