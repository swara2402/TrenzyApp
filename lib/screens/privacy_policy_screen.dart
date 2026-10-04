import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassBackButton(onTap: () => context.pop()),
                  SizedBox(width: 8),
                  DisplayText(
                    'Privacy Policy',
                    fontSize: 22,
                    weight: FontWeight.w600,
                    color: context.trenzyColors.primary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last updated: August 2026',
                      style: GlassTypography.body(
                        fontSize: 12,
                        color: context.trenzyColors.mutedFg,
                      ),
                    ),
                    SizedBox(height: 16),
                    _section(
                      context,
                      '1. Information We Collect',
                      'We collect information you provide directly, such as your name, email address, and preferences. We also collect data from your device, including your preferences and usage patterns, product views, wishlists, and saved styles. Payments and account-related data are processed through our backend and service providers.',
                    ),
                    _section(
                      context,
                      '2. How We Use Your Information',
                      'We use your information to provide and improve the service: personalizing recommendations, powering search, generating your style persona, enabling social shopping sessions, and communicating about the service. We do not sell your personal information.',
                    ),
                    _section(
                      context,
                      '3. Information Sharing',
                      'We share information with service providers who help operate the app (such as hosting and authentication providers) only as needed to provide the service. We do not sell personal data and we do not use partner-store data collection in the beta experience.',
                    ),
                    _section(
                      context,
                      '4. Data Security',
                      'We use industry-standard safeguards, including encryption in transit and access controls, to protect your information. No method of transmission is 100% secure, and we cannot guarantee absolute security.',
                    ),
                    _section(
                      context,
                      '5. Your Choices & Controls',
                      'You can update your preferences in Settings, request account deletion from Settings, and control push notifications from your device. You may also contact us to request access to or deletion of your personal data.',
                    ),
                    _section(
                      context,
                      '6. Data Retention',
                      'We retain your information for as long as your account is active or as needed to provide the service and meet legal obligations. When you delete your account, we take reasonable steps to remove your data.',
                    ),
                    _section(
                      context,
                      '7. Children\u2019s Privacy',
                      'The app is not directed at children under 13, and we do not knowingly collect personal information from children under 13.',
                    ),
                    _section(
                      context,
                      '8. Changes to This Policy',
                      'We may update this Privacy Policy from time to time. Material changes will be communicated within the app. Your continued use of the app after changes take effect constitutes acceptance of the revised policy.',
                    ),
                    _section(
                      context,
                      '9. Contact Us',
                      'If you have questions about this Privacy Policy, contact us through the app\u2019s Help & Support section.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DisplayText(title, fontSize: 15, weight: FontWeight.w700),
          SizedBox(height: 6),
          Text(
            body,
            style: GlassTypography.body(
              fontSize: 13.5,
              height: 1.6,
              color: context.trenzyColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}
