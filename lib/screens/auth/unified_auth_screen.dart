import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/unified_auth_service.dart';
import '../home_navigation_screen.dart';
import '../legal/legal_screens.dart';
import '../onboarding/onboarding_wizard_screen.dart';

/// Unified Authentication Screen aligned with the single Phone number or Email entry
/// and flowchart routing:
/// - No account -> route straight to onboarding (pre-filling phone/email), log in automatically, and route to Main Feed (initialIndex: 0)
/// - Has account + finished onboarding -> show password input to log in, then route to Main Feed (initialIndex: 0)
/// - Has account + unfinished onboarding -> route directly to finish onboarding, then route to Main Feed (initialIndex: 0)
class UnifiedAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const UnifiedAuthScreen({super.key, this.onAuthSuccess});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> {
  final _unifiedAuthService = UnifiedAuthService();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showPasswordField = false;
  bool _obscurePassword = true;
  String? _resolvedEmail;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _routeToMainFeed() {
    if (widget.onAuthSuccess != null) {
      widget.onAuthSuccess!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeNavigationScreen(initialIndex: 0),
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_showPasswordField) {
      await _handleIdentifierContinue();
    } else {
      await _handlePasswordLogin();
    }
  }

  Future<void> _handleIdentifierContinue() async {
    final input = _identifierController.text.trim();
    if (!AuthService.isValidEmailOrPhone(input)) {
      SnackbarHelper.showError(
        context,
        'Please enter a valid phone number or email address',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final status = await _authService.checkAccountAndOnboardingStatus(input);
      if (!mounted) return;

      final isEmail = AuthService.isEmailInput(input);

      if (!status.hasAccount) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OnboardingWizardScreen(
              initialEmail: isEmail ? input : status.email,
              initialPhone: !isEmail ? input : status.phone,
              isNewAccount: true,
              onCompleted: _routeToMainFeed,
            ),
          ),
        );
      } else if (!status.onboardingCompleted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OnboardingWizardScreen(
              initialEmail: status.email ?? (isEmail ? input : null),
              initialPhone: status.phone ?? (!isEmail ? input : null),
              initialStep: status.onboardingStep,
              isNewAccount: false,
              onCompleted: _routeToMainFeed,
            ),
          ),
        );
      } else {
        setState(() {
          _showPasswordField = true;
          _resolvedEmail = status.email ?? (isEmail ? input : null);
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error checking account: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordLogin() async {
    final input = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter your password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _authService.signInWithPassword(
        email: _resolvedEmail ?? input,
        password: password,
      );
      final userId = res.user?.id ?? SupabaseService.currentUserId;

      if (userId != null && mounted) {
        final isCompleted = await _authService.checkOnboardingCompleted(userId);
        if (!mounted) return;
        if (isCompleted) {
          _routeToMainFeed();
        } else {
          final isEmail = AuthService.isEmailInput(input);
          final step = await _authService.getUserOnboardingStep(userId);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OnboardingWizardScreen(
                initialEmail: _resolvedEmail ?? (isEmail ? input : null),
                initialPhone: !isEmail ? input : null,
                initialStep: step,
                onCompleted: _routeToMainFeed,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e is AuthException ? e.message : e.toString();
        SnackbarHelper.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _unifiedAuthService,
      builder: (context, _) {
        final busy = _isLoading || _unifiedAuthService.state.isLoading;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Crest / Logo
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 68,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Container(
                                width: 68,
                                height: 68,
                                decoration: const BoxDecoration(
                                  color: AppColors.navyPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: AppColors.goldAccent,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Waitaki Old Boys',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navyDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Old Boys Network • Qaunti Est Sapere',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.crimson,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 28),

                          if (!_showPasswordField) ...[
                            TextFormField(
                              controller: _identifierController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleSubmit(),
                              decoration: const InputDecoration(
                                labelText: 'Phone Number or Email',
                                hintText:
                                    'e.g. 021 123 4567 or oldboy@waitakibhs.school.nz',
                                prefixIcon: Icon(
                                  Icons.contact_mail_outlined,
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v == null ||
                                    !AuthService.isValidEmailOrPhone(v)) {
                                  return 'Enter a valid phone number or email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                          ],

                          if (_showPasswordField) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF16A34A),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _identifierController.text.trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.navyDark,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showPasswordField = false;
                                        _resolvedEmail = null;
                                        _passwordController.clear();
                                      });
                                    },
                                    child: const Text(
                                      'Change',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleSubmit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Primary Action Button
                          ElevatedButton(
                            onPressed: busy ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    !_showPasswordField ? 'Continue' : 'Log In',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          const LegalLinksFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
