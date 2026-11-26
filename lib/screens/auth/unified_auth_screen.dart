import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../../services/unified_auth_service.dart';
import '../home_navigation_screen.dart';
import '../legal/legal_screens.dart';
import '../onboarding/onboarding_wizard_screen.dart';
import 'auth_gate.dart';
import 'auth_screen.dart';

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

    final hasAuthGate =
        context.findAncestorWidgetOfExactType<AuthGate>() != null;

    setState(() => _isLoading = true);
    try {
      final status = await _authService.checkAccountAndOnboardingStatus(input);
      if (!mounted) return;

      final isEmail = AuthService.isEmailInput(input);

      if (!status.hasAccount) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (routeContext) => OnboardingWizardScreen(
              initialEmail: isEmail ? input : status.email,
              initialPhone: !isEmail ? input : status.phone,
              isNewAccount: true,
              onCompleted: () {
                if (widget.onAuthSuccess != null) {
                  widget.onAuthSuccess!();
                } else if (hasAuthGate) {
                  Navigator.of(routeContext).popUntil((route) => route.isFirst);
                } else {
                  Navigator.of(routeContext).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          const HomeNavigationScreen(initialIndex: 0),
                    ),
                  );
                }
              },
            ),
          ),
        );
      } else if (!status.onboardingCompleted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (routeContext) => OnboardingWizardScreen(
              initialEmail: status.email ?? (isEmail ? input : null),
              initialPhone: status.phone ?? (!isEmail ? input : null),
              initialStep: status.onboardingStep,
              isNewAccount: false,
              onCompleted: () {
                if (widget.onAuthSuccess != null) {
                  widget.onAuthSuccess!();
                } else if (hasAuthGate) {
                  Navigator.of(routeContext).popUntil((route) => route.isFirst);
                } else {
                  Navigator.of(routeContext).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          const HomeNavigationScreen(initialIndex: 0),
                    ),
                  );
                }
              },
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
        SnackbarHelper.showError(context, AuthService.formatAuthError(e));
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

    final hasAuthGate =
        context.findAncestorWidgetOfExactType<AuthGate>() != null;
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);
    try {
      final res = await _authService.signInWithPassword(
        email: _resolvedEmail ?? input,
        password: password,
      );
      final userId = res.user?.id ?? SupabaseService.currentUserId;

      if (userId != null) {
        final isCompleted = await _authService.checkOnboardingCompleted(userId);
        if (isCompleted) {
          ProfileService.markOnboardingCompleted(userId);
          if (widget.onAuthSuccess != null) {
            widget.onAuthSuccess!();
          } else if (!hasAuthGate && mounted) {
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (_) => const HomeNavigationScreen(initialIndex: 0),
              ),
            );
          }
        } else if (!hasAuthGate && mounted) {
          final isEmail = AuthService.isEmailInput(input);
          final step = await _authService.getUserOnboardingStep(userId);
          if (!mounted) return;
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (routeContext) => OnboardingWizardScreen(
                initialEmail: _resolvedEmail ?? (isEmail ? input : null),
                initialPhone: !isEmail ? input : null,
                initialStep: step,
                onCompleted: () {
                  if (widget.onAuthSuccess != null) {
                    widget.onAuthSuccess!();
                  } else {
                    Navigator.of(routeContext).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            const HomeNavigationScreen(initialIndex: 0),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, AuthService.formatAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMagicLink() async {
    final input = (_resolvedEmail ?? _identifierController.text).trim();
    if (input.isEmpty || !input.contains('@')) {
      SnackbarHelper.showError(
        context,
        'No email address is linked to this phone number. Please sign in with your password or enter your email address.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendMagicLink(email: input);
      if (mounted) {
        await AuthScreen.showMagicLinkConfirmationDialog(
          context,
          input,
          onResend: () => _authService.sendMagicLink(email: input),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, AuthService.formatAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final input = (_resolvedEmail ?? _identifierController.text).trim();
    if (input.isEmpty || !input.contains('@')) {
      SnackbarHelper.showError(
        context,
        'Please enter your email address so we can send you a password reset link.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      try {
        await _authService.resetPassword(email: input);
      } catch (_) {
        await _authService.sendMagicLink(email: input);
      }
      if (mounted) {
        await AuthScreen.showMagicLinkConfirmationDialog(
          context,
          input,
          onResend: () async {
            try {
              await _authService.resetPassword(email: input);
            } catch (_) {
              await _authService.sendMagicLink(email: input);
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, AuthService.formatAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enteredText = _identifierController.text.trim();
    final isPhoneEntered =
        enteredText.isNotEmpty && !AuthService.isEmailInput(enteredText);
    final hasResolvedEmail =
        _resolvedEmail != null && _resolvedEmail!.contains('@');

    return ListenableBuilder(
      listenable: _unifiedAuthService,
      builder: (context, _) {
        final busy = _isLoading || _unifiedAuthService.state.isLoading;
        final isDark = AppColors.isDark(context);

        return Scaffold(
          backgroundColor: AppColors.bg(context),
          body: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: AppColors.line(context)),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
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

                          Text(
                            'Waitaki Old Boys',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading(context),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Old Boys Network • Quanti Est Sapere',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger(context),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!_showPasswordField) ...[
                            Text(
                              'Sign in or create a new account using your phone number or email address.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.subtext(context),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 18),
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
                                color: AppColors.cardMuted(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.line(context)),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            enteredText,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppColors.heading(context),
                                            ),
                                          ),
                                        ),
                                        if (isPhoneEntered &&
                                            hasResolvedEmail) ...[
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Account email: $_resolvedEmail',
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.subtext(context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20,
                                    color: AppColors.muted(context),
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    busy ? null : _handleForgotPassword,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
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
                          const SizedBox(height: 14),

                          if (_showPasswordField && hasResolvedEmail) ...[
                            OutlinedButton.icon(
                              onPressed: busy ? null : _handleMagicLink,
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: Text(
                                isPhoneEntered
                                    ? 'Email Magic Link ($_resolvedEmail)'
                                    : 'Send Me a Magic Link',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          Text(
                            !_showPasswordField
                                ? 'New here? Enter your phone number or email above and tap Continue to set up your profile.'
                                : 'Exclusively for Old Boys and staff of Waitaki Boys\' High School.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted(context),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
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
              Positioned(
                top: 12,
                right: 16,
                child: SafeArea(
                  child: IconButton.outlined(
                    tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                    onPressed: () => ThemeService().toggleTheme(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.card(context),
                      side: BorderSide(color: AppColors.line(context)),
                    ),
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20,
                      color: AppColors.heading(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
