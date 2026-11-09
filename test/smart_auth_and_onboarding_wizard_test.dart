import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waitaki_network/models/profile.dart';
import 'package:waitaki_network/screens/auth/auth_screen.dart';
import 'package:waitaki_network/screens/directory/directory_screen.dart';
import 'package:waitaki_network/screens/home_navigation_screen.dart';
import 'package:waitaki_network/screens/onboarding/onboarding_wizard_screen.dart';
import 'package:waitaki_network/screens/profile/edit_profile_screen.dart';
import 'package:waitaki_network/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Model - Age, Share Phone, and Onboarding Serialization', () {
    test('Serializes and deserializes age, share_phone_on_profile, is_onboarded, and onboarding_step', () {
      final profile = Profile(
        id: 'test-profile-1',
        firstName: 'Philip',
        lastName: 'Crossan',
        age: 28,
        phone: '021 123 4567',
        sharePhoneOnProfile: true,
        isOnboarded: true,
        onboardingStep: 1,
        house: 'Milner',
      );

      final json = profile.toJson();
      expect(json['age'], equals(28));
      expect(json['share_phone_on_profile'], isTrue);
      expect(json['is_onboarded'], isTrue);
      expect(json['onboarding_completed'], isTrue);
      expect(json['onboarding_step'], equals(1));

      final deserialized = Profile.fromJson(json);
      expect(deserialized.age, equals(28));
      expect(deserialized.sharePhoneOnProfile, isTrue);
      expect(deserialized.isOnboarded, isTrue);
      expect(deserialized.onboardingStep, equals(1));
      expect(deserialized.house, equals('Milner'));
    });
  });

  group('1. Single Phone/Email Auth Entry Gate', () {
    testWidgets('Displays single Phone Number or Email input and Continue button without Sign In/Register switcher',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify single input field: Phone Number or Email
      expect(find.text('Phone Number or Email'), findsOneWidget);
      // Verify Sign In / Register switcher and Password field are NOT shown initially
      expect(find.text('Register'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);

      // Verify Continue button
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('2. Simplified Consolidated Onboarding (No Grad Year)', () {
    testWidgets('Renders Name, Age, Phone Number, Share my contact info toggle, and credentials without Graduation Year',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingWizardScreen(
            initialEmail: 'frank@waitakibhs.school.nz',
            isNewAccount: true,
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waitaki Old Boys'), findsOneWidget);
      expect(find.text('Complete Your Profile Setup'), findsOneWidget);

      // Verify Name, Age, Phone Number, and Share my contact info toggle exist
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Share my contact info'), findsOneWidget);

      // Verify Graduation Year is NOT present anywhere
      expect(find.textContaining('Graduation'), findsNothing);

      // Fill out the consolidated onboarding form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Frank'),
        'Frank',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Milner'),
        'Milner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Select your age (13 – 100)'),
        '25',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 021 123 4567'),
        '021 123 4567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 6 characters'),
        'Waitaki1883!',
      );

      // Toggle "Share my contact info"
      await tester.tap(find.text('Share my contact info'));
      await tester.pumpAndSettle();

      // Tap Complete Setup
      final completeBtn = find.text('Complete Setup');
      await tester.ensureVisible(completeBtn);
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });

  group('3. Profile Contact Visibility Enforcement', () {
    testWidgets('ProfileScreen hides email and phone when sharePhoneOnProfile is false and shows both when true',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hiddenContactProfile = Profile(
        id: 'p-1',
        firstName: 'Ian',
        lastName: 'Milner',
        email: 'ian@waitakibhs.school.nz',
        phone: '021 999 8888',
        sharePhoneOnProfile: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            userId: 'p-1',
            initialProfile: hiddenContactProfile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ian@waitakibhs.school.nz'), findsNothing);
      expect(find.text('021 999 8888'), findsNothing);

      final visibleContactProfile = hiddenContactProfile.copyWith(
        sharePhoneOnProfile: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            userId: 'p-1',
            initialProfile: visibleContactProfile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ian@waitakibhs.school.nz'), findsOneWidget);
      expect(find.text('021 999 8888'), findsOneWidget);
    });

    testWidgets('EditProfileScreen exposes Share my contact info toggle',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = Profile(
        id: 'p-2',
        firstName: 'Frank',
        lastName: 'Milner',
        phone: '021 555 4444',
        sharePhoneOnProfile: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(profile: profile),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share my contact info'), findsOneWidget);
    });
  });

  group('4. Directory Search & Filters', () {
    testWidgets('DirectoryScreen renders Search bar, House, Grad Year, Age filters',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DirectoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search member names...'), findsOneWidget);
      expect(find.text('House'), findsOneWidget);
      expect(find.text('Grad Year'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);

      expect(find.byType(HomeNavigationScreen), findsNothing);
    });
  });
}
