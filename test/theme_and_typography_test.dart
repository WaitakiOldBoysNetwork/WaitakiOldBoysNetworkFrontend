import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waitaki_network/core/constants/app_colors.dart';
import 'package:waitaki_network/core/theme/app_theme.dart';
import 'package:waitaki_network/screens/home_navigation_screen.dart';
import 'package:waitaki_network/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeService().resetForTest();
  });

  tearDown(() {
    ThemeService().resetForTest();
  });

  group('Typography & Bundled Font Verification', () {
    test('All 5 static Inter TrueType font files exist with valid headers', () {
      const fontPaths = [
        'assets/fonts/Inter-Regular.ttf',
        'assets/fonts/Inter-Medium.ttf',
        'assets/fonts/Inter-SemiBold.ttf',
        'assets/fonts/Inter-Bold.ttf',
        'assets/fonts/Inter-ExtraBold.ttf',
      ];

      for (final path in fontPaths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Missing font file: $path');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(100000),
            reason: 'Font file unexpectedly small: $path');
        // TrueType sfnt version header: 0x00 0x01 0x00 0x00
        expect(bytes.sublist(0, 4), equals([0x00, 0x01, 0x00, 0x00]),
            reason: 'Invalid TrueType header in $path');
      }
    });

    test('Light and dark themes use Inter fontFamily and matching palettes', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.background);
      expect(AppTheme.lightTheme.textTheme.bodyLarge?.fontFamily, 'Inter');
      expect(AppTheme.lightTheme.textTheme.headlineLarge?.fontFamily, 'Inter');

      expect(AppTheme.darkTheme.brightness, Brightness.dark);
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(AppTheme.darkTheme.textTheme.bodyLarge?.fontFamily, 'Inter');
      expect(AppTheme.darkTheme.textTheme.headlineLarge?.fontFamily, 'Inter');
    });
  });

  group('ThemeService & Dark Mode Toggle', () {
    test('ThemeService defaults to light and persists dark/light toggles', () async {
      final service = ThemeService();
      expect(service.themeMode, ThemeMode.light);
      expect(service.isDark, isFalse);

      await service.toggleTheme();
      expect(service.themeMode, ThemeMode.dark);
      expect(service.isDark, isTrue);

      // Reset in-memory singleton and reload from SharedPreferences
      service.resetForTest();
      expect(service.isDark, isFalse);
      await service.loadSavedTheme();
      expect(service.themeMode, ThemeMode.dark);
      expect(service.isDark, isTrue);

      await service.toggleTheme();
      expect(service.themeMode, ThemeMode.light);
      expect(service.isDark, isFalse);
    });

    testWidgets(
      'Toggling Dark Mode in HomeNavigationScreen switches brightness and label',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final themeService = ThemeService();

        await tester.pumpWidget(
          ListenableBuilder(
            listenable: themeService,
            builder: (context, _) {
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeService.themeMode,
                home: const HomeNavigationScreen(),
              );
            },
          ),
        );

        await tester.pump();

        expect(
          Theme.of(tester.element(find.byType(HomeNavigationScreen))).brightness,
          Brightness.light,
        );
        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.text('Light Mode'), findsNothing);

        await tester.tap(find.text('Dark Mode'));
        await tester.pumpAndSettle();

        expect(
          Theme.of(tester.element(find.byType(HomeNavigationScreen))).brightness,
          Brightness.dark,
        );
        expect(find.text('Light Mode'), findsOneWidget);
        expect(find.text('Dark Mode'), findsNothing);

        await tester.tap(find.text('Light Mode'));
        await tester.pumpAndSettle();

        expect(
          Theme.of(tester.element(find.byType(HomeNavigationScreen))).brightness,
          Brightness.light,
        );
        expect(find.text('Dark Mode'), findsOneWidget);
      },
    );
  });
}
