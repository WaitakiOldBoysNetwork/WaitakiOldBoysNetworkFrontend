import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/unified_auth_service.dart';

/// 6-Digit OTP Verification Screen with Automatic SMS Autofill feel,
/// smooth auto-focus progression, backspace detection, and 60-second cooldown timer.
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback? onSuccess;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.onSuccess,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = UnifiedAuthService();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the first PIN box after the screen transitions in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentOtp =>
      _controllers.map((controller) => controller.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted multiple characters (e.g., 6-digit SMS code)
      _handlePaste(value);
      return;
    }

    if (value.isNotEmpty) {
      // Advance to next box
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered: remove focus and auto-verify!
        _focusNodes[index].unfocus();
        if (_currentOtp.length == 6) {
          _verifyOtp();
        }
      }
    }
  }

  void _handlePaste(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (int i = 0; i < 6; i++) {
      if (i < digits.length) {
        _controllers[i].text = digits[i];
      }
    }

    if (digits.length >= 6) {
      _focusNodes[5].unfocus();
      _verifyOtp();
    } else {
      _focusNodes[digits.length].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _currentOtp;
    if (otp.length < 6) {
      SnackbarHelper.showError(context, 'Please enter all 6 digits');
      return;
    }

    setState(() => _isVerifying = true);
    final success = await _authService.verifyPhoneOtp(
      phone: widget.phoneNumber,
      token: otp,
    );

    if (mounted) {
      setState(() => _isVerifying = false);
      if (success) {
        widget.onSuccess?.call();
      } else {
        final error = _authService.state.errorMessage ?? 'Verification failed';
        SnackbarHelper.showError(context, error);
        // Clear digits on error and refocus first box
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  Future<void> _handleResend() async {
    if (!_authService.state.canResendOtp) return;

    final success = await _authService.resendPhoneOtp();
    if (mounted) {
      if (success) {
        SnackbarHelper.showSuccess(
          context,
          'A new 6-digit verification code has been sent.',
        );
      } else {
        final error = _authService.state.errorMessage ?? 'Failed to resend code';
        SnackbarHelper.showError(context, error);
      }
    }
  }

  String _formatMaskedPhone(String phone) {
    if (phone.length <= 6) return phone;
    final prefix = phone.substring(0, phone.length - 4);
    final suffix = phone.substring(phone.length - 2);
    return '$prefix••$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, _) {
        final state = _authService.state;
        final countdown = state.resendCountdown;
        final canResend = state.canResendOtp;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: AppColors.navyDark,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Icon Shield
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.navyPrimary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mark_chat_read_outlined,
                                color: AppColors.navyPrimary,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Enter 6-Digit Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navyDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Sent to ${_formatMaskedPhone(widget.phoneNumber)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.crimson,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // 6 Individual PIN Input Boxes
                          KeyboardListener(
                            focusNode: FocusNode(),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.backspace) {
                                for (int i = 1; i < 6; i++) {
                                  if (_focusNodes[i].hasFocus &&
                                      _controllers[i].text.isEmpty) {
                                    _focusNodes[i - 1].requestFocus();
                                    _controllers[i - 1].clear();
                                    break;
                                  }
                                }
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (index) {
                                return SizedBox(
                                  width: 48,
                                  height: 56,
                                  child: TextFormField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navyDark,
                                    ),
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(6),
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.goldAccent,
                                          width: 2.2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: _focusNodes[index].hasFocus
                                          ? Colors.white
                                          : AppColors.surfaceMuted,
                                    ),
                                    onChanged: (val) =>
                                        _onDigitChanged(index, val),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Verify Button
                          ElevatedButton(
                            onPressed: _isVerifying || state.isLoading
                                ? null
                                : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isVerifying || state.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Verify & Continue',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Resend Timer Row
                          Center(
                            child: canResend
                                ? TextButton(
                                    onPressed: _handleResend,
                                    child: const Text(
                                      'Resend SMS Code',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navyPrimary,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Resend code in ${countdown}s',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
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
      },
    );
  }
}
