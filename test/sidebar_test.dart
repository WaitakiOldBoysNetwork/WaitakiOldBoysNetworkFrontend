import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waitaki_network/screens/home_navigation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sidebar and Branding Tests', () {
    testWidgets('Renders Sidebar with Crest Logo and Navigation Items in Expanded Mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeNavigationScreen(),
        ),
      );

      await tester.pump();

      // Verify the new logo crest is rendered
      final logoFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/logo.png',
      );
      expect(logoFinder, findsWidgets);

      // Verify sidebar branding text
      expect(find.text('Waitaki Old Boys'), findsWidgets);
      expect(find.textContaining('Network'), findsWidgets);

      // Verify navigation labels
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Directory'), findsOneWidget);
      expect(find.text('My Network'), findsWidgets);
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Share Post'), findsOneWidget);
    });

    testWidgets('Renders Compact Sidebar Centered with Crest Logo when collapsed', (tester) async {
      // Screen width below 900 triggers auto-compact mode (76px wide sidebar)
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeNavigationScreen(),
        ),
      );

      await tester.pump();

      // Verify logo image is present in compact sidebar
      final logoFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/logo.png',
      );
      expect(logoFinder, findsWidgets);

      // Verify Feed icon is present in compact mode
      expect(find.byIcon(Icons.feed_rounded), findsOneWidget);

      // Verify Share Post add icon is present in compact mode
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });
}
