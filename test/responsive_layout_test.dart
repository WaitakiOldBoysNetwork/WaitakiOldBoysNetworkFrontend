import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waitaki_network/core/utils/responsive.dart';
import 'package:waitaki_network/models/connection.dart';
import 'package:waitaki_network/models/profile.dart';
import 'package:waitaki_network/screens/auth/auth_screen.dart';
import 'package:waitaki_network/screens/directory/widgets/old_boy_card.dart';
import 'package:waitaki_network/screens/feed/create_post_screen.dart';
import 'package:waitaki_network/screens/home_navigation_screen.dart';
import 'package:waitaki_network/screens/profile/edit_profile_screen.dart';
import 'package:waitaki_network/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Responsive Breakpoints Helper', () {
    test('Classifies mobile, tablet, and desktop widths accurately', () {
      expect(Responsive.isMobileWidth(390), isTrue);
      expect(Responsive.isTabletWidth(390), isFalse);
      expect(Responsive.isDesktopWidth(390), isFalse);

      expect(Responsive.isMobileWidth(679), isTrue);
      expect(Responsive.isMobileWidth(680), isFalse);
      expect(Responsive.isTabletWidth(680), isTrue);
      expect(Responsive.isTabletWidth(800), isTrue);
      expect(Responsive.isDesktopWidth(800), isFalse);

      expect(Responsive.isTabletWidth(959), isTrue);
      expect(Responsive.isTabletWidth(960), isFalse);
      expect(Responsive.isDesktopWidth(960), isTrue);
      expect(Responsive.isDesktopWidth(1280), isTrue);
    });
  });

  group('HomeNavigationScreen Adaptive Shell', () {
    testWidgets(
      'Uses bottom NavigationBar and FAB on 390x844 mobile and hides FAB on other tabs',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: HomeNavigationScreen(),
          ),
        );
        await tester.pump();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Share Post'), findsNothing);
        expect(find.byTooltip('Collapse sidebar'), findsNothing);
        expect(find.byTooltip('Expand sidebar'), findsNothing);
        expect(tester.takeException(), isNull);

        // Switch to Directory tab (index 1)
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Directory'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.takeException(), isNull);

        // Switch to Network tab (index 2)
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Network'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.takeException(), isNull);

        // Switch to Profile tab (index 3)
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Profile'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Uses compact sidebar rail on 800x900 tablet and full sidebar on 1280x900 desktop',
      (tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: HomeNavigationScreen(),
          ),
        );
        await tester.pump();

        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byIcon(Icons.feed_rounded), findsOneWidget);
        expect(find.text('Share Post'), findsNothing);
        expect(tester.takeException(), isNull);

        // Resize to desktop
        tester.view.physicalSize = const Size(1280, 900);
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('Share Post'), findsOneWidget);
        expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('EditProfileScreen Responsive Form Layout', () {
    final testProfile = Profile(
      id: 'p-resp-1',
      firstName: 'Frank',
      lastName: 'Milner',
      gradYear: 1930,
      house: 'Milner',
      company: 'Waitaki BHS',
      industry: 'Education & Academia',
    );

    testWidgets('Stacks paired fields vertically on 390x844 mobile', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(profile: testProfile),
        ),
      );
      await tester.pump();

      final firstNameRect = tester.getRect(
        find.widgetWithText(TextFormField, 'First Name'),
      );
      final lastNameRect = tester.getRect(
        find.widgetWithText(TextFormField, 'Last Name'),
      );
      expect(firstNameRect.top, lessThan(lastNameRect.top));

      final gradYearFinder =
          find.widgetWithText(TextFormField, 'Final Year / Class of');
      await tester.ensureVisible(gradYearFinder);
      final gradYearRect = tester.getRect(gradYearFinder);
      final houseRect = tester.getRect(
        find.widgetWithText(TextFormField, 'School House'),
      );
      expect(gradYearRect.top, lessThan(houseRect.top));

      final companyFinder =
          find.widgetWithText(TextFormField, 'Company / Organisation');
      await tester.ensureVisible(companyFinder);
      final companyRect = tester.getRect(companyFinder);
      final industryRect = tester.getRect(
        find.widgetWithText(TextFormField, 'Industry Sector'),
      );
      expect(companyRect.top, lessThan(industryRect.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Places paired fields side-by-side on 1280x900 desktop',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(profile: testProfile),
        ),
      );
      await tester.pump();

      final firstNameRect = tester.getRect(
        find.widgetWithText(TextFormField, 'First Name'),
      );
      final lastNameRect = tester.getRect(
        find.widgetWithText(TextFormField, 'Last Name'),
      );
      expect(firstNameRect.top, equals(lastNameRect.top));
      expect(firstNameRect.left, lessThan(lastNameRect.left));

      final gradYearRect = tester.getRect(
        find.widgetWithText(TextFormField, 'Final Year / Class of'),
      );
      final houseRect = tester.getRect(
        find.widgetWithText(TextFormField, 'School House'),
      );
      expect(gradYearRect.top, equals(houseRect.top));

      final companyRect = tester.getRect(
        find.widgetWithText(TextFormField, 'Company / Organisation'),
      );
      final industryRect = tester.getRect(
        find.widgetWithText(TextFormField, 'Industry Sector'),
      );
      expect(companyRect.top, equals(industryRect.top));
      expect(tester.takeException(), isNull);
    });
  });

  group('Mobile 390x844 Overflow Checks Across Screens', () {
    testWidgets('OldBoyCard with long fields renders cleanly on 390x844',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final longProfile = Profile(
        id: 'ob-long',
        firstName: 'Alexander',
        lastName: 'Bartholomew-Featherstonehaugh',
        gradYear: 2015,
        headline:
            'Principal Infrastructure Architect & Senior Advisory Consultant at Aotearoa Cloud Systems',
        city: 'Oamaru, Waitaki District, North Otago, New Zealand',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: OldBoyCard(
                profile: longProfile,
                connectionStatus: ConnectionStatus.none,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Connect'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileScreen renders cleanly on 390x844 mobile',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = Profile(
        id: 'p-mobile',
        firstName: 'Charles',
        lastName: 'Brasch',
        gradYear: 1926,
        headline: 'Editor, Poet & Patron of New Zealand Literature',
        city: 'Dunedin, Otago, New Zealand',
        house: 'Founders',
        bio: 'Waitaki Old Boy and founder of Landfall.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            userId: 'p-mobile',
            initialProfile: profile,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Charles Brasch'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CreatePostScreen renders cleanly on 390x844 mobile',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CreatePostScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Create Post'), findsOneWidget);
      expect(find.text('#Reunion2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AuthScreen renders cleanly on 390x844 mobile', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Waitaki Old Boys'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
