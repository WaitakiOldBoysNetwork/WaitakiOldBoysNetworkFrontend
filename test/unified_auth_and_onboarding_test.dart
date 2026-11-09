import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waitaki_network/screens/auth/otp_verification_screen.dart';
import 'package:waitaki_network/screens/auth/unified_auth_screen.dart';
import 'package:waitaki_network/screens/onboarding/onboarding_flow_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UnifiedAuthScreen Widget Tests', () {
    testWidgets('Renders single Phone Number or Email input and Continue button', (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: UnifiedAuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header Branding
      expect(find.text('Waitaki Old Boys'), findsOneWidget);

      // Verify single Phone Number or Email input and Continue button
      expect(find.text('Phone Number or Email'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
    });
  });

  group('OtpVerificationScreen Widget Tests', () {
    testWidgets('Renders 6 PIN boxes and masked phone subtitle', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(
            phoneNumber: '+64211234567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter 6-Digit Code'), findsOneWidget);
      expect(find.text('Sent to +6421123••67'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);

      // Verify exactly 6 numeric PIN text fields are rendered
      expect(find.byType(TextFormField), findsNWidgets(6));
    });
  });

  group('OnboardingFlowScreen Widget Tests', () {
    testWidgets('Walks through 3 steps with PageView and multi-select chips', (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlowScreen(
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Profile Basics
      expect(find.text('Welcome! Let’s set up your profile'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // Enter full name
      final nameField = find.widgetWithText(TextFormField, 'Full Name');
      await tester.enterText(nameField, 'Angus MacLeod');
      await tester.pumpAndSettle();

      // Tap Continue to Step 2
      final continueBtn = find.text('Continue');
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 2: Interests
      expect(find.text('What are you interested in?'), findsOneWidget);
      expect(find.text('Step 2 of 3'), findsOneWidget);

      // Tap a chip to toggle it
      final rugbyChip = find.text('Sports & Rugby Fixtures');
      await tester.ensureVisible(rugbyChip);
      await tester.tap(rugbyChip);
      await tester.pumpAndSettle();

      // Advance to Step 3
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 3: Permissions
      expect(find.text('Stay connected with Waitaki'), findsOneWidget);
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Complete Setup'), findsOneWidget);

      // Tap Complete Setup
      await tester.tap(find.text('Complete Setup'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });
}
