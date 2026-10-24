import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/auth_state.dart';
import '../../screens/auth/otp_verification_screen.dart';
import '../../screens/auth/unified_auth_screen.dart';
import '../../screens/home_navigation_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/unified_auth_service.dart';

import '../../screens/onboarding/onboarding_wizard_screen.dart';

/// Production-Grade Declarative GoRouter Configuration with Route Guards
/// Seamlessly redirects:
/// - Unauthenticated users -> /login
/// - Authenticated users with pending onboarding accessing /directory -> /onboarding
/// - Authenticated, fully onboarded users -> /directory or /home
class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/directory',
    refreshListenable: UnifiedAuthService(),
    redirect: _routeGuard,
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => UnifiedAuthScreen(
          onAuthSuccess: () {
            final authService = UnifiedAuthService();
            if (authService.state.status == UnifiedAuthStatus.onboardingRequired) {
              context.go('/onboarding');
            } else {
              context.go('/directory');
            }
          },
        ),
      ),
      GoRoute(
        path: '/verify-otp',
        name: 'verify-otp',
        builder: (context, state) {
          final phone = state.extra as String? ??
              UnifiedAuthService().state.phoneNumber ??
              '';
          return OtpVerificationScreen(
            phoneNumber: phone,
            onSuccess: () {
              final authService = UnifiedAuthService();
              if (authService.state.status == UnifiedAuthStatus.onboardingRequired) {
                context.go('/onboarding');
              } else {
                context.go('/directory');
              }
            },
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) {
          final authState = UnifiedAuthService().state;
          final step = authState.onboardingStep > 0 ? authState.onboardingStep : 1;
          return OnboardingWizardScreen(
            initialStep: step,
            onCompleted: () => context.go('/directory'),
          );
        },
      ),
      GoRoute(
        path: '/directory',
        name: 'directory',
        builder: (context, state) => const HomeNavigationScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeNavigationScreen(initialIndex: 0),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );

  /// Centralized Route Guard
  static String? _routeGuard(BuildContext context, GoRouterState state) {
    final authService = UnifiedAuthService();
    final authState = authService.state;

    final hasSupabaseSession = SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;
    final isAuthenticated = hasSupabaseSession || authState.isAuthenticated;

    final loc = state.matchedLocation;
    final isAuthRoute = loc == '/login' || loc == '/verify-otp';
    final isOnboardingRoute = loc == '/onboarding';

    // 1. Unauthenticated users cannot visit protected routes
    if (!isAuthenticated) {
      return isAuthRoute ? null : '/login';
    }

    // 2. Authenticated users who still require onboarding:
    // If they attempt to access /directory (or any protected app route), redirect to onboarding
    final needsOnboarding = authState.status == UnifiedAuthStatus.onboardingRequired;
    if (needsOnboarding) {
      return isOnboardingRoute ? null : '/onboarding';
    }

    // 3. Authenticated, onboarded users visiting login or onboarding get redirected to directory
    if (isAuthRoute || isOnboardingRoute) {
      return '/directory';
    }

    return null;
  }
}
