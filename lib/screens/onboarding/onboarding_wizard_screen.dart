import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../auth/auth_screen.dart';
import '../home_navigation_screen.dart';
import '../legal/legal_screens.dart';

/// Simplified Consolidated Onboarding Screen
/// Asks only for:
/// - Name (First Name, Last Name)
/// - Age (13–100)
/// - Phone Number
/// - "Share my contact info" toggle
/// - Plus Email & Password credentials when creating a new account (or when unauthenticated)
class OnboardingWizardScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialPhone;
  final int initialStep;
  final bool isNewAccount;
  final VoidCallback? onCompleted;
  final ValueChanged<int>? onStepChanged;

  const OnboardingWizardScreen({
    super.key,
    this.initialEmail,
    this.initialPhone,
    this.initialStep = 1,
    this.isNewAccount = false,
    this.onCompleted,
    this.onStepChanged,
  });

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _sharePhoneOnProfile = false;

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int? _selectedAge;

  static final List<int> _ageRange = List.generate(
    100 - 13 + 1,
    (index) => 13 + index,
  );

  bool get _needsCredentials {
    if (widget.isNewAccount) return true;
    if (!SupabaseService.isInitialized) {
      return widget.initialEmail != null || widget.initialPhone != null;
    }
    return SupabaseService.currentUser == null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      final raw = widget.initialEmail!.trim();
      if (AuthService.isEmailInput(raw)) {
        _emailController.text = raw;
      } else {
        _phoneController.text = raw;
      }
    }
    if (widget.initialPhone != null && widget.initialPhone!.trim().isNotEmpty) {
      _phoneController.text = widget.initialPhone!.trim();
    }
    _loadSavedData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Loads any previously saved profile details for the user
  Future<void> _loadSavedData() async {
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        if (_emailController.text.isEmpty && user.email != null) {
          _emailController.text = user.email!;
        }

        final profile = await _profileService.getCurrentProfile();
        if (profile != null && mounted) {
          setState(() {
            if (_firstNameController.text.isEmpty &&
                profile.firstName != null) {
              _firstNameController.text = profile.firstName!;
            }
            if (_lastNameController.text.isEmpty && profile.lastName != null) {
              _lastNameController.text = profile.lastName!;
            }
            if (_phoneController.text.isEmpty && profile.phone != null) {
              _phoneController.text = profile.phone!;
            }
            if (_selectedAge == null && profile.age != null) {
              _selectedAge = profile.age;
              _ageController.text = profile.age.toString();
            }
            _sharePhoneOnProfile = profile.sharePhoneOnProfile;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handleBackToSignIn() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    if (SupabaseService.isInitialized && SupabaseService.currentUser != null) {
      await _authService.signOut();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _handleCompleteSetup() async {
    final parsedAge = int.tryParse(_ageController.text.trim());
    if (parsedAge != null) {
      _selectedAge = parsedAge;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedAge == null) {
      SnackbarHelper.showError(context, 'Please enter or select your age');
      return;
    }

    setState(() => _isLoading = true);
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      String? userId = SupabaseService.currentUserId;
      bool requiresEmailConfirmation = false;

      if (_needsCredentials && SupabaseService.isInitialized && userId == null) {
        if (!widget.isNewAccount) {
          // Existing account with unfinished onboarding: verify password via signIn first
          try {
            final res = await _authService.signInWithPassword(
              email: email,
              password: password,
            );
            userId = res.user?.id ?? SupabaseService.currentUserId;
          } catch (signInError) {
            final errStr = signInError.toString().toLowerCase();
            // If it was an unclaimed pre-imported profile without an Auth user yet, try signUp
            if (errStr.contains('invalid login credentials') ||
                errStr.contains('user not found')) {
              try {
                final signUpRes = await _authService.signUpWithPassword(
                  email: email,
                  password: password,
                  firstName: first,
                  lastName: last,
                  age: _selectedAge,
                  phone: phone,
                  sharePhoneOnProfile: _sharePhoneOnProfile,
                  isOnboarded: true,
                );
                userId = signUpRes.user?.id ?? SupabaseService.currentUserId;
                if (signUpRes.user != null &&
                    signUpRes.session == null &&
                    SupabaseService.currentUserId == null) {
                  requiresEmailConfirmation = true;
                }
              } catch (_) {
                throw Exception(
                  'Incorrect password for $email. Please enter your existing account password, or tap Back to sign in with a different email.',
                );
              }
            } else {
              rethrow;
            }
          }
        } else {
          // Brand new account: signUp first, fall back to signIn if already registered
          try {
            final res = await _authService.signUpWithPassword(
              email: email,
              password: password,
              firstName: first,
              lastName: last,
              age: _selectedAge,
              phone: phone,
              sharePhoneOnProfile: _sharePhoneOnProfile,
              isOnboarded: true,
            );
            userId = res.user?.id ?? SupabaseService.currentUserId;
            if (res.user != null &&
                res.session == null &&
                SupabaseService.currentUserId == null) {
              requiresEmailConfirmation = true;
            }
          } catch (signUpError) {
            final errStr = signUpError.toString().toLowerCase();
            if (errStr.contains('already registered') ||
                errStr.contains('already exists') ||
                errStr.contains('user_already_exists')) {
              try {
                final res = await _authService.signInWithPassword(
                  email: email,
                  password: password,
                );
                userId = res.user?.id ?? SupabaseService.currentUserId;
              } catch (_) {
                throw Exception(
                  'An account with $email already exists, and the password entered did not match. Please enter your existing password or tap Back.',
                );
              }
            } else {
              rethrow;
            }
          }
        }
      }

      if (requiresEmailConfirmation) {
        if (userId != null) {
          ProfileService.markOnboardingCompleted(userId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('sp_onboarding_completed_$userId', true);
          await prefs.setBool('sp_share_phone_$userId', _sharePhoneOnProfile);
        }
        if (mounted) {
          await AuthScreen.showEmailConfirmationDialog(
            context,
            email,
            onDismiss: () {
              if (mounted) {
                _handleBackToSignIn();
              }
            },
          );
        }
        return;
      }

      final activeUserId = SupabaseService.currentUserId;
      userId ??= activeUserId;
      if (userId != null && SupabaseService.isInitialized) {
        if (activeUserId != null) {
          await _profileService.updateProfile(
            firstName: first,
            lastName: last,
            age: _selectedAge,
            phone: phone,
            sharePhoneOnProfile: _sharePhoneOnProfile,
            onboardingStep: 1,
            isOnboarded: true,
          );
        }

        ProfileService.markOnboardingCompleted(userId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sp_onboarding_completed_$userId', true);
        await prefs.setBool('sp_share_phone_$userId', _sharePhoneOnProfile);
        await prefs.remove('sp_onboarding_step_$userId');
      }

      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        'Welcome to the Waitaki Old Boys Network!',
      );

      final nav = Navigator.maybeOf(context);
      if (widget.onCompleted != null && nav != null) {
        try {
          widget.onCompleted!();
        } catch (_) {}
      } else if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeNavigationScreen(initialIndex: 0),
          ),
          (route) => false,
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
    final showCredentials = _needsCredentials;
    final prefilledIdentifier = (widget.initialEmail != null &&
            widget.initialEmail!.trim().isNotEmpty)
        ? widget.initialEmail!.trim()
        : (widget.initialPhone != null &&
                widget.initialPhone!.trim().isNotEmpty)
            ? widget.initialPhone!.trim()
            : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Back Action Bar
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed:
                                _isLoading ? null : _handleBackToSignIn,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text('Back to Sign In'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildHeader(),
                        const SizedBox(height: 18),

                        // Context Banner for New Account vs Existing Incomplete Account
                        if (prefilledIdentifier != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.navyPrimary
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.navyPrimary
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.isNewAccount
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.account_circle_outlined,
                                  size: 18,
                                  color: AppColors.navyPrimary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.isNewAccount
                                        ? 'No existing account matched "$prefilledIdentifier". Complete the details below to create your account, or tap Back to edit.'
                                        : 'Welcome back! Finish your profile details below for "$prefilledIdentifier".',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.navyDark,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Name Row (First Name & Last Name)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'First Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _firstNameController,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Frank',
                                      prefixIcon: Icon(
                                        Icons.person_outline,
                                        size: 20,
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Last Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _lastNameController,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Milner',
                                      prefixIcon: Icon(
                                        Icons.person_outline,
                                        size: 20,
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Age (Typable + Dropdown 13 - 100)
                        const Text(
                          'Age',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Select your age (13 – 100)',
                            prefixIcon: const Icon(
                              Icons.cake_outlined,
                              size: 20,
                            ),
                            suffixIcon: PopupMenuButton<int>(
                              icon: const Icon(Icons.arrow_drop_down),
                              tooltip: 'Select age',
                              constraints: const BoxConstraints(maxHeight: 320),
                              onSelected: (val) {
                                setState(() {
                                  _selectedAge = val;
                                  _ageController.text = val.toString();
                                });
                              },
                              itemBuilder: (context) => _ageRange
                                  .map(
                                    (age) => PopupMenuItem<int>(
                                      value: age,
                                      child: Text('$age years old'),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedAge = int.tryParse(val.trim());
                            });
                          },
                          validator: (v) {
                            final parsed =
                                int.tryParse(v?.trim() ?? '') ?? _selectedAge;
                            if (parsed == null) return 'Please select your age';
                            if (parsed < 13 || parsed > 100) {
                              return 'Please enter an age between 13 and 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone Number
                        const Text(
                          'Phone Number',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 021 123 4567',
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            if (!AuthService.isPhoneInput(v)) {
                              return 'Enter a valid phone number (digits only)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Share my contact info toggle (controls both email and phone visibility)
                        Material(
                          color: AppColors.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            title: const Text(
                              'Share my contact info',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navyDark,
                              ),
                            ),
                            subtitle: const Text(
                              'Allow other Old Boys to view your email and phone number',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            value: _sharePhoneOnProfile,
                            activeTrackColor: AppColors.navyPrimary,
                            onChanged: (val) {
                              setState(() => _sharePhoneOnProfile = val);
                            },
                          ),
                        ),

                        // Email & Password Credentials (when creating a new account or unauthenticated)
                        if (showCredentials) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'e.g. frank@waitakibhs.school.nz',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: (v) {
                              if (!showCredentials) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!v.contains('@') || !v.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.isNewAccount
                                ? 'Create Password'
                                : 'Account Password',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'At least 6 characters',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (!showCredentials) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Password is required';
                              }
                              if (v.trim().length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Complete Setup Action Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleCompleteSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navyPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Complete Setup',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.navyPrimary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyPrimary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.school_rounded,
              color: AppColors.goldAccent,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Waitaki Old Boys',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.navyDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Complete Your Profile Setup',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
