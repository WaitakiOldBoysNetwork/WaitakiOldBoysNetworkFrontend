import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../legal/legal_screens.dart';

/// Multi-Step Onboarding Wizard Screen
/// Implements:
/// - Step 1: Account Credentials & Contact (Email pre-filled, Phone, Password)
/// - Step 2: Profile & Academic Details (First Name, Last Name, Age 13-100, Grad Year current down to 1960)
/// - Step 3: School House Selection (Prompt: "Which house are you in?", clickable cards with WBHS colors)
/// - Resumes automatically at last incomplete step without losing previously submitted data
class OnboardingWizardScreen extends StatefulWidget {
  final String? initialEmail;
  final int initialStep;
  final VoidCallback? onCompleted;
  final ValueChanged<int>? onStepChanged;

  const OnboardingWizardScreen({
    super.key,
    this.initialEmail,
    this.initialStep = 1,
    this.onCompleted,
    this.onStepChanged,
  });

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();

  late int _currentStep;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Step 1 Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKeyStep1 = GlobalKey<FormState>();

  // Step 2 Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _gradYearController = TextEditingController();
  int? _selectedAge;
  int? _selectedGradYear;
  final _formKeyStep2 = GlobalKey<FormState>();

  // Step 3 Selection
  String? _selectedHouse;

  // Dropdown ranges
  static final int _currentYear = DateTime.now().year;
  static const int _maxGradYear = 2035;
  static final List<int> _gradYears = List.generate(
    _maxGradYear - 1940 + 1,
    (index) => _maxGradYear - index,
  );
  static final List<int> _ageRange = List.generate(
    100 - 13 + 1,
    (index) => 13 + index,
  );

  // WBHS Houses definitions with heritage colors
  static const List<Map<String, dynamic>> _wbhsHouses = [
    {
      'name': 'Don',
      'color': Color(0xFF16A34A),
      'colorName': 'Green',
      'description': 'Patrick Don • School Founder & Patron',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Founders',
      'color': Color(0xFF64748B),
      'colorName': 'Grey',
      'description': 'Honouring the visionary founders of WBHS',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Forrester',
      'color': Color(0xFF1D4ED8),
      'colorName': 'Blue',
      'description': 'Thomas Forrester • Renowned Architect & Patron',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Lee',
      'color': Color(0xFFD97706),
      'colorName': 'Yellow',
      'description': 'Early Waitaki leadership and scholastic excellence',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Harkness',
      'color': Color(0xFF0891B2),
      'colorName': 'Cyan',
      'description': 'George Harkness • Esteemed early Rector',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Milner',
      'color': Color(0xFF881337),
      'colorName': 'Maroon',
      'description': 'Frank Milner • The "Man of Waitaki" (Rector 1906–1944)',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Sutherland',
      'color': Color(0xFF334155),
      'colorName': 'White',
      'isWhite': true,
      'description': 'Jack Sutherland • Tradition & Waitaki Spirit',
      'icon': Icons.shield_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep.clamp(1, 3);
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    _loadSavedData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _gradYearController.dispose();
    super.dispose();
  }

  /// Reloads saved progress from profile or local preferences to preserve data
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
            if (_firstNameController.text.isEmpty && profile.firstName != null) {
              _firstNameController.text = profile.firstName!;
            }
            if (_lastNameController.text.isEmpty && profile.lastName != null) {
              _lastNameController.text = profile.lastName!;
            }
            if (_phoneController.text.isEmpty && profile.phone != null) {
              _phoneController.text = profile.phone!;
            }
            if (_selectedGradYear == null && profile.gradYear != null) {
              _selectedGradYear = profile.gradYear;
              _gradYearController.text = profile.gradYear.toString();
            }
            if (_selectedAge == null && profile.age != null) {
              _selectedAge = profile.age;
              _ageController.text = profile.age.toString();
            }
            if (_selectedHouse == null && profile.house != null && profile.house!.isNotEmpty) {
              _selectedHouse = profile.house;
            }

            // If resuming without an explicit widget step, use saved step
            if (widget.initialStep <= 1 && profile.onboardingStep != null && profile.onboardingStep! >= 2) {
              _currentStep = profile.onboardingStep!.clamp(1, 3);
            }
          });
        }

        // Also check SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedStep = prefs.getInt('sp_onboarding_step_${user.id}');
        if (savedStep != null && savedStep >= 2 && widget.initialStep <= 1 && mounted) {
          setState(() {
            _currentStep = savedStep.clamp(1, 3);
          });
        }
      }
    } catch (_) {}
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step.clamp(1, 3);
    });
    widget.onStepChanged?.call(_currentStep);
  }

  /// Step 1: Account Credentials & Contact
  Future<void> _handleStep1Continue() async {
    if (!_formKeyStep1.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        // Create new user account
        final res = await _authService.signUpWithPassword(
          email: email,
          password: password,
          phone: phone,
        );

        final userId = res.user?.id;
        if (userId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('sp_onboarding_step_$userId', 2);
          await prefs.setString('sp_onboarding_phone_$userId', phone);
        }
      } else {
        // User already has an authenticated session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('sp_onboarding_step_${currentUser.id}', 2);
        await prefs.setString('sp_onboarding_phone_${currentUser.id}', phone);
      }

      if (mounted) {
        _goToStep(2);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Unable to create account: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Step 2: Profile & Academic Details
  Future<void> _handleStep2Next() async {
    final parsedAge = int.tryParse(_ageController.text.trim());
    if (parsedAge != null) {
      _selectedAge = parsedAge;
    }
    final parsedGradYear = int.tryParse(_gradYearController.text.trim());
    if (parsedGradYear != null) {
      _selectedGradYear = parsedGradYear;
    }

    if (!_formKeyStep2.currentState!.validate()) return;

    if (_selectedAge == null) {
      SnackbarHelper.showError(context, 'Please enter or select your age');
      return;
    }
    if (_selectedGradYear == null) {
      SnackbarHelper.showError(context, 'Please enter or select your graduation year');
      return;
    }

    setState(() => _isLoading = true);
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        await _profileService.updateProfile(
          firstName: first,
          lastName: last,
          age: _selectedAge,
          gradYear: _selectedGradYear,
          phone: phone.isNotEmpty ? phone : null,
          onboardingStep: 3,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('sp_onboarding_step_${user.id}', 3);
      }

      if (mounted) {
        _goToStep(3);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Step 3: School House Selection & Completion
  Future<void> _handleCompleteSetup() async {
    if (_selectedHouse == null || _selectedHouse!.isEmpty) {
      SnackbarHelper.showError(context, 'Please select your school house');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = SupabaseService.currentUser;
      final userId = user?.id ?? SupabaseService.currentUserId;

      if (userId != null) {
        final first = _firstNameController.text.trim().isNotEmpty
            ? _firstNameController.text.trim()
            : 'Old';
        final last = _lastNameController.text.trim().isNotEmpty
            ? _lastNameController.text.trim()
            : 'Boy';

        await _profileService.updateProfile(
          firstName: first,
          lastName: last,
          house: _selectedHouse,
          age: _selectedAge,
          gradYear: _selectedGradYear ?? _currentYear,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          onboardingStep: 3,
          isOnboarded: true,
        );

        ProfileService.markOnboardingCompleted(userId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sp_onboarding_completed_$userId', true);
        await prefs.remove('sp_onboarding_step_$userId');
      }

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Welcome to the Waitaki Old Boys Network!',
        );
        widget.onCompleted?.call();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header & Stepper
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStepProgress(),
                      const SizedBox(height: 28),

                      // Step Content
                      if (_currentStep == 1) _buildStep1AccountContact(),
                      if (_currentStep == 2) _buildStep2ProfileAcademic(),
                      if (_currentStep == 3) _buildStep3HouseSelection(),
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
          child: Center(
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
        Text(
          _currentStep == 1
              ? 'Step 1: Account Credentials & Contact'
              : _currentStep == 2
                  ? 'Step 2: Profile & Academic Details'
                  : 'Step 3: School House Selection',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepProgress() {
    return Row(
      children: [
        _buildStepBadge(1, 'Account'),
        _buildStepConnector(1),
        _buildStepBadge(2, 'Profile'),
        _buildStepConnector(2),
        _buildStepBadge(3, 'House'),
      ],
    );
  }

  Widget _buildStepBadge(int step, String title) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? const Color(0xFF16A34A)
                : isActive
                    ? AppColors.navyPrimary
                    : AppColors.surface,
            border: Border.all(
              color: isDone
                  ? const Color(0xFF16A34A)
                  : isActive
                      ? AppColors.navyPrimary
                      : AppColors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.navyDark : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int step) {
    final isDone = _currentStep > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 18, left: 8, right: 8),
        color: isDone ? const Color(0xFF16A34A) : AppColors.border,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: Account Credentials & Contact
  // ---------------------------------------------------------------------------
  Widget _buildStep1AccountContact() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
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
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
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
              if (v == null || v.trim().isEmpty) return 'Phone number is required';
              if (v.trim().replaceAll(RegExp(r'[\s\-\(\)\+]'), '').length < 7) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Create Password
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
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Password is required';
              if (v.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 28),

          // Continue Button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleStep1Continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Profile & Academic Details
  // ---------------------------------------------------------------------------
  Widget _buildStep2ProfileAcademic() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'First Name',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Frank',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Milner',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
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
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Select your age (13 – 100)',
              prefixIcon: const Icon(Icons.cake_outlined, size: 20),
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
              final parsed = int.tryParse(v?.trim() ?? '') ?? _selectedAge;
              if (parsed == null) return 'Please select your age';
              if (parsed < 13 || parsed > 100) {
                return 'Please enter an age between 13 and 100';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Graduation Year (Typable + Dropdown 2035 down to 1940)
          const Text(
            'Graduation / Final Year at WBHS',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _gradYearController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Select graduation year (1920 – $_maxGradYear)',
              prefixIcon: const Icon(Icons.school_outlined, size: 20),
              suffixIcon: PopupMenuButton<int>(
                icon: const Icon(Icons.arrow_drop_down),
                tooltip: 'Select graduation year',
                onSelected: (val) {
                  setState(() {
                    _selectedGradYear = val;
                    _gradYearController.text = val.toString();
                  });
                },
                itemBuilder: (context) => _gradYears
                    .map(
                      (year) => PopupMenuItem<int>(
                        value: year,
                        child: Text('Class of $year'),
                      ),
                    )
                    .toList(),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedGradYear = int.tryParse(val.trim());
              });
            },
            validator: (v) {
              final parsed = int.tryParse(v?.trim() ?? '') ?? _selectedGradYear;
              if (parsed == null) return 'Please select graduation year';
              if (parsed < 1920 || parsed > _maxGradYear) {
                return 'Please enter a valid year between 1920 and $_maxGradYear';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              OutlinedButton(
                onPressed: _isLoading ? null : () => _goToStep(1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleStep2Next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Next: Select House',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: School House Selection
  // ---------------------------------------------------------------------------
  Widget _buildStep3HouseSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Text(
            'Which house are you in?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.navyDark,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Select your historic or current Waitaki Boys\' High School house',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),

        // House Cards Grid / List
        ..._wbhsHouses.map((house) {
          final isSelected = _selectedHouse == house['name'];
          final color = house['color'] as Color;
          final isWhite = house['isWhite'] == true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _selectedHouse = house['name'] as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: isWhite ? 0.08 : 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isWhite
                            ? Border.all(color: AppColors.navyDark, width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        house['icon'] as IconData,
                        color: isWhite ? AppColors.navyDark : Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${house['name']} House',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isSelected ? AppColors.navyDark : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  house['colorName'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isWhite ? AppColors.navyDark : color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            house['description'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: isSelected ? color : AppColors.textMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        Row(
          children: [
            OutlinedButton(
              onPressed: _isLoading ? null : () => _goToStep(2),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCompleteSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Complete Setup',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
