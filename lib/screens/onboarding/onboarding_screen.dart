import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _profileService = ProfileService();
  final _picker = ImagePicker();
  final _pageController = PageController();

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  Profile? _profile;

  // Step 1: Heritage
  String? _selectedHouse;
  final _customHouseController = TextEditingController();
  final _gradYearController = TextEditingController();

  // Step 2: Location & Profession
  final _cityController = TextEditingController();
  final _headlineController = TextEditingController();
  final _companyController = TextEditingController();
  String? _selectedIndustry;
  final _customIndustryController = TextEditingController();

  // Step 3: Story & Mentorship
  final _bioController = TextEditingController();
  String? _avatarUrl;
  bool _openToHelping = true;

  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // WBHS Houses definitions (All 7 historic & day houses)
  static const List<Map<String, dynamic>> _wbhsHouses = [
    {
      'name': 'Don',
      'color': Color(0xFF16A34A),
      'colorName': 'Green',
      'description': 'Green House • Named after Patrick Don',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Founders',
      'color': Color(0xFF64748B),
      'colorName': 'Grey',
      'description': 'Grey House • Honours school founders',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Forrester',
      'color': Color(0xFF1D4ED8),
      'colorName': 'Blue',
      'description': 'Blue House • Named after Thomas Forrester',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Lee',
      'color': Color(0xFFD97706),
      'colorName': 'Yellow',
      'description': 'Yellow House • Named after early Waitaki leaders',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Harkness',
      'color': Color(0xFF0891B2),
      'colorName': 'Cyan',
      'description': 'Cyan House • Named after George Harkness',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Milner',
      'color': Color(0xFF881337),
      'colorName': 'Maroon',
      'description': 'Maroon House • Named after Frank Milner',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Sutherland',
      'color': Color(0xFF334155),
      'isWhite': true,
      'colorName': 'White',
      'description': 'White House • Named after Jack Sutherland',
      'icon': Icons.shield_rounded,
    },
  ];

  // Industry sectors
  static const List<String> _industries = [
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

  // Quick City Suggestions
  static const List<String> _popularCities = [
    'Oamaru',
    'Dunedin',
    'Christchurch',
    'Wellington',
    'Auckland',
    'Queenstown',
    'Sydney',
    'London',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final p = await _profileService.getCurrentProfile();
      if (p != null && mounted) {
        setState(() {
          _profile = p;
          if (p.gradYear != null) {
            _gradYearController.text = p.gradYear.toString();
          }
          if (p.house != null && p.house!.isNotEmpty) {
            final match = _wbhsHouses.any((h) => h['name'] == p.house);
            if (match) {
              _selectedHouse = p.house;
            } else {
              _selectedHouse = 'Other';
              _customHouseController.text = p.house!;
            }
          }
          if (p.city != null && p.city!.isNotEmpty) {
            _cityController.text = p.city!;
          }
          if (p.headline != null && p.headline!.isNotEmpty) {
            _headlineController.text = p.headline!;
          }
          if (p.company != null && p.company!.isNotEmpty) {
            _companyController.text = p.company!;
          }
          if (p.industry != null && p.industry!.isNotEmpty) {
            if (_industries.contains(p.industry)) {
              _selectedIndustry = p.industry;
            } else {
              _selectedIndustry = 'Other';
              _customIndustryController.text = p.industry!;
            }
          }
          if (p.bio != null && p.bio!.isNotEmpty) {
            _bioController.text = p.bio!;
          }
          _avatarUrl = p.avatarUrl;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customHouseController.dispose();
    _gradYearController.dispose();
    _cityController.dispose();
    _headlineController.dispose();
    _companyController.dispose();
    _customIndustryController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
      if (_selectedHouse == null) {
        SnackbarHelper.showError(context, 'Please select your School House');
        return;
      }
    } else if (_currentStep == 1) {
      if (!_formKeyStep2.currentState!.validate()) return;
      if (_selectedIndustry == null) {
        SnackbarHelper.showError(context, 'Please select your Industry');
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _handleFinish();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _handleSkip() async {
    setState(() => _isLoading = true);
    await _profileService.skipOnboarding();
    if (mounted) {
      widget.onCompleted();
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';

      final publicUrl = await _profileService.uploadAvatar(bytes, ext);
      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
        });
        SnackbarHelper.showSuccess(context, 'Avatar uploaded!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to upload photo: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _handleFinish() async {
    setState(() => _isLoading = true);

    try {
      final gradYear = int.tryParse(_gradYearController.text.trim()) ?? 2015;
      final house = _selectedHouse == 'Other'
          ? _customHouseController.text.trim()
          : (_selectedHouse ?? 'Don');

      final industry = _selectedIndustry == 'Other'
          ? _customIndustryController.text.trim()
          : (_selectedIndustry ?? 'General');

      await _profileService.completeOnboarding(
        house: house.isNotEmpty ? house : 'Don',
        gradYear: gradYear,
        city: _cityController.text.trim(),
        headline: _headlineController.text.trim(),
        industry: industry.isNotEmpty ? industry : 'General',
        company: _companyController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _avatarUrl,
        openToHelping: _openToHelping,
      );

      if (mounted) {
        final name = _profile?.firstName ?? 'Old Boy';
        SnackbarHelper.showSuccess(
          context,
          'Welcome to the Waitaki Old Boys Network, $name!',
        );
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save profile: $e');
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // Top App Bar / Progress Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            height: 38,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Waitaki Old Boys',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.navyDark,
                                ),
                              ),
                              Text(
                                'Alumni Profile Setup',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _handleSkip,
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step Indicator Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStepPill(0, '1. Heritage'),
                          const SizedBox(width: 8),
                          _buildStepPill(1, '2. Location & Career'),
                          const SizedBox(width: 8),
                          _buildStepPill(2, '3. Your Story'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / 3,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.navyPrimary,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form Page View
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1Heritage(),
                      _buildStep2LocationAndJob(),
                      _buildStep3StoryAndPhoto(),
                    ],
                  ),
                ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: const Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _prevStep,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back'),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentStep == 2
                                        ? 'Finish & Enter Network'
                                        : 'Continue',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _currentStep == 2
                                        ? Icons.check_circle_outline
                                        : Icons.arrow_forward,
                                    size: 18,
                                  ),
                                ],
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
    );
  }

  Widget _buildStepPill(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.navyPrimary.withValues(alpha: 0.1)
              : (isDone ? AppColors.surfaceMuted : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? AppColors.navyPrimary
                : (isDone ? AppColors.textPrimary : AppColors.textMuted),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ===========================================================================
  // Step 1: Waitaki Heritage (House & Graduation Year)
  // ===========================================================================
  Widget _buildStep1Heritage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Waitaki Heritage',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Help Old Boys find and connect with you by selecting your school house and final year.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Graduation Year Field
            TextFormField(
              controller: _gradYearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Graduation / Final Year at WBHS',
                hintText: 'e.g. 2014',
                prefixIcon: Icon(Icons.school_outlined, size: 20),
                helperText: 'Enter the final year you attended Waitaki Boys\' High School',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Graduation year is required';
                final parsed = int.tryParse(v.trim());
                if (parsed == null || parsed < 1920 || parsed > 2035) {
                  return 'Please enter a valid year between 1920 and 2035';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Quick Year Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildQuickYearChip('2024'),
                _buildQuickYearChip('2020'),
                _buildQuickYearChip('2015'),
                _buildQuickYearChip('2010'),
                _buildQuickYearChip('2005'),
                _buildQuickYearChip('2000'),
                _buildQuickYearChip('1990'),
                _buildQuickYearChip('1980'),
              ],
            ),
            const SizedBox(height: 28),

            // School House Selector
            Row(
              children: const [
                Icon(Icons.shield_outlined, size: 18, color: AppColors.navyPrimary),
                SizedBox(width: 8),
                Text(
                  'Select Your School House',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // All 7 WBHS Houses Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 450;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isCompact ? 1 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isCompact ? 4.0 : 2.05,
                  ),
                  itemCount: _wbhsHouses.length,
                  itemBuilder: (context, index) {
                    final house = _wbhsHouses[index];
                    final name = house['name'] as String;
                    final color = house['color'] as Color;
                    final colorName = house['colorName'] as String;
                    final desc = house['description'] as String;
                    final isWhite = house['isWhite'] == true;
                    final isSelected = _selectedHouse == name;

                    return InkWell(
                      onTap: () => setState(() => _selectedHouse = name),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isWhite
                                  ? AppColors.navyPrimary.withValues(alpha: 0.06)
                                  : color.withValues(alpha: 0.08))
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? (isWhite ? AppColors.navyPrimary : color)
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isWhite
                                    ? const Color(0xFF1E293B)
                                    : color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: isWhite
                                    ? Border.all(
                                        color: const Color(0xFF94A3B8),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Icon(
                                Icons.shield,
                                color: isWhite ? Colors.white : color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '$name House',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: isSelected
                                                ? (isWhite ? AppColors.navyDark : color)
                                                : AppColors.navyDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isWhite
                                              ? Colors.white
                                              : color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isWhite
                                                ? const Color(0xFF94A3B8)
                                                : color.withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          colorName,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: isWhite
                                                ? const Color(0xFF334155)
                                                : color,
                                          ),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: isWhite
                                              ? AppColors.navyPrimary
                                              : color,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Other House Option (e.g. Boarding Houses)
            InkWell(
              onTap: () => setState(() => _selectedHouse = 'Other'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedHouse == 'Other'
                      ? AppColors.navyPrimary.withValues(alpha: 0.08)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedHouse == 'Other'
                        ? AppColors.navyPrimary
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hotel_outlined, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Boarding / Other House (e.g. Fraser, Campbell, or Custom)',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    if (_selectedHouse == 'Other') ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, size: 16, color: AppColors.navyPrimary),
                    ],
                  ],
                ),
              ),
            ),
            if (_selectedHouse == 'Other') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _customHouseController,
                decoration: const InputDecoration(
                  labelText: 'Enter House Name',
                  hintText: 'e.g. Fraser House',
                ),
                validator: (v) {
                  if (_selectedHouse == 'Other' && (v == null || v.trim().isEmpty)) {
                    return 'Please enter your house name';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickYearChip(String year) {
    final isSelected = _gradYearController.text == year;
    return ChoiceChip(
      label: Text(year),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _gradYearController.text = year;
        });
      },
      selectedColor: AppColors.goldAccent.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.goldDark : AppColors.textPrimary,
      ),
    );
  }

  // ===========================================================================
  // Step 2: Location & Current Profession
  // ===========================================================================
  Widget _buildStep2LocationAndJob() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeyStep2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location & Profession',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Share where you are based and what you do. Fellow Old Boys frequently connect for career advice and local networks.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // City / Location Field
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Current City / Location',
                hintText: 'e.g. Auckland, Oamaru, London, Sydney',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Location is required' : null,
            ),
            const SizedBox(height: 10),

            // Popular City Suggestions
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _popularCities.map((city) {
                final isSelected = _cityController.text.trim().toLowerCase() ==
                    city.toLowerCase();
                return ActionChip(
                  label: Text(city),
                  backgroundColor: isSelected
                      ? AppColors.navyPrimary.withValues(alpha: 0.15)
                      : AppColors.surfaceMuted,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? AppColors.navyPrimary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onPressed: () {
                    setState(() => _cityController.text = city);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Job Title / Headline
            TextFormField(
              controller: _headlineController,
              decoration: const InputDecoration(
                labelText: 'Job Title / Role / Profession',
                hintText: 'e.g. Senior Partner • AgriTech Founder • Civil Engineer',
                prefixIcon: Icon(Icons.work_outline, size: 20),
                helperText: 'Your role or current occupation (students & retirees welcome)',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Job or occupation is required' : null,
            ),
            const SizedBox(height: 18),

            // Company / Organisation Field
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company / Organisation (Optional)',
                hintText: 'e.g. Fonterra, Bell Gully, Fulton Hogan, Self-employed',
                prefixIcon: Icon(Icons.business_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 24),

            // Industry Sector Selection
            Row(
              children: const [
                Icon(Icons.category_outlined, size: 18, color: AppColors.navyPrimary),
                SizedBox(width: 8),
                Text(
                  'Industry / Sector',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _industries.map((ind) {
                final isSelected = _selectedIndustry == ind;
                return ChoiceChip(
                  label: Text(ind),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedIndustry = ind);
                  },
                  selectedColor: AppColors.navyPrimary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.navyPrimary
                        : AppColors.textPrimary,
                  ),
                );
              }).toList(),
            ),
            if (_selectedIndustry == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customIndustryController,
                decoration: const InputDecoration(
                  labelText: 'Specify Industry',
                  hintText: 'e.g. Renewable Energy, Aquaculture',
                ),
                validator: (v) {
                  if (_selectedIndustry == 'Other' &&
                      (v == null || v.trim().isEmpty)) {
                    return 'Please specify your industry';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Step 3: Story, Photo & Mentorship
  // ===========================================================================
  Widget _buildStep3StoryAndPhoto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Story & Community',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete your profile with a photo, a short bio, and let fellow Old Boys know if you are open to mentoring.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Avatar Photo Uploader
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navyPrimary, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.1),
                        backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(_avatarUrl!)
                            : null,
                        child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? Text(
                                _profile?.initials ?? 'OB',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navyPrimary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.navyPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: _isUploadingAvatar
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: Text(
                    (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? 'Change Profile Photo'
                        : 'Upload Profile Photo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Short Bio Field
          TextFormField(
            controller: _bioController,
            minLines: 3,
            maxLines: 5,
            maxLength: 600,
            decoration: const InputDecoration(
              labelText: 'About / Short Bio',
              hintText:
                  'Share a brief story about your career path, fond memories of Waitaki, sports or extracurriculars, or what you are up to now...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Mentorship Toggle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _openToHelping
                    ? AppColors.goldAccent.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.goldAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_outlined,
                    color: AppColors.goldDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Open to Mentoring Fellow Old Boys',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Willing to offer advice, school guidance, or industry insights to younger Waitakians.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _openToHelping,
                  activeThumbColor: AppColors.goldDark,
                  onChanged: (val) => setState(() => _openToHelping = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
