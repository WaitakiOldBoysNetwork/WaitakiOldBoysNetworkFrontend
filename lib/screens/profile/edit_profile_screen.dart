import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Profile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _headlineController;
  late TextEditingController _cityController;
  late TextEditingController _gradYearController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.profile.firstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.profile.lastName ?? '');
    _headlineController =
        TextEditingController(text: widget.profile.headline ?? '');
    _cityController = TextEditingController(text: widget.profile.city ?? '');
    _gradYearController = TextEditingController(
      text: widget.profile.gradYear != null
          ? widget.profile.gradYear.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _headlineController.dispose();
    _cityController.dispose();
    _gradYearController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final gradYear = int.tryParse(_gradYearController.text.trim());
      await _profileService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        headline: _headlineController.text.trim(),
        gradYear: gradYear,
        city: _cityController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _headlineController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Headline / Role',
                      hintText: 'e.g. Senior Partner at Chapman Tripp • Tech Founder',
                      helperText: 'Your current role, company, or profession',
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _gradYearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Waitaki Graduation / Final Year',
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
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Current City / Location',
                      hintText: 'e.g. Auckland, New Zealand',
                      prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
