import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if configured via env, file, or preferences
  await SupabaseService.initialize();

  runApp(const WaitakiAlumniApp());
}

class WaitakiAlumniApp extends StatelessWidget {
  const WaitakiAlumniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waitaki Old Boys\' Network',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}
