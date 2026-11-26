import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';
import 'services/supabase_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase and load persisted theme preference
  await SupabaseService.initialize();
  await ThemeService().loadSavedTheme();

  runApp(const WaitakiOldBoysApp());
}

class WaitakiOldBoysApp extends StatelessWidget {
  const WaitakiOldBoysApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Waitaki Old Boys\' Network',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Backward compatibility alias
typedef WaitakiAlumniApp = WaitakiOldBoysApp;
