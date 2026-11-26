import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _errorMessage;

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int? _selectedAge;

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

  Future<void> _showAgePickerDialog() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _AgePickerDialog(
        initialAge: _selectedAge ?? int.tryParse(_ageController.text.trim()),
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _selectedAge = chosen;
        _ageController.text = chosen.toString();
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleCompleteSetup() async {
    setState(() => _errorMessage = null);

    final parsedAge = int.tryParse(_ageController.text.trim());
    if (parsedAge != null) {
      _selectedAge = parsedAge;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedAge == null) {
      setState(() => _errorMessage = 'Please enter or select your age.');
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

        if (userId != null && !requiresEmailConfirmation) {
          ProfileService.markOnboardingCompleted(userId);
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

      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeNavigationScreen(initialIndex: 0),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthService.formatAuthError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required bool isCompact,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      isDense: isCompact,
      contentPadding: isCompact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
          : null,
      prefixIconConstraints: isCompact
          ? const BoxConstraints(minWidth: 38, minHeight: 38)
          : null,
      prefixIcon: Icon(prefixIcon, size: isCompact ? 18 : 20),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildFirstNameField(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'First Name',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _firstNameController,
          decoration: _buildInputDecoration(
            hintText: 'e.g. Frank',
            prefixIcon: Icons.person_outline,
            isCompact: isCompact,
          ),
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildLastNameField(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last Name',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _lastNameController,
          decoration: _buildInputDecoration(
            hintText: 'e.g. Milner',
            prefixIcon: Icons.person_outline,
            isCompact: isCompact,
          ),
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCredentials = _needsCredentials;
    final isCompact = MediaQuery.of(context).size.width < 480;
    final fieldGap = isCompact ? 12.0 : 16.0;
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
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 20,
              vertical: isCompact ? 12 : 24,
            ),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 24,
                    vertical: isCompact ? 18 : 28,
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
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 2 : 4),
                        _buildHeader(isCompact),
                        SizedBox(height: isCompact ? 12 : 18),

                        // Context Banner for New Account vs Existing Incomplete Account
                        if (prefilledIdentifier != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
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
                          SizedBox(height: fieldGap),
                        ],

                        // Name Inputs (stacked vertically on narrow mobile to prevent clipping)
                        if (isCompact) ...[
                          _buildFirstNameField(isCompact),
                          SizedBox(height: fieldGap),
                          _buildLastNameField(isCompact),
                        ] else
                          Row(
                            children: [
                              Expanded(child: _buildFirstNameField(isCompact)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildLastNameField(isCompact)),
                            ],
                          ),
                        SizedBox(height: fieldGap),

                        // Age (Typable + Bounded Picker Dialog 13 - 100)
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: _buildInputDecoration(
                            hintText: 'Select your age (13 – 100)',
                            prefixIcon: Icons.cake_outlined,
                            isCompact: isCompact,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              tooltip: 'Select age',
                              onPressed: _showAgePickerDialog,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedAge = int.tryParse(val.trim());
                              _errorMessage = null;
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
                        SizedBox(height: fieldGap),

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
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\s\-\(\)\+]'),
                            ),
                          ],
                          decoration: _buildInputDecoration(
                            hintText: 'e.g. 021 123 4567',
                            prefixIcon: Icons.phone_outlined,
                            isCompact: isCompact,
                          ),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
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
                        SizedBox(height: isCompact ? 10 : 12),

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
                          SizedBox(height: fieldGap),
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
                            decoration: _buildInputDecoration(
                              hintText: 'e.g. frank@waitakibhs.school.nz',
                              prefixIcon: Icons.email_outlined,
                              isCompact: isCompact,
                            ),
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
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
                          SizedBox(height: fieldGap),
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
                            decoration: _buildInputDecoration(
                              hintText: 'At least 6 characters',
                              prefixIcon: Icons.lock_outline,
                              isCompact: isCompact,
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
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
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

                        SizedBox(height: isCompact ? 16 : 24),

                        // Inline Error Banner (never covers Create Password or Complete Setup)
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppColors.crimson.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.crimson.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.crimson,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.crimson,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Dismiss error',
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppColors.crimson,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  onPressed: () =>
                                      setState(() => _errorMessage = null),
                                ),
                              ],
                            ),
                          ),
                        ],

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

                        SizedBox(height: isCompact ? 14 : 20),
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

  Widget _buildHeader(bool isCompact) {
    final badgeSize = isCompact ? 44.0 : 56.0;
    return Column(
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
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
          child: Center(
            child: Icon(
              Icons.school_rounded,
              color: AppColors.goldAccent,
              size: isCompact ? 26 : 32,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        Text(
          'Waitaki Old Boys',
          style: TextStyle(
            fontSize: isCompact ? 20 : 22,
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

class _AgePickerDialog extends StatefulWidget {
  final int? initialAge;

  const _AgePickerDialog({this.initialAge});

  @override
  State<_AgePickerDialog> createState() => _AgePickerDialogState();
}

class _AgePickerDialogState extends State<_AgePickerDialog> {
  static const List<({String label, int min, int max})> _decades = [
    (label: '13–19', min: 13, max: 19),
    (label: '20–29', min: 20, max: 29),
    (label: '30–39', min: 30, max: 39),
    (label: '40–49', min: 40, max: 49),
    (label: '50–59', min: 50, max: 59),
    (label: '60–69', min: 60, max: 69),
    (label: '70+', min: 70, max: 100),
  ];

  late int _selectedDecadeIndex;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDecadeIndex = _decadeIndexForAge(widget.initialAge);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _decadeIndexForAge(int? age) {
    if (age == null) return 0;
    for (var i = 0; i < _decades.length; i++) {
      if (age >= _decades[i].min && age <= _decades[i].max) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final range = _decades[_selectedDecadeIndex];
    final ages = List<int>.generate(
      range.max - range.min + 1,
      (i) => range.min + i,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Select Your Age',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyDark,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(_decades.length, (i) {
                  final selected = i == _selectedDecadeIndex;
                  return ChoiceChip(
                    label: Text(_decades[i].label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedDecadeIndex = i);
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    },
                  );
                }),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: ages.length,
                    itemBuilder: (context, index) {
                      final age = ages[index];
                      final isSelected = widget.initialAge == age;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        title: Text('$age years old'),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                color: AppColors.navyPrimary,
                                size: 18,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(age),
                      );
                    },
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
