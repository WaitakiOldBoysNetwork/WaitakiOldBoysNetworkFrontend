import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waitaki_network/models/profile.dart';
import 'package:waitaki_network/screens/profile/edit_profile_screen.dart';
import 'package:waitaki_network/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = Profile(
    id: 'user-del-test-123',
    userId: 'user-del-test-123',
    firstName: 'John',
    lastName: 'TestBoy',
    headline: 'Senior Engineer',
    gradYear: 2012,
    city: 'Oamaru',
    house: 'Don',
    bio: 'Test bio description',
  );

  group('Delete Account Feature Tests', () {
    test('ProfileService.deleteAccount returns safely when offline/uninitialized', () async {
      final service = ProfileService();
      // Should not throw unhandled exception when offline or uninitialized
      await expectLater(service.deleteAccount(), completes);
    });

    testWidgets('EditProfileScreen renders Danger Zone and Delete Account button', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditProfileScreen(profile: testProfile),
          ),
        ),
      );

      await tester.pump();

      // Scroll to bottom to view Danger Zone
      final deleteBtnFinder = find.text('Delete Account');
      await tester.ensureVisible(deleteBtnFinder);

      expect(find.text('Danger Zone'), findsOneWidget);
      expect(deleteBtnFinder, findsOneWidget);
    });

    testWidgets('Tapping Delete Account opens confirmation dialog with cancel option', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditProfileScreen(profile: testProfile),
          ),
        ),
      );

      await tester.pump();

      // Scroll to and tap Delete Account
      final deleteBtnFinder = find.text('Delete Account');
      await tester.ensureVisible(deleteBtnFinder);
      await tester.tap(deleteBtnFinder);
      await tester.pump();

      // Verify confirmation dialog appears
      expect(find.text('Delete Account?'), findsOneWidget);
      expect(find.text('Permanently Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Verify dialog is dismissed and we are still on EditProfileScreen
      expect(find.text('Delete Account?'), findsNothing);
      expect(find.text('Edit Profile'), findsOneWidget);
    });
  });
}
