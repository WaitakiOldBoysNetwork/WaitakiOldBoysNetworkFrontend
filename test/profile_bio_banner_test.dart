import 'package:flutter_test/flutter_test.dart';
import 'package:waitaki_network/core/constants/supabase_config.dart';
import 'package:waitaki_network/models/profile.dart';

void main() {
  group('Profile Model - Bio and Banner', () {
    test('Profile constructor initializes bio and bannerUrl correctly', () {
      final profile = Profile(
        id: 'user-1',
        firstName: 'Charles',
        lastName: 'Brasch',
        bio: 'Waitaki Old Boy, poet, and patron of New Zealand arts.',
        bannerUrl: 'https://example.com/banner.jpg',
      );

      expect(profile.bio, equals('Waitaki Old Boy, poet, and patron of New Zealand arts.'));
      expect(profile.bannerUrl, equals('https://example.com/banner.jpg'));
      expect(profile.fullName, equals('Charles Brasch'));
    });

    test('Profile.fromJson parses standard bio and banner_url keys', () {
      final json = {
        'id': 'p-123',
        'first_name': 'James',
        'last_name': 'Hargest',
        'bio': 'WBHS alumni leader and brigadier.',
        'banner_url': 'https://storage.supabase.co/media/banners/banner1.png',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, equals('p-123'));
      expect(profile.bio, equals('WBHS alumni leader and brigadier.'));
      expect(profile.bannerUrl, equals('https://storage.supabase.co/media/banners/banner1.png'));
    });

    test('Profile.fromJson parses legacy Airtable Short Bio, Full Bio, and Banner Photo', () {
      final json1 = {
        'id': 'p-legacy-1',
        'Name': 'Denis Blundell',
        'Short Bio': 'Governor-General of New Zealand and Waitakian.',
        'Banner Photo': 'https://storage.supabase.co/media/banners/airtable_banner.jpg (attachment)',
      };

      final profile1 = Profile.fromJson(json1);
      expect(profile1.bio, equals('Governor-General of New Zealand and Waitakian.'));
      expect(profile1.bannerUrl, equals('https://storage.supabase.co/media/banners/airtable_banner.jpg'));

      final json2 = {
        'id': 'p-legacy-2',
        'Name': 'Frank Milner',
        'Full Bio': 'Long-standing rector of WBHS.',
        'banner': 'https://example.com/school_grounds.jpg',
      };

      final profile2 = Profile.fromJson(json2);
      expect(profile2.bio, equals('Long-standing rector of WBHS.'));
      expect(profile2.bannerUrl, equals('https://example.com/school_grounds.jpg'));
    });

    test('Profile.toJson includes bio and banner_url when present', () {
      final profile = Profile(
        id: 'p-json-test',
        firstName: 'John',
        lastName: 'Smith',
        bio: 'Passionate about mentoring young Waitakians.',
        bannerUrl: 'https://example.com/oamaru_stone.jpg',
      );

      final json = profile.toJson();

      expect(json['bio'], equals('Passionate about mentoring young Waitakians.'));
      expect(json['banner_url'], equals('https://example.com/oamaru_stone.jpg'));
    });

    test('Profile.copyWith accurately updates bio and bannerUrl', () {
      final original = Profile(
        id: 'p-copy',
        firstName: 'William',
        lastName: 'Stewart',
        bio: 'Old bio text',
        bannerUrl: 'https://example.com/old_banner.jpg',
      );

      final updated = original.copyWith(
        bio: 'Updated bio with new achievements',
        bannerUrl: 'https://example.com/new_banner.jpg',
      );

      expect(updated.id, equals('p-copy'));
      expect(updated.firstName, equals('William'));
      expect(updated.bio, equals('Updated bio with new achievements'));
      expect(updated.bannerUrl, equals('https://example.com/new_banner.jpg'));
      expect(original.bio, equals('Old bio text'));
    });
  });

  group('SupabaseConfig - Banner Storage', () {
    test('SupabaseConfig defines bannerFolder constant as banners', () {
      expect(SupabaseConfig.bannerFolder, equals('banners'));
      expect(SupabaseConfig.storageBucket, equals('media'));
    });
  });
}
