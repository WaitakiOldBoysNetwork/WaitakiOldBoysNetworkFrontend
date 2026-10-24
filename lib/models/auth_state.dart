import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents the status of the unified authentication flow
enum UnifiedAuthStatus {
  initial,
  loading,
  otpSent,
  authenticated,
  onboardingRequired,
  error,
}

/// Unified authentication state model containing all relevant state
class UnifiedAuthState {
  final UnifiedAuthStatus status;
  final User? user;
  final String? phoneNumber;
  final String? email;
  final String? errorMessage;
  final int resendCountdown;
  final bool isEmailMode;
  final int onboardingStep;

  const UnifiedAuthState({
    this.status = UnifiedAuthStatus.initial,
    this.user,
    this.phoneNumber,
    this.email,
    this.errorMessage,
    this.resendCountdown = 0,
    this.isEmailMode = true,
    this.onboardingStep = 0,
  });

  bool get isLoading => status == UnifiedAuthStatus.loading;
  bool get isAuthenticated => status == UnifiedAuthStatus.authenticated;
  bool get isOtpSent => status == UnifiedAuthStatus.otpSent;
  bool get canResendOtp => resendCountdown <= 0 && !isLoading;

  UnifiedAuthState copyWith({
    UnifiedAuthStatus? status,
    User? user,
    String? phoneNumber,
    String? email,
    String? errorMessage,
    int? resendCountdown,
    bool? isEmailMode,
    int? onboardingStep,
    bool clearError = false,
  }) {
    return UnifiedAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resendCountdown: resendCountdown ?? this.resendCountdown,
      isEmailMode: isEmailMode ?? this.isEmailMode,
      onboardingStep: onboardingStep ?? this.onboardingStep,
    );
  }
}
