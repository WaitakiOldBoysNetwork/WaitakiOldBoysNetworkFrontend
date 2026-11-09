import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../home_navigation_screen.dart';
import '../legal/legal_screens.dart';

/// Simplified Consolidated Onboarding Screen
/// Asks only for:
/// - Name (First Name, Last Name)
/// - Age (13–100)
/// - Phone Number
/// - "Share phone number on my profile" toggle
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

      if (_needsCredentials && SupabaseService.isInitialized && userId == null) {
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
        } catch (signUpError) {
          final errStr = signUpError.toString().toLowerCase();
          if (errStr.contains('already registered') ||
              errStr.contains('already exists') ||
              errStr.contains('user_already_exists')) {
            final res = await _authService.signInWithPassword(
              email: email,
              password: password,
            );
            userId = res.user?.id ?? SupabaseService.currentUserId;
          } else {
            rethrow;
          }
        }
      }

      userId ??= SupabaseService.currentUserId;
      if (userId != null && SupabaseService.isInitialized) {
        await _profileService.updateProfile(
          firstName: first,
          lastName: last,
          age: _selectedAge,
          phone: phone,
          sharePhoneOnProfile: _sharePhoneOnProfile,
          onboardingStep: 1,
          isOnboarded: true,
        );

        ProfileService.markOnboardingCompleted(userId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sp_onboarding_completed_$userId', true);
        await prefs.setBool('sp_share_phone_$userId', _sharePhoneOnProfile);
        await prefs.remove('sp_onboarding_step_$userId');
      }

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to complete setup: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCredentials = _needsCredentials;

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
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),

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
                            if (v
                                    .trim()
                                    .replaceAll(RegExp(r'[\s\-\(\)\+]'), '')
                                    .length <
                                7) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Share phone number on my profile toggle
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            title: const Text(
                              'Share phone number on my profile',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navyDark,
                              ),
                            ),
                            subtitle: const Text(
                              'Allow other Old Boys to view your phone number',
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

                        // Email & Password Credentials (when creating a new account)
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
                          const Text(
                            'Create Password',
                            style: TextStyle(
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

                        const SizedBox(height: 28),

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
