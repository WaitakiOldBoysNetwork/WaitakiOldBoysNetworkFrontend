import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onConfigured;
  const SetupScreen({super.key, required this.onConfigured});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const String _defaultWaitakiUrl =
      'https://qehluoctztbjgtijhjir.supabase.co';
  static const String _defaultWaitakiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlaGx1b2N0enRiamd0aWpoamlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MTk4NjUsImV4cCI6MjEwODE5NTg2NX0.BmLMMLDYZqHIjHGLOnuVvkXcTYzrgz_oI7-_J0jxp3c';

  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isSaving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _urlController.text = SupabaseConfig.url.contains('your-project-ref')
        ? ''
        : SupabaseConfig.url;
    _keyController.text =
        (SupabaseConfig.publishableKey.contains('your-publishable-key') ||
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

    final parsedUri = Uri.tryParse(url);
    if (url.isEmpty ||
        parsedUri == null ||
        !(parsedUri.scheme == 'http' || parsedUri.scheme == 'https') ||
        parsedUri.host.isEmpty) {
      SnackbarHelper.showError(
        context,
        'Please enter a valid server address starting with https:// or http://',
      );
      return;
    }
    if (key.isEmpty) {
      SnackbarHelper.showError(
        context,
        'Please enter your server access key',
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

      // Verify connectivity before leaving SetupScreen
      await SupabaseService.client.from('profiles').select('id').limit(1);

      if (mounted) {
        widget.onConfigured();
      }
    } catch (e) {
      if (mounted) {
        final msg = AuthService.isNetworkError(e)
            ? 'Unable to reach the server at $url. Please check the server address and your internet connection.'
            : 'Connection failed: ${AuthService.formatAuthError(e)}';
        SnackbarHelper.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleUseDefaultServer() async {
    _urlController.text = _defaultWaitakiUrl;
    _keyController.text = _defaultWaitakiKey;
    await _handleConnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.line(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Header
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.brand(context).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.cloud_done_outlined,
                          color: AppColors.brand(context),
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Server Connection Setup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your server address and access key to connect to the Waitaki Old Boys Network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.subtext(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Server Address Input
                    Text(
                      'Server Address (URL)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.body(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'https://your-server.supabase.co',
                        prefixIcon: Icon(Icons.link, size: 20),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Access Key Input with Show/Hide toggle
                    Text(
                      'Access Key',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.body(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _keyController,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        hintText: 'Paste your server access key',
                        prefixIcon: const Icon(Icons.key, size: 20),
                        suffixIcon: IconButton(
                          tooltip: _obscureKey
                              ? 'Show access key'
                              : 'Hide access key',
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                            color: AppColors.muted(context),
                          ),
                          onPressed: () => setState(
                            () => _obscureKey = !_obscureKey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleConnect,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
                    const SizedBox(height: 12),

                    TextButton.icon(
                      onPressed: _isSaving ? null : _handleUseDefaultServer,
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Use Default Waitaki Server'),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Need help connecting? Please contact your Waitaki Old Boys Network administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                        height: 1.35,
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
