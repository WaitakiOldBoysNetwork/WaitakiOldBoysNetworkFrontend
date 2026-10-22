import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/supabase_service.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onConfigured;
  const SetupScreen({super.key, required this.onConfigured});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = SupabaseConfig.url.contains('your-project-ref')
        ? ''
        : SupabaseConfig.url;
    _keyController.text = (SupabaseConfig.publishableKey.contains('your-publishable-key') ||
            SupabaseConfig.publishableKey.contains('your-anon-key'))
        ? ''
        : SupabaseConfig.publishableKey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || !url.startsWith('http')) {
      SnackbarHelper.showError(context, 'Please enter a valid Supabase URL');
      return;
    }
    if (key.isEmpty) {
      SnackbarHelper.showError(
        context,
        'Please enter your Supabase publishable key (e.g. sb_publishable_...)',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.reinitializeWith(
        url: url,
        publishableKey: key,
        anonKey: key,
      );
      widget.onConfigured();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to connect: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Header
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.navyPrimary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.dns_rounded,
                          color: AppColors.navyPrimary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Connect Your Supabase Backend',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Paste your Supabase project credentials below to connect the Old Boys network frontend to your database.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Inputs
                    const Text(
                      'Project URL',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'https://xyzcompany.supabase.co',
                        prefixIcon: Icon(Icons.link, size: 20),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Publishable API Key',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navyPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'sb_publishable_...',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navyPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _keyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'sb_publishable_... (or legacy anon key)',
                        prefixIcon: Icon(Icons.key, size: 20),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleConnect,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Connect & Launch App',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Tip: You can also define these in lib/core/constants/supabase_config.dart or via --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
    );
  }
}
