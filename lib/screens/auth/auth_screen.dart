import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _gradYearController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _gradYearController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignUp) {
        final gradYear = int.tryParse(_gradYearController.text.trim());
        await _authService.signUpWithPassword(
          email: email,
          password: password,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          gradYear: gradYear,
        );
        if (mounted) {
          SnackbarHelper.showSuccess(
            context,
            'Account created! If email confirmation is enabled, check your inbox.',
          );
        }
      } else {
        await _authService.signInWithPassword(email: email, password: password);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        SnackbarHelper.showSuccess(
          context,
          'Magic link sent to $email! Check your email to sign in.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e.toString());
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
                      ],

                      // Email Field
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

                      // Password Field
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
                                _isSignUp ? 'Join Old Boys Network' : 'Sign In',
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
