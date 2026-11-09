import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waitaki_network/screens/auth/auth_screen.dart';

void main() {
  testWidgets('AuthScreen email confirmation dialog renders and requires explicit dismissal',
      (WidgetTester tester) async {
    // Provide adequate screen dimensions
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial screen has single Phone Number or Email input
    expect(find.text('Phone Number or Email'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Invoke the email confirmation dialog
    AuthScreen.showEmailConfirmationDialog(
      tester.element(find.byType(AuthScreen)),
      'oldboy@waitakibhs.school.nz',
    );
    await tester.pumpAndSettle();

    // Verify the large modal dialog appeared
    expect(find.text('Check Your Inbox'), findsOneWidget);
    expect(find.text('oldboy@waitakibhs.school.nz'), findsOneWidget);
    expect(find.text('Open the confirmation email in your inbox.'), findsOneWidget);
    expect(find.text('Click the verification link to activate your account.'), findsOneWidget);
    expect(find.text('Don’t see it? Please check your Spam or Junk folder.'), findsOneWidget);

    // Verify the dismissal button exists
    final dismissButton = find.text('Got It, I’ll Check My Email');
    expect(dismissButton, findsOneWidget);

    // Tapping the barrier background (top left outside dialog) should NOT dismiss it
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Check Your Inbox'), findsOneWidget);

    // Tapping the explicit dismissal button closes the dialog
    await tester.tap(dismissButton);
    await tester.pumpAndSettle();

    // Dialog is now gone
    expect(find.text('Check Your Inbox'), findsNothing);
  });

  testWidgets('AuthScreen single Phone Number or Email input validates input and routes to onboarding',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phone Number or Email'), findsOneWidget);

    final continueButton = find.text('Continue');
    expect(continueButton, findsOneWidget);

    // Enter a valid NZ phone number and tap Continue -> routes to onboarding with phone pre-filled
    final inputField = find.widgetWithText(TextFormField, 'Phone Number or Email');
    await tester.enterText(inputField, '021 123 4567');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Complete Your Profile Setup'), findsOneWidget);
    expect(find.text('021 123 4567'), findsOneWidget);
  });
}
