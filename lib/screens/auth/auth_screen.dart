import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../home_navigation_screen.dart';
import '../legal/legal_screens.dart';
import '../onboarding/onboarding_wizard_screen.dart';

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
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: MagicLinkConfirmationDialog(
          email: email,
          onDismiss: () {
            Navigator.of(dialogContext).pop();
            onDismiss?.call();
          },
        ),
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
            builder: (_) => OnboardingWizardScreen(
              initialEmail: isEmail ? input : status.email,
              initialPhone: !isEmail ? input : status.phone,
              isNewAccount: true,
              onCompleted: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const HomeNavigationScreen(initialIndex: 0),
                  ),
                );
              },
            ),
          ),
        );
      } else if (!status.onboardingCompleted) {
        // 2. Has account + unfinished onboarding -> route directly to finish onboarding,
        // then route to Main Feed (initialIndex: 0).
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OnboardingWizardScreen(
              initialEmail: status.email ?? (isEmail ? input : null),
              initialPhone: status.phone ?? (!isEmail ? input : null),
              initialStep: status.onboardingStep,
              isNewAccount: false,
              onCompleted: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const HomeNavigationScreen(initialIndex: 0),
                  ),
                );
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
        SnackbarHelper.showError(context, 'Error checking account: $e');
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeNavigationScreen(initialIndex: 0),
            ),
          );
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
                onCompleted: () {
                  Navigator.of(context).pushReplacement(
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
        SnackbarHelper.showError(context, _parseAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseAuthError(dynamic error) {
    final str = error.toString();
    if (str.contains('over_email_send_rate_limit') ||
        str.contains('rate limit') ||
        str.contains('429')) {
      return 'Supabase email rate limit exceeded. The default test provider limits emails to ~3 per hour. Please wait a bit, or turn off "Confirm email" in Supabase settings for testing.';
    }
    if (error is AuthException) {
      return error.message;
    }
    return str;
  }

  Future<void> _handleMagicLink() async {
    final input = (_resolvedEmail ?? _identifierController.text).trim();
    if (input.isEmpty || !input.contains('@')) {
      SnackbarHelper.showError(
        context,
        'Please enter a valid email address first',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendMagicLink(email: input);
      if (mounted) {
        await AuthScreen.showMagicLinkConfirmationDialog(context, input);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, _parseAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
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
                      // Header & WBHS Crest Representation
                      Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 72,
                          fit: BoxFit.contain,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.crimson,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Single Phone Number or Email Input (when not yet verified)
                      if (!_showPasswordField) ...[
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSubmit(),
                          decoration: const InputDecoration(
                            labelText: 'Phone Number or Email',
                            hintText: 'e.g. 021 123 4567 or oldboy@waitakibhs.school.nz',
                            prefixIcon: Icon(
                              Icons.contact_mail_outlined,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || !AuthService.isValidEmailOrPhone(v)) {
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
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
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
                      const SizedBox(height: 16),

                      // Magic Link Option when an email is entered
                      if (_showPasswordField &&
                          (_resolvedEmail?.contains('@') ?? false)) ...[
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleMagicLink,
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Send Me a Magic Link'),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Info text
                      const Text(
                        'Exclusively for Old Boys and staff of Waitaki Boys\' High School.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
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

  Widget _buildStepRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.navyPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 16,
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon badge with WBHS Navy & Gold styling
              Container(
                width: 78,
                height: 78,
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
                    size: 40,
                    color: AppColors.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Check Your Inbox',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'A verification email has been dispatched to activate your Waitaki Old Boys Network account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),

              // Recipient email pill card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.navyPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.navyPrimary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.mail_rounded,
                      size: 18,
                      color: AppColors.navyPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Steps checklist card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildStepRow(
                      icon: Icons.filter_1_rounded,
                      text: 'Open the confirmation email in your inbox.',
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow(
                      icon: Icons.filter_2_rounded,
                      text: 'Click the verification link to activate your account.',
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow(
                      icon: Icons.filter_3_rounded,
                      text: 'Return to this app and sign in with your password.',
                    ),
                    const Divider(height: 18, color: AppColors.border),
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
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
class MagicLinkConfirmationDialog extends StatelessWidget {
  final String email;
  final VoidCallback? onDismiss;

  const MagicLinkConfirmationDialog({
    super.key,
    required this.email,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 16,
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
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
                    size: 38,
                    color: AppColors.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Magic Link Sent',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'We emailed you a password-free sign-in link. Click it in your email to immediately access your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.navyPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.navyPrimary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.mail_rounded,
                      size: 18,
                      color: AppColors.navyPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
