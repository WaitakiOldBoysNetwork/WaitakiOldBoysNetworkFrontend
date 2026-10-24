import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/unified_auth_service.dart';

/// Modern, Frictionless 3-Step Onboarding Flow Screen
/// Features PageView progression, animated sticky indicators, interactive multi-select chips,
/// educational permission cards, avatar presets, and SharedPreferences step persistence.
class OnboardingFlowScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingFlowScreen({super.key, this.onCompleted});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final _authService = UnifiedAuthService();
  final _pageController = PageController();
  final _picker = ImagePicker();

  int _currentPage = 0;
  bool _isSaving = false;

  // Step 1: Profile Basics
  final _fullNameController = TextEditingController();
  String? _selectedAvatarUrl;
  int _selectedPresetIndex = 0;

  static const List<Map<String, dynamic>> _avatarPresets = [
    {
      'label': 'WB',
      'sub': 'Navy',
      'bg': Color(0xFF0F2547),
      'fg': Color(0xFFD4AF37),
      'url':
          'https://ui-avatars.com/api/?name=WB&background=0F2547&color=D4AF37&bold=true&size=256',
    },
    {
      'label': '1883',
      'sub': 'Gold',
      'bg': Color(0xFFD4AF37),
      'fg': Color(0xFF0F2547),
      'url':
          'https://ui-avatars.com/api/?name=1883&background=D4AF37&color=0F2547&bold=true&size=256',
    },
    {
      'label': 'OB',
      'sub': 'Crimson',
      'bg': Color(0xFF8E1B24),
      'fg': Colors.white,
      'url':
          'https://ui-avatars.com/api/?name=OB&background=8E1B24&color=FFFFFF&bold=true&size=256',
    },
    {
      'label': 'Waitaki',
      'sub': 'Classic',
      'bg': Color(0xFF1E3A66),
      'fg': Color(0xFFD4AF37),
      'url':
          'https://ui-avatars.com/api/?name=Waitaki&background=1E3A66&color=D4AF37&bold=true&size=256',
    },
  ];

  // Step 2: Preferences / Interests (Multi-Select Chips)
  final Set<String> _selectedInterests = {
    'Mentoring Younger Alumni',
    'Reunions & Gatherings',
    'Business Opportunities',
  };

  static const List<Map<String, dynamic>> _interestCategories = [
    {
      'category': 'Career & Mentorship',
      'items': [
        'Tech & Software',
        'Agribusiness & Farming',
        'Legal & Advisory',
        'Engineering & Trades',
        'Mentoring Younger Alumni',
        'Hiring & Internships',
      ],
    },
    {
      'category': 'Heritage & WBHS Spirit',
      'items': [
        'School Archives & History',
        'Sports & Rugby Fixtures',
        'Reunions & Gatherings',
        'Hall of Fame & Honours',
      ],
    },
    {
      'category': 'Community & Regions',
      'items': [
        'Otago & Oamaru Locals',
        'Auckland Chapter',
        'Wellington Chapter',
        'Overseas (UK, Aus, US)',
        'Business Opportunities',
      ],
    },
  ];

  // Step 3: Permissions & Notifications
  bool _notificationsEnabled = true;
  bool _mentoringRequestsEnabled = true;
  bool _newsletterDigestEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPersistedStep();
  }

  Future<void> _loadPersistedStep() async {
    final savedStep = await _authService.getSavedOnboardingStep();
    if (savedStep > 0 && savedStep < 3 && mounted) {
      setState(() => _currentPage = savedStep);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(savedStep);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _authService.saveOnboardingStep(page);
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_fullNameController.text.trim().isEmpty) {
        SnackbarHelper.showError(context, 'Please enter your full name');
        return;
      }
    }

    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeFlow();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _pickCustomAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedAvatarUrl = image.path;
          _selectedPresetIndex = -1;
        });
      }
    } catch (_) {
      // Mock/fallback if platform media picker is denied
    }
  }

  Future<void> _completeFlow() async {
    setState(() => _isSaving = true);
    final fullName = _fullNameController.text.trim();
    final avatar = _selectedAvatarUrl ??
        _avatarPresets[_selectedPresetIndex >= 0 ? _selectedPresetIndex : 0]
            ['url']!;

    await _authService.completeOnboarding(
      fullName: fullName.isNotEmpty ? fullName : 'Old Boy',
      avatarUrl: avatar,
      interests: _selectedInterests.toList(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: AppColors.navyDark,
                onPressed: _previousPage,
              )
            : null,
        actions: [
          TextButton(
            onPressed: _completeFlow,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              children: [
                // Top Progress Pill Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: List.generate(3, (index) {
                      final isCurrent = index == _currentPage;
                      final isCompleted = index < _currentPage;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: isCompleted
                                ? AppColors.goldAccent
                                : (isCurrent
                                    ? AppColors.navyPrimary
                                    : AppColors.border),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Multi-Step PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    children: [
                      _buildStep1ProfileBasics(),
                      _buildStep2Interests(),
                      _buildStep3Permissions(),
                    ],
                  ),
                ),

                // Sticky Bottom Bar
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Step ${_currentPage + 1} of 3',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _currentPage == 2
                                    ? 'Complete Setup'
                                    : 'Continue',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
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

  // ===========================================================================
  // Step 1: Profile Basics (Name + Avatar Selector)
  // ===========================================================================
  Widget _buildStep1ProfileBasics() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Welcome! Let’s set up your profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navyDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This is how other Old Boys, teachers, and classmates will recognize you.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Avatar Preview & Upload Action
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: _selectedPresetIndex >= 0
                      ? (_avatarPresets[_selectedPresetIndex]['bg'] as Color)
                      : AppColors.navyPrimary,
                  child: Text(
                    _selectedPresetIndex >= 0
                        ? (_avatarPresets[_selectedPresetIndex]['label'] as String)
                        : 'OB',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _selectedPresetIndex >= 0
                          ? (_avatarPresets[_selectedPresetIndex]['fg'] as Color)
                          : AppColors.goldAccent,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickCustomAvatar,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.goldAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: AppColors.navyDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Preset Avatars Selector
          const Center(
            child: Text(
              'Choose a badge avatar or upload your photo',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_avatarPresets.length, (i) {
              final isSelected = _selectedPresetIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPresetIndex = i;
                    _selectedAvatarUrl = null;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.goldAccent
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: _avatarPresets[i]['bg'] as Color,
                    child: Text(
                      _avatarPresets[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _avatarPresets[i]['fg'] as Color,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // Full Name Input Field
          TextFormField(
            controller: _fullNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _nextPage(),
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'e.g. John Campbell',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Step 2: Preferences / Interests (Multi-Select Chips)
  // ===========================================================================
  Widget _buildStep2Interests() {
    final count = _selectedInterests.length;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'What are you interested in?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'We will tailor your feed, reunions, and mentoring connections.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: count >= 3
                      ? AppColors.goldAccent.withValues(alpha: 0.18)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: count >= 3
                        ? AppColors.goldAccent
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  '$count selected (3+ rec)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: count >= 3 ? AppColors.goldDark : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Categories & Chips
          ..._interestCategories.map((group) {
            final category = group['category'] as String;
            final items = group['items'] as List<String>;

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.map((item) {
                      final isSelected = _selectedInterests.contains(item);
                      return FilterChip(
                        label: Text(item),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedInterests.add(item);
                            } else {
                              _selectedInterests.remove(item);
                            }
                          });
                        },
                        selectedColor:
                            AppColors.navyPrimary.withValues(alpha: 0.12),
                        checkmarkColor: AppColors.navyPrimary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.navyPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.navyPrimary
                                : AppColors.border,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // Step 3: Permissions / Notifications (Educational Pre-Prompts)
  // ===========================================================================
  Widget _buildStep3Permissions() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Stay connected with Waitaki',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navyDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Customize which updates you receive so you never miss an important milestone.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Permission Item 1: Event & Reunion Alerts
          _buildPermissionCard(
            icon: Icons.notifications_active_outlined,
            title: 'Reunions & Event Announcements',
            subtitle:
                'Get timely reminders when annual dinners, reunions, or matches are in your city.',
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          const SizedBox(height: 14),

          // Permission Item 2: Mentoring & Alumni Reachouts
          _buildPermissionCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'Mentoring & Connection Requests',
            subtitle:
                'Allow verified Waitaki Old Boys to invite you to connect or request advice.',
            value: _mentoringRequestsEnabled,
            onChanged: (val) =>
                setState(() => _mentoringRequestsEnabled = val),
          ),
          const SizedBox(height: 14),

          // Permission Item 3: Official Newsletter & Hail Publications
          _buildPermissionCard(
            icon: Icons.newspaper_outlined,
            title: 'Official WBHS Hail.to Articles',
            subtitle:
                'Receive term updates, Rector notices, and Fraser Farm publications directly.',
            value: _newsletterDigestEnabled,
            onChanged: (val) =>
                setState(() => _newsletterDigestEnabled = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navyPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.navyPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.navyPrimary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
