import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../auth/auth_gate.dart';

class EditProfileScreen extends StatefulWidget {
  final Profile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _profileService = ProfileService();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _headlineController;
  late TextEditingController _cityController;
  late TextEditingController _gradYearController;
  late TextEditingController _bioController;
  late TextEditingController _houseController;
  late TextEditingController _industryController;
  late TextEditingController _companyController;

  String? _bannerUrl;
  bool _isSaving = false;
  bool _isUploadingBanner = false;
  bool _isDeleting = false;

  static const List<Map<String, String>> _wbhsHouses = [
    {'name': 'Don', 'color': 'Green'},
    {'name': 'Founders', 'color': 'Grey'},
    {'name': 'Forrester', 'color': 'Blue'},
    {'name': 'Lee', 'color': 'Yellow'},
    {'name': 'Harkness', 'color': 'Cyan'},
    {'name': 'Milner', 'color': 'Maroon'},
    {'name': 'Sutherland', 'color': 'White'},
  ];

  static const List<String> _commonIndustries = [
    'Agriculture & Farming',
    'Technology & Software',
    'Engineering & Construction',
    'Legal & Professional Services',
    'Banking, Finance & Investment',
    'Healthcare & Medicine',
    'Education & Academia',
    'Trades & Manufacturing',
    'Government & Public Sector',
    'Sports, Fitness & Recreation',
    'Arts, Media & Design',
    'Retail, Hospitality & Tourism',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.profile.firstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.profile.lastName ?? '');
    _phoneController =
        TextEditingController(text: widget.profile.phone ?? '');
    _headlineController =
        TextEditingController(text: widget.profile.headline ?? '');
    _cityController = TextEditingController(text: widget.profile.city ?? '');
    _gradYearController = TextEditingController(
      text: widget.profile.gradYear != null
          ? widget.profile.gradYear.toString()
          : '',
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _houseController = TextEditingController(text: widget.profile.house ?? '');
    _industryController =
        TextEditingController(text: widget.profile.industry ?? '');
    _companyController =
        TextEditingController(text: widget.profile.company ?? '');
    _bannerUrl = widget.profile.bannerUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _headlineController.dispose();
    _cityController.dispose();
    _gradYearController.dispose();
    _bioController.dispose();
    _houseController.dispose();
    _industryController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadBanner() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingBanner = true);

      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';

      final publicUrl = await _profileService.uploadBanner(bytes, ext);

      if (mounted) {
        setState(() {
          _bannerUrl = publicUrl;
        });
        SnackbarHelper.showSuccess(context, 'Banner image uploaded!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to upload banner: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  Future<void> _handleRemoveBanner() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Banner'),
        content: const Text(
          'Reset your banner back to the default Waitaki Boys\' heritage theme?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploadingBanner = true);
    try {
      await _profileService.removeBanner();
      if (mounted) {
        setState(() {
          _bannerUrl = null;
        });
        SnackbarHelper.showSuccess(context, 'Banner reset to default theme');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to remove banner: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final gradYear = int.tryParse(_gradYearController.text.trim());
      await _profileService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        headline: _headlineController.text.trim(),
        gradYear: gradYear,
        city: _cityController.text.trim(),
        house: _houseController.text.trim(),
        industry: _industryController.text.trim(),
        company: _companyController.text.trim(),
        bio: _bioController.text.trim(),
        bannerUrl: _bannerUrl,
      );

      if (mounted) {
        Navigator.pop(context, true);
        SnackbarHelper.showSuccess(context, 'Profile updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.crimson,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Account?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.navyDark,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This action is permanent and cannot be undone. All your profile information, Waitaki heritage data, posts, comments, likes, and network connections will be completely erased.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Permanently Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _profileService.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been permanently deleted.'),
            backgroundColor: AppColors.navyDark,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        SnackbarHelper.showError(context, 'Failed to delete account: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBanner = _bannerUrl != null && _bannerUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Banner Section
                  const Text(
                    'Profile Banner',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 140,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [AppColors.navyDark, AppColors.navyPrimary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasBanner)
                          CachedNetworkImage(
                            imageUrl: _bannerUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.navyDark,
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.navyDark,
                                    AppColors.navyPrimary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.2),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                        ),
                        if (!hasBanner)
                          Positioned(
                            right: 18,
                            top: 20,
                            child: Icon(
                              Icons.school,
                              size: 70,
                              color: AppColors.goldAccent.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                        Center(
                          child: _isUploadingBanner
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Uploading banner...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _pickAndUploadBanner,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.navyDark,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        elevation: 2,
                                      ),
                                      icon: const Icon(Icons.camera_alt, size: 16),
                                      label: Text(
                                        hasBanner
                                            ? 'Change Banner'
                                            : 'Upload Banner',
                                      ),
                                    ),
                                    if (hasBanner)
                                      ElevatedButton.icon(
                                        onPressed: _handleRemoveBanner,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.crimson,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          elevation: 2,
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        label: const Text('Reset'),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Recommended size: 1200 x 400 px (PNG, JPG, or WebP).',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),

                  // Basic Info
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'e.g. 021 123 4567 or +64 21 123 4567',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // School Heritage
                  const Text(
                    'Waitaki Heritage',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gradYearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Final Year / Class of',
                            hintText: 'e.g. 2012',
                            prefixIcon: Icon(Icons.school_outlined, size: 20),
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final val = int.tryParse(v.trim());
                              if (val == null || val < 1920 || val > 2035) {
                                return 'Enter valid year';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _houseController,
                          decoration: InputDecoration(
                            labelText: 'School House',
                            hintText: 'e.g. Don, Lee...',
                            prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                            suffixIcon: PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down),
                              onSelected: (val) {
                                setState(() => _houseController.text = val);
                              },
                              itemBuilder: (context) => _wbhsHouses
                                  .map(
                                    (h) => PopupMenuItem(
                                      value: h['name']!,
                                      child: Text('${h['name']} House (${h['color']})'),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Location & Career
                  const Text(
                    'Location & Profession',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Current City / Location',
                      hintText: 'e.g. Auckland, New Zealand',
                      prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _headlineController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Job Title / Headline',
                      hintText:
                          'e.g. Senior Partner at Chapman Tripp • Tech Founder',
                      helperText: 'Your current role, profession, or occupation',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(
                            labelText: 'Company / Organisation',
                            hintText: 'e.g. Fonterra, Bell Gully',
                            prefixIcon: Icon(Icons.business_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _industryController,
                          decoration: InputDecoration(
                            labelText: 'Industry Sector',
                            hintText: 'e.g. Agriculture',
                            prefixIcon: const Icon(Icons.category_outlined, size: 20),
                            suffixIcon: PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down),
                              onSelected: (val) {
                                if (val != 'Other') {
                                  setState(() => _industryController.text = val);
                                }
                              },
                              itemBuilder: (context) => _commonIndustries
                                  .map(
                                    (ind) => PopupMenuItem(
                                      value: ind,
                                      child: Text(ind),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bio Section
                  const Text(
                    'About & Bio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioController,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 800,
                    decoration: const InputDecoration(
                      labelText: 'Bio / Story',
                      hintText:
                          'Share a brief summary of your journey, your time at Waitaki Boys\', career milestones, or what you enjoy doing today...',
                      helperText:
                          'This will be displayed in your profile About section for other Old Boys to read.',
                      helperMaxLines: 2,
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 24),

                  // Danger Zone: Account Deletion
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.crimson.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.crimson.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.crimson,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Danger Zone',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.crimson,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Permanently delete your Waitaki Old Boys Network account, profile, posts, connections, and personal data. This action cannot be reversed.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _isDeleting ? null : _confirmDeleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.crimson,
                            side: const BorderSide(color: AppColors.crimson),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.crimson,
                                  ),
                                )
                              : const Icon(Icons.delete_forever_rounded, size: 18),
                          label: Text(
                            _isDeleting ? 'Deleting Account...' : 'Delete Account',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
