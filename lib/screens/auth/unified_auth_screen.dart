import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/unified_auth_service.dart';
import 'otp_verification_screen.dart';

/// Unified Authentication Screen providing frictionless toggling between
/// Email authentication and Phone SMS OTP verification with real-time password strength,
/// country picker, auto-focus progression, and OAuth integrations.
class UnifiedAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const UnifiedAuthScreen({super.key, this.onAuthSuccess});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> {
  final _authService = UnifiedAuthService();
  final _formKey = GlobalKey<FormState>();

  // Form Mode: true = Email, false = Phone
  bool _isEmailMode = true;
  // Sub-mode for email: true = Register, false = Sign In
  bool _isRegister = false;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _gradYearController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _gradYearFocusNode = FocusNode();

  bool _obscurePassword = true;
  String _passwordStrengthLabel = '';
  double _passwordStrengthPercent = 0.0;
  Color _passwordStrengthColor = Colors.transparent;

  // Country code selector state
  String _selectedCountryCode = '+64';
  String _selectedCountryFlag = '🇳🇿';
  String _selectedCountryName = 'New Zealand';

  static const List<Map<String, String>> _countryCodes = [
    {'code': '+64', 'flag': '🇳🇿', 'name': 'New Zealand'},
    {'code': '+61', 'flag': '🇦🇺', 'name': 'Australia'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States / Canada'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'Singapore'},
    {'code': '+852', 'flag': '🇭🇰', 'name': 'Hong Kong'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'South Africa'},
    {'code': '+353', 'flag': '🇮🇪', 'name': 'Ireland'},
  ];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_computePasswordStrength);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _gradYearController.dispose();

    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _phoneFocusNode.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _gradYearFocusNode.dispose();
    super.dispose();
  }

  void _computePasswordStrength() {
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      setState(() {
        _passwordStrengthLabel = '';
        _passwordStrengthPercent = 0.0;
        _passwordStrengthColor = Colors.transparent;
      });
      return;
    }

    int score = 0;
    if (pass.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass)) score++;
    if (RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (RegExp(r'[!@#\$&*~_.]').hasMatch(pass)) score++;

    setState(() {
      if (score <= 1) {
        _passwordStrengthLabel = 'Weak';
        _passwordStrengthPercent = 0.25;
        _passwordStrengthColor = AppColors.error;
      } else if (score == 2) {
        _passwordStrengthLabel = 'Fair';
        _passwordStrengthPercent = 0.50;
        _passwordStrengthColor = AppColors.warning;
      } else if (score == 3) {
        _passwordStrengthLabel = 'Good';
        _passwordStrengthPercent = 0.75;
        _passwordStrengthColor = const Color(0xFF3B82F6);
      } else {
        _passwordStrengthLabel = 'Strong';
        _passwordStrengthPercent = 1.0;
        _passwordStrengthColor = AppColors.success;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEmailMode) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      bool success;
      if (_isRegister) {
        final gradYear = int.tryParse(_gradYearController.text.trim());
        success = await _authService.signUpWithEmail(
          email: email,
          password: password,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          gradYear: gradYear,
        );
      } else {
        success = await _authService.signInWithEmail(
          email: email,
          password: password,
        );
      }

      if (mounted) {
        if (success) {
          widget.onAuthSuccess?.call();
        } else {
          final err = _authService.state.errorMessage ?? 'Authentication failed';
          SnackbarHelper.showError(context, err);
        }
      }
    } else {
      // Phone OTP authentication flow
      final rawPhone = _phoneController.text.trim();
      final clean = rawPhone.replaceAll(RegExp(r'[\s\-]'), '');
      final fullPhoneNumber = '$_selectedCountryCode$clean';

      final success = await _authService.sendPhoneOtp(
        formattedPhone: fullPhoneNumber,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phoneNumber: fullPhoneNumber,
                onSuccess: () {
                  widget.onAuthSuccess?.call();
                },
              ),
            ),
          );
        } else {
          final err = _authService.state.errorMessage ?? 'Failed to send OTP';
          SnackbarHelper.showError(context, err);
        }
      }
    }
  }

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Country Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _countryCodes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = _countryCodes[i];
                  final isSelected = item['code'] == _selectedCountryCode;
                  return ListTile(
                    leading: Text(
                      item['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(item['name']!),
                    trailing: Text(
                      item['code']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.navyPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCountryCode = item['code']!;
                        _selectedCountryFlag = item['flag']!;
                        _selectedCountryName = item['name']!;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, _) {
        final isLoading = _authService.state.isLoading;

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
                            'Old Boys Network • Cultores Mentium',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.crimson,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Unified Mode Segmented Control: [Email] vs [Phone Number]
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isEmailMode = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isEmailMode
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                        boxShadow: _isEmailMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.mail_outline_rounded,
                                            size: 17,
                                            color: _isEmailMode
                                                ? AppColors.navyPrimary
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Email',
                                            style: TextStyle(
                                              fontWeight: _isEmailMode
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: _isEmailMode
                                                  ? AppColors.navyPrimary
                                                  : AppColors.textSecondary,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _isEmailMode = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: !_isEmailMode
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                        boxShadow: !_isEmailMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.phone_iphone_rounded,
                                            size: 17,
                                            color: !_isEmailMode
                                                ? AppColors.navyPrimary
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Phone OTP',
                                            style: TextStyle(
                                              fontWeight: !_isEmailMode
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: !_isEmailMode
                                                  ? AppColors.navyPrimary
                                                  : AppColors.textSecondary,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ===================================================
                          // EMAIL AUTHENTICATION SECTION
                          // ===================================================
                          if (_isEmailMode) ...[
                            // Sign In vs Register sub-switcher
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _isRegister = false),
                                  style: TextButton.styleFrom(
                                    foregroundColor: !_isRegister
                                        ? AppColors.navyPrimary
                                        : AppColors.textMuted,
                                    textStyle: TextStyle(
                                      fontWeight: !_isRegister
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  child: const Text('Sign In'),
                                ),
                                const Text('•', style: TextStyle(color: AppColors.borderDarker)),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _isRegister = true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _isRegister
                                        ? AppColors.navyPrimary
                                        : AppColors.textMuted,
                                    textStyle: TextStyle(
                                      fontWeight: _isRegister
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  child: const Text('New Account'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (_isRegister) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstNameController,
                                      focusNode: _firstNameFocusNode,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          _lastNameFocusNode.requestFocus(),
                                      decoration: const InputDecoration(
                                        labelText: 'First Name',
                                        prefixIcon: Icon(Icons.person_outline, size: 20),
                                      ),
                                      validator: (v) => _isRegister &&
                                              (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastNameController,
                                      focusNode: _lastNameFocusNode,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          _gradYearFocusNode.requestFocus(),
                                      decoration: const InputDecoration(
                                        labelText: 'Last Name',
                                      ),
                                      validator: (v) => _isRegister &&
                                              (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _gradYearController,
                                focusNode: _gradYearFocusNode,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _emailFocusNode.requestFocus(),
                                decoration: const InputDecoration(
                                  labelText: 'Graduation / Final Year',
                                  hintText: 'e.g. 2014',
                                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                                ),
                                validator: (v) {
                                  if (!_isRegister) return null;
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final year = int.tryParse(v);
                                  if (year == null || year < 1920 || year > 2035) {
                                    return 'Enter valid year';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Email Address Field with real-time validation
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _passwordFocusNode.requestFocus(),
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'oldboy@waitakibhs.school.nz',
                                prefixIcon: Icon(Icons.mail_outline, size: 20),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                    .hasMatch(v.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
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
                                if (_isRegister && v.length < 6) {
                                  return 'At least 6 characters required';
                                }
                                return null;
                              },
                            ),

                            // Real-Time Password Strength Meter (Shown during Registration)
                            if (_isRegister &&
                                _passwordStrengthLabel.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _passwordStrengthPercent,
                                        backgroundColor: AppColors.border,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _passwordStrengthColor,
                                        ),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _passwordStrengthLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _passwordStrengthColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],

                          // ===================================================
                          // PHONE OTP AUTHENTICATION SECTION
                          // ===================================================
                          if (!_isEmailMode) ...[
                            const Text(
                              'Fast passwordless login with a 6-digit SMS verification code.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Country code picker & phone number row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tooltip(
                                  message: _selectedCountryName,
                                  child: InkWell(
                                    onTap: _showCountryCodePicker,
                                    borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(10),
                                      color: AppColors.surfaceMuted,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _selectedCountryFlag,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedCountryCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.navyDark,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    focusNode: _phoneFocusNode,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _handleSubmit(),
                                    decoration: const InputDecoration(
                                      labelText: 'Mobile Number',
                                      hintText: '021 123 4567',
                                      prefixIcon: Icon(
                                        Icons.phone_outlined,
                                        size: 20,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (_isEmailMode) return null;
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Phone is required';
                                      }
                                      final clean =
                                          v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                                      if (clean.length < 7 ||
                                          !RegExp(r'^[0-9]+$').hasMatch(clean)) {
                                        return 'Enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Primary Action Button (with anti-double-tap lock & spinner)
                          ElevatedButton(
                            onPressed: isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isEmailMode
                                        ? (_isRegister
                                            ? 'Join Old Boys Network'
                                            : 'Sign In')
                                        : 'Send Verification Code',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),

                          // Social OAuth Divider
                          Row(
                            children: const [
                              Expanded(child: Divider(color: AppColors.border)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or continue with',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Social Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => _authService.signInWithOAuth(
                                            OAuthProvider.google,
                                          ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: const BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 24,
                                    color: AppColors.navyPrimary,
                                  ),
                                  label: const Text(
                                    'Google',
                                    style: TextStyle(
                                      color: AppColors.navyDark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => _authService.signInWithOAuth(
                                            OAuthProvider.apple,
                                          ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: const BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.apple,
                                    size: 20,
                                    color: AppColors.navyDark,
                                  ),
                                  label: const Text(
                                    'Apple',
                                    style: TextStyle(
                                      color: AppColors.navyDark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      },
    );
  }
}
