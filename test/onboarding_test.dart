import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waitaki_network/models/profile.dart';
import 'package:waitaki_network/screens/onboarding/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Onboarding Profile Model Serialization', () {
    test('Profile serializes house, gradYear, city, headline, industry, and company', () {
      final profile = Profile(
        id: 'user-onboarding-1',
        firstName: 'Hamish',
        lastName: 'MacKenzie',
        gradYear: 2014,
        house: 'Don',
        city: 'Oamaru',
        headline: 'AgriTech Founder',
        industry: 'Agriculture & Technology',
        company: 'Waitaki Valley Wool Co',
        openToHelping: 'true',
      );

      final json = profile.toJson();

      expect(json['first_name'], equals('Hamish'));
      expect(json['last_name'], equals('MacKenzie'));
      expect(json['grad_year'], equals(2014));
      expect(json['house'], equals('Don'));
      expect(json['House'], equals('Don'));
      expect(json['city'], equals('Oamaru'));
      expect(json['headline'], equals('AgriTech Founder'));
      expect(json['industry'], equals('Agriculture & Technology'));
      expect(json['Industry'], equals('Agriculture & Technology'));
      expect(json['company'], equals('Waitaki Valley Wool Co'));
      expect(json['open_to_helping'], equals('true'));
    });

    test('Profile.fromJson parses house, city, headline, industry, and company accurately', () {
      final json = {
        'id': 'user-101',
        'first_name': 'David',
        'last_name': 'Sutherland',
        'Year left School': 2018,
        'House': 'Forrester',
        'Region': 'Wellington',
        'What are you up to': 'Senior Policy Advisor',
        'Industry': 'Government & Public Policy',
        'Company / Organisation': 'MFAT',
      };

      final profile = Profile.fromJson(json);

      expect(profile.firstName, equals('David'));
      expect(profile.lastName, equals('Sutherland'));
      expect(profile.gradYear, equals(2018));
      expect(profile.house, equals('Forrester'));
      expect(profile.city, equals('Wellington'));
      expect(profile.headline, equals('Senior Policy Advisor'));
      expect(profile.industry, equals('Government & Public Policy'));
      expect(profile.company, equals('MFAT'));
    });
  });

  group('OnboardingScreen Widget Tests', () {
    testWidgets('Renders Step 1 with WBHS Houses and Graduation Year', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingScreen(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Check header branding and title
      expect(find.text('Waitaki Old Boys'), findsOneWidget);
      expect(find.text('Your Waitaki Heritage'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);

      // Check all 7 WBHS Houses and their color badges are displayed
      expect(find.text('Don House'), findsOneWidget);
      expect(find.text('Green'), findsOneWidget);

      expect(find.text('Founders House'), findsOneWidget);
      expect(find.text('Grey'), findsOneWidget);

      expect(find.text('Forrester House'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);

      expect(find.text('Lee House'), findsOneWidget);
      expect(find.text('Yellow'), findsOneWidget);

      expect(find.text('Harkness House'), findsOneWidget);
      expect(find.text('Cyan'), findsOneWidget);

      expect(find.text('Milner House'), findsOneWidget);
      expect(find.text('Maroon'), findsOneWidget);

      expect(find.text('Sutherland House'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);

      // Check Graduation Year input
      expect(find.text('Graduation / Final Year at WBHS'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Tapping a House selects it in Step 1', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingScreen(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap 'Forrester House'
      final houseFinder = find.text('Forrester House');
      await tester.ensureVisible(houseFinder);
      await tester.tap(houseFinder);
      await tester.pump();

      // Verify check icon appears for selected house
      expect(find.byIcon(Icons.check_circle), findsWidgets);

      // Tap 'Sutherland House' (White)
      final sutherlandFinder = find.text('Sutherland House');
      await tester.ensureVisible(sutherlandFinder);
      await tester.tap(sutherlandFinder);
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });
  });
}
