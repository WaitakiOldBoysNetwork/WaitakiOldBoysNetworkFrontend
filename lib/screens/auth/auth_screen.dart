import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../home_navigation_screen.dart';
import '../legal/legal_screens.dart';
import '../onboarding/onboarding_wizard_screen.dart';
import 'auth_gate.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  static Future<void> showEmailConfirmationDialog(
    BuildContext context,
    String email, {
    VoidCallback? onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: EmailConfirmationDialog(
          email: email,
          onDismiss: () {
            Navigator.of(dialogContext).pop();
            onDismiss?.call();
          },
        ),
      ),
    );
  }

  static Future<void> showMagicLinkConfirmationDialog(
    BuildContext context,
    String email, {
    VoidCallback? onDismiss,
    Future<void> Function()? onResend,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => MagicLinkConfirmationDialog(
        email: email,
        onResend: onResend,
        onDismiss: () {
          Navigator.of(dialogContext).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Smart Auth Entry Gate State
  bool _showPasswordField = false;
  String? _resolvedEmail;

  // Controllers
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

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

  /// Step 1 of Flowchart Auth Entry: Single Phone number or Email check
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
        // 1. No account -> route straight to onboarding (pre-filling entered phone/email),
        // log in automatically on completion, and route to Main Feed (initialIndex: 0).
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (routeContext) => OnboardingWizardScreen(
              initialEmail: isEmail ? input : status.email,
              initialPhone: !isEmail ? input : status.phone,
              isNewAccount: true,
              onCompleted: () {
                if (hasAuthGate) {
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
        // 2. Has account + unfinished onboarding -> route directly to finish onboarding,
        // then route to Main Feed (initialIndex: 0).
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (routeContext) => OnboardingWizardScreen(
              initialEmail: status.email ?? (isEmail ? input : null),
              initialPhone: status.phone ?? (!isEmail ? input : null),
              initialStep: status.onboardingStep,
              isNewAccount: false,
              onCompleted: () {
                if (hasAuthGate) {
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
        // 3. Has account + finished onboarding -> show the password input to log in
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

  /// Step 2 of Flowchart Auth Entry: Password Login -> Main Feed (initialIndex: 0)
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
          if (!hasAuthGate && mounted) {
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
                  Navigator.of(routeContext).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          const HomeNavigationScreen(initialIndex: 0),
                    ),
                  );
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
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
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
                          // Header & WBHS Crest Representation
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 72,
                              fit: BoxFit.contain,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.danger(context),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Single Phone Number or Email Input (when not yet verified)
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

                          // Confirmed Phone/Email + Change link & Password Field
                          if (_showPasswordField) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardMuted(context),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AppColors.line(context)),
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
                                                color:
                                                    AppColors.subtext(context),
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
                                    _isLoading ? null : _handleForgotPassword,
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

                          // Primary Continue / Log In Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isLoading
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

                          // Magic Link Option when an email is available
                          if (_showPasswordField && hasResolvedEmail) ...[
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleMagicLink,
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

                          // Info text
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
            top: 16,
            right: 16,
            child: SafeArea(
              child: IconButton.outlined(
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () => ThemeService().toggleTheme(),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large, un-dismissible popup modal dialog alerting new users to check their email
/// for account verification before signing in.
class EmailConfirmationDialog extends StatelessWidget {
  final String email;
  final VoidCallback? onDismiss;

  const EmailConfirmationDialog({
    super.key,
    required this.email,
    this.onDismiss,
  });

  Widget _buildStepRow(
      BuildContext context, {required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.brandLink(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subtext(context),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 16,
      backgroundColor: AppColors.card(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon badge with WBHS Navy & Gold styling
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navyPrimary, AppColors.navyDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navyPrimary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    size: 36,
                    color: AppColors.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Check Your Inbox',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heading(context),
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                'A verification email has been dispatched to activate your Waitaki Old Boys Network account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColors.subtext(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Recipient email pill card (scales down cleanly on mobile without truncating)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.brand(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brand(context).withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mail_rounded,
                      size: 18,
                      color: AppColors.brandLink(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          email,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandLink(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Steps checklist card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line(context)),
                ),
                child: Column(
                  children: [
                    _buildStepRow(
                      context,
                      icon: Icons.filter_1_rounded,
                      text: 'Open the confirmation email in your inbox.',
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow(
                      context,
                      icon: Icons.filter_2_rounded,
                      text:
                          'Click the verification link to activate your account.',
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow(
                      context,
                      icon: Icons.filter_3_rounded,
                      text:
                          'Return to this app and sign in with your password.',
                    ),
                    Divider(height: 18, color: AppColors.line(context)),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.goldDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Don’t see it? Please check your Spam or Junk folder.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.subtext(context),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Dismiss button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onDismiss ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got It, I’ll Check My Email',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal dialog alerting user that a password-free magic link has been sent.
class MagicLinkConfirmationDialog extends StatefulWidget {
  final String email;
  final VoidCallback? onDismiss;
  final Future<void> Function()? onResend;

  const MagicLinkConfirmationDialog({
    super.key,
    required this.email,
    this.onDismiss,
    this.onResend,
  });

  @override
  State<MagicLinkConfirmationDialog> createState() =>
      _MagicLinkConfirmationDialogState();
}

class _MagicLinkConfirmationDialogState
    extends State<MagicLinkConfirmationDialog> {
  bool _isResending = false;
  bool _resentSuccess = false;

  Future<void> _handleResend() async {
    if (widget.onResend == null || _isResending) return;
    setState(() {
      _isResending = true;
      _resentSuccess = false;
    });
    try {
      await widget.onResend!();
      if (mounted) {
        setState(() => _resentSuccess = true);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, AuthService.formatAuthError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 16,
      backgroundColor: AppColors.card(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navyPrimary, AppColors.navyDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navyPrimary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.send_rounded,
                    size: 34,
                    color: AppColors.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Magic Link Sent',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heading(context),
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'We emailed you a password-free sign-in link. Click it in your email to immediately access your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColors.subtext(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.brand(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brand(context).withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mail_rounded,
                      size: 18,
                      color: AppColors.brandLink(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.email,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandLink(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line(context)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.goldDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resentSuccess
                            ? 'A new sign-in link has been sent to your inbox!'
                            : 'Don’t see it? Please check your Spam or Junk folder.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _resentSuccess
                              ? AppColors.success
                              : AppColors.subtext(context),
                          fontWeight: _resentSuccess
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onResend != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isResending ? null : _handleResend,
                  icon: _isResending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    _isResending ? 'Sending...' : 'Resend Magic Link',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      widget.onDismiss ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got It, I’ll Check My Email',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
