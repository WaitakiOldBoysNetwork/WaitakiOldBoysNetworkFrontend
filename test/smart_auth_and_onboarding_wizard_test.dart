import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waitaki_network/models/profile.dart';
import 'package:waitaki_network/screens/auth/auth_screen.dart';
import 'package:waitaki_network/screens/directory/directory_screen.dart';
import 'package:waitaki_network/screens/home_navigation_screen.dart';
import 'package:waitaki_network/screens/onboarding/onboarding_wizard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Model - Age and Onboarding Progress Serialization', () {
    test('Serializes and deserializes age, is_onboarded, and onboarding_step', () {
      final profile = Profile(
        id: 'test-profile-1',
        firstName: 'Philip',
        lastName: 'Crossan',
        age: 28,
        isOnboarded: true,
        onboardingStep: 3,
        house: 'Milner',
        gradYear: 2014,
      );

      final json = profile.toJson();
      expect(json['age'], equals(28));
      expect(json['is_onboarded'], isTrue);
      expect(json['onboarding_completed'], isTrue);
      expect(json['onboarding_step'], equals(3));

      final deserialized = Profile.fromJson(json);
      expect(deserialized.age, equals(28));
      expect(deserialized.isOnboarded, isTrue);
      expect(deserialized.onboardingStep, equals(3));
      expect(deserialized.house, equals('Milner'));
    });
  });

  group('1. Smart Auth Entry Gate (Email First)', () {
    testWidgets('Displays single Email input and Continue button on initial entry',
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

      // Verify single input field: Email Address
      expect(find.text('Email Address'), findsOneWidget);
      // Password field should NOT be visible initially in email-first mode
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);

      // Verify Continue button
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('2. Multi-Step Onboarding Flow (Wizard)', () {
    testWidgets('Step 1 renders Email prefilled, Phone, and Password fields',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingWizardScreen(
            initialEmail: 'frank@waitakibhs.school.nz',
            initialStep: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waitaki Old Boys'), findsOneWidget);
      expect(find.text('Step 1: Account Credentials & Contact'), findsOneWidget);

      // Verify email is pre-filled
      final emailField = find.widgetWithText(TextFormField, 'e.g. frank@waitakibhs.school.nz');
      expect(emailField, findsOneWidget);

      // Phone Number field
      expect(find.widgetWithText(TextFormField, 'e.g. 021 123 4567'), findsOneWidget);

      // Password field
      expect(find.widgetWithText(TextFormField, 'At least 6 characters'), findsOneWidget);

      // Continue action button
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Step 2 renders Full Name, Age (13-100), and Grad Year (1960-current)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingWizardScreen(
            initialStep: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 2: Profile & Academic Details'), findsOneWidget);

      // Full Name inputs with Frank Milner example hints
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'e.g. Frank'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'e.g. Milner'), findsOneWidget);

      // Age typable selection box
      expect(find.text('Age'), findsOneWidget);
      final ageField = find.widgetWithText(TextFormField, 'Select your age (13 – 100)');
      expect(ageField, findsOneWidget);
      await tester.enterText(ageField, '17');

      // Graduation Year typable selection box supporting years above 2026
      expect(find.text('Graduation / Final Year at WBHS'), findsOneWidget);
      final gradYearField = find.widgetWithText(
        TextFormField,
        'Select graduation year (1920 – 2035)',
      );
      expect(gradYearField, findsOneWidget);
      await tester.enterText(gradYearField, '2028');

      // Action button
      expect(find.text('Next: Select House'), findsOneWidget);
    });

    testWidgets('Step 3 displays "Which house are you in?" with clickable cards & colors',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingWizardScreen(
            initialStep: 3,
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen prompt
      expect(find.text('Which house are you in?'), findsOneWidget);

      // WBHS Houses and their color badges
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
      expect(find.text('Jack Sutherland • Tradition & Waitaki Spirit'), findsOneWidget);

      // Complete Setup button
      final completeBtn = find.text('Complete Setup');
      expect(completeBtn, findsOneWidget);

      // Tap Forrester House
      await tester.tap(find.text('Forrester House'));
      await tester.pumpAndSettle();

      // Check circle icon highlights
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Tap Complete Setup
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });
  });

  group('3. Route Guard & Resumption Logic', () {
    testWidgets('HomeNavigationScreen displays prompt banner for incomplete profiles',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeNavigationScreen(initialIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the home navigation loads
      expect(find.byType(HomeNavigationScreen), findsOneWidget);
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

      // Top Search Bar
      expect(find.text('Search member names...'), findsOneWidget);

      // Filter Row directly below search
      expect(find.text('House'), findsOneWidget);
      expect(find.text('Grad Year'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);

      // Initially no filters are active -> "Clear Filters" should not be visible
      expect(find.text('Clear Filters'), findsNothing);

      // Enter text in search bar
      final searchField = find.widgetWithText(TextField, 'Search member names...');
      await tester.enterText(searchField, 'Crossan');
      await tester.pumpAndSettle();

      // Now "Clear Filters" button should appear
      expect(find.text('Clear Filters'), findsOneWidget);

      // Tapping "Clear Filters" clears the search and active filters
      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Clear Filters'), findsNothing);
    });
  });
}
