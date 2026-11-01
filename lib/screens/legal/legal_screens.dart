import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Screen displaying the Waitaki Old Boys Network Privacy Policy.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegalHeader(
                      title: 'Privacy Policy',
                      subtitle:
                          'Waitaki Boys\' High School Old Boys\' Association • Effective 2026',
                      icon: Icons.privacy_tip_outlined,
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      '1. Overview & Commitment to Privacy',
                      'The Waitaki Old Boys Network ("the Network", "we", "our", or "us") is operated for the alumni community of Waitaki Boys\' High School (Oamaru, New Zealand). We are committed to protecting your personal information in accordance with the New Zealand Privacy Act 2020 and applicable data protection laws.',
                    ),
                    _buildSection(
                      '2. Information We Collect',
                      'When you register and participate in the Network, we collect:\n'
                          '• Account & Contact Details: Your full name, email address, phone number, and authentication credentials.\n'
                          '• Waitaki Heritage & Profile Data: Your graduation/final year, age, school house (Don, Founders, Forrester, Lee, Harkness, Milner, or Sutherland), current city/region, profession/headline, company, industry, biography, profile photo, and banner image.\n'
                          '• Community Activity: Posts, comments, likes, mentorship preferences, and connection requests you choose to share within the Network.',
                    ),
                    _buildSection(
                      '3. How We Use Your Information',
                      'Your personal information is used exclusively to:\n'
                          '• Verify your membership as a Waitaki Boys\' High School Old Boy, student, or staff member.\n'
                          '• Display your alumni profile in the authenticated Old Boys Directory so fellow Old Boys can find and connect with you.\n'
                          '• Facilitate mentoring, career networking, reunion announcements, and official Waitaki Boys\' High School updates.\n'
                          '• Maintain the security and integrity of the platform.',
                    ),
                    _buildSection(
                      '4. Directory Visibility & Information Sharing',
                      '• Member-Only Access: Your profile and directory details are only accessible to registered, authenticated members of the Waitaki Old Boys Network.\n'
                          '• No Sale of Personal Data: We never sell, rent, or trade your personal information to third-party advertisers or external marketing agencies.\n'
                          '• Service Providers: We use trusted infrastructure providers (such as Supabase) strictly to host and secure our database and authentication services.',
                    ),
                    _buildSection(
                      '5. Data Security & Storage',
                      'We implement industry-standard security controls, including encrypted connections (HTTPS/TLS) and Row-Level Security (RLS) policies, to ensure that only you can modify your own profile and account data.',
                    ),
                    _buildSection(
                      '6. Your Rights & Account Deletion',
                      'Under the New Zealand Privacy Act 2020, you have the right to access, update, or correct your personal information at any time via the Edit Profile screen.\n\n'
                          'You may also permanently delete your account at any time using the "Delete Account" option in your Profile settings, which immediately erases your profile, posts, comments, likes, and connections from the Network.',
                    ),
                    _buildSection(
                      '7. Contact Us',
                      'If you have any questions or requests regarding this Privacy Policy or your personal data, please contact the Waitaki Boys\' High School Old Boys\' Association via Waitaki Boys\' High School, Waitaki Avenue, Oamaru, New Zealand.',
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

/// Screen displaying the Waitaki Old Boys Network Terms & Conditions.
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TermsAndConditionsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegalHeader(
                      title: 'Terms & Conditions',
                      subtitle:
                          'Waitaki Boys\' High School Old Boys\' Association • Qaunti Est Sapere',
                      icon: Icons.gavel_rounded,
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      '1. Acceptance of Terms',
                      'By creating an account, completing onboarding, or using the Waitaki Old Boys Network ("the Network"), you agree to be bound by these Terms & Conditions and our Privacy Policy.',
                    ),
                    _buildSection(
                      '2. Eligibility & Account Accuracy',
                      '• Membership in the Network is intended for past and present students, staff, and approved affiliates of Waitaki Boys\' High School.\n'
                          '• You agree to provide accurate, truthful information regarding your identity, graduation year, and school house during registration and onboarding.\n'
                          '• You are responsible for maintaining the confidentiality of your account password and login credentials.',
                    ),
                    _buildSection(
                      '3. Community Code of Conduct',
                      'As a member of the Waitaki brotherhood, you agree to uphold the values and traditions of Waitaki Boys\' High School:\n'
                          '• Treat fellow Old Boys, staff, and students with respect and courtesy.\n'
                          '• Do not post content that is unlawful, defamatory, harassing, discriminatory, fraudulent, or spam.\n'
                          '• Do not scrape, harvest, or misuse member contact details from the Old Boys Directory for unsolicited commercial mass-marketing.',
                    ),
                    _buildSection(
                      '4. User-Generated Content',
                      '• You retain ownership of the posts, photos, comments, and profile information you submit to the Network.\n'
                          '• By posting content on the Network, you grant us a non-exclusive license to display and distribute that content to authenticated members of the platform.\n'
                          '• We reserve the right to remove any content or suspend accounts that violate these Terms & Conditions.',
                    ),
                    _buildSection(
                      '5. Mentoring & Professional Networking Disclaimer',
                      'Connections, career opportunities, and mentoring discussions made through the Network are entered into voluntarily between members. The Waitaki Boys\' High School Old Boys\' Association does not guarantee employment outcomes or endorse third-party business ventures posted by members.',
                    ),
                    _buildSection(
                      '6. Termination & Account Removal',
                      'You may terminate your account at any time using the in-app "Delete Account" feature. We reserve the right to suspend or terminate access for any user who breaches these Terms & Conditions or misrepresents their affiliation with Waitaki Boys\' High School.',
                    ),
                    _buildSection(
                      '7. Governing Law',
                      'These Terms & Conditions are governed by and construed in accordance with the laws of New Zealand.',
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

Widget _buildLegalHeader({
  required String title,
  required String subtitle,
  required IconData icon,
}) {
  return Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.navyPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.goldAccent, size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.navyDark,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildSection(String heading, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.navyDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

/// Reusable inline footer widget with clickable links to Privacy Policy and Terms & Conditions.
class LegalLinksFooter extends StatelessWidget {
  final TextAlign textAlign;
  final bool showPrefixText;

  const LegalLinksFooter({
    super.key,
    this.textAlign = TextAlign.center,
    this.showPrefixText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlign == TextAlign.start
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (showPrefixText) ...[
          Text(
            'By using the Waitaki Old Boys Network, you agree to our:',
            textAlign: textAlign,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Wrap(
          alignment: textAlign == TextAlign.start
              ? WrapAlignment.start
              : WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            InkWell(
              onTap: () => TermsAndConditionsScreen.show(context),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const Text(
              '•',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            InkWell(
              onTap: () => PrivacyPolicyScreen.show(context),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
