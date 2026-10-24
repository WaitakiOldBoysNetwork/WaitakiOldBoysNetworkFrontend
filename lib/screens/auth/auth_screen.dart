import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../home_navigation_screen.dart';
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
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Smart Auth Entry Gate State
  bool _isEmailChecked = false;
  bool _showIncompleteBanner = false;
  int _incompleteStep = 2;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _gradYearController = TextEditingController();
  final _phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _gradYearController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSignUp) {
      await _handleRegisterSubmit();
    } else if (!_isEmailChecked) {
      await _handleEmailContinue();
    } else {
      await _handlePasswordLogin();
    }
  }

  /// Step 1 of Smart Auth Entry Gate: Email First
  Future<void> _handleEmailContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      SnackbarHelper.showError(context, 'Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final exists = await _authService.checkEmailExists(email);
      if (mounted) {
        if (!exists) {
          // New User: Automatically route them into Step 1 of the Onboarding Wizard
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OnboardingWizardScreen(
                initialEmail: email,
                initialStep: 1,
                onCompleted: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const HomeNavigationScreen(initialIndex: 1),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          // Existing User: Reveal the Password input field with a "Log In" button
          setState(() {
            _isEmailChecked = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error checking email: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Step 2 of Smart Auth Entry Gate: Password Authentication
  Future<void> _handlePasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter your password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _authService.signInWithPassword(email: email, password: password);
      final userId = res.user?.id ?? SupabaseService.currentUserId;

      if (userId != null && mounted) {
        final isCompleted = await _authService.checkOnboardingCompleted(userId);
        if (!mounted) return;
        if (isCompleted) {
          // Redirect directly to /directory
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeNavigationScreen(initialIndex: 1),
            ),
          );
        } else {
          final step = await _authService.getUserOnboardingStep(userId);
          if (!mounted) return;
          setState(() {
            _showIncompleteBanner = true;
            _incompleteStep = step;
          });
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

  Future<void> _handleRegisterSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final gradYear = int.tryParse(_gradYearController.text.trim());
      final phone = _phoneController.text.trim();
      await _authService.signUpWithPassword(
        email: email,
        password: password,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gradYear: gradYear,
        phone: phone.isNotEmpty ? phone : null,
      );
      if (mounted) {
        await AuthScreen.showEmailConfirmationDialog(
          context,
          email,
          onDismiss: () {
            if (mounted) {
              setState(() {
                _isSignUp = false;
                _isEmailChecked = false;
                _passwordController.clear();
                _phoneController.clear();
              });
            }
          },
        );
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
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      SnackbarHelper.showError(
        context,
        'Please enter a valid email address first',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendMagicLink(email: email);
      if (mounted) {
        await AuthScreen.showMagicLinkConfirmationDialog(context, email);
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
                      Text(
                        'Old Boys Network • Cultores Mentium',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.crimson,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Segmented switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isSignUp = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isSignUp
                                        ? AppColors.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !_isSignUp
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    'Sign In',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: !_isSignUp
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: !_isSignUp
                                          ? AppColors.navyPrimary
                                          : AppColors.textSecondary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isSignUp = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isSignUp
                                        ? AppColors.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _isSignUp
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    'Register',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: _isSignUp
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _isSignUp
                                          ? AppColors.navyPrimary
                                          : AppColors.textSecondary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign Up Fields
                      if (_isSignUp) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) =>
                                    _isSignUp && (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                ),
                                validator: (v) =>
                                    _isSignUp && (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _gradYearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Graduation / Final Year (e.g. 2014)',
                            prefixIcon: Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (!_isSignUp) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final parsed = int.tryParse(v);
                            if (parsed == null ||
                                parsed < 1920 ||
                                parsed > 2035) {
                              return 'Enter valid year';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'e.g. 021 123 4567 or +64 21 123 4567',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (!_isSignUp) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final clean = v.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
                            if (clean.length < 7 || !RegExp(r'^[0-9]+$').hasMatch(clean)) {
                              return 'Enter valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Incomplete Onboarding Prompt Banner
                      if (_showIncompleteBanner) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.crimson.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.crimson,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Finish setting up your profile to access the directory',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.navyDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => OnboardingWizardScreen(
                                        initialStep: _incompleteStep,
                                        onCompleted: () {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const HomeNavigationScreen(
                                                initialIndex: 1,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.crimson,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Complete Setup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Email Field (Visible in Sign Up or when entering email in Sign In)
                      if (_isSignUp || !_isEmailChecked) ...[
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.mail_outline, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!v.contains('@') || !v.contains('.')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // If Existing User on Sign In tab: Display confirmed email + Change link
                      if (!_isSignUp && _isEmailChecked) ...[
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
                                  _emailController.text,
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
                                    _isEmailChecked = false;
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
                      ],

                      // Password Field (Visible in Sign Up or after email is checked in Sign In)
                      if (_isSignUp || _isEmailChecked) ...[
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
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
                            if (_isSignUp && v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Submit Button
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
                                _isSignUp
                                    ? 'Join Old Boys Network'
                                    : (!_isEmailChecked ? 'Continue' : 'Log In'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Magic Link Alternative for Sign In
                      if (!_isSignUp) ...[
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleMagicLink,
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Send Me a Magic Link'),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Info text
                      Text(
                        _isSignUp
                            ? 'Your email will be auto-matched with pre-registered Waitaki Old Boys records.'
                            : 'Exclusively for Old Boys and staff of Waitaki Boys\' High School.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
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
