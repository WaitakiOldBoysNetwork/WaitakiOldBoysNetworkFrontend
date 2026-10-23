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

    // Verify initial screen is Sign In
    expect(find.text('Sign In'), findsWidgets);

    // Switch to Register (Sign Up) tab
    final signUpTab = find.text('Register');
    expect(signUpTab, findsOneWidget);
    await tester.tap(signUpTab);
    await tester.pumpAndSettle();

    // Find the state to trigger the confirmation dialog
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
}
