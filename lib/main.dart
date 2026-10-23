import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if configured via env, file, or preferences
  await SupabaseService.initialize();

  runApp(const WaitakiOldBoysApp());
}

class WaitakiOldBoysApp extends StatelessWidget {
  const WaitakiOldBoysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waitaki Old Boys\' Network',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
  }
}

/// Backward compatibility alias
typedef WaitakiAlumniApp = WaitakiOldBoysApp;
