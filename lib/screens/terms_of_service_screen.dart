import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
                    'Terms of Service',
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
                      '1. Acceptance of Terms',
                      'By accessing or using the Trenzy app, you agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree, please do not use the app.',
                    ),
                    _section(
                      context,
                      '2. Description of Service',
                      'Trenzy is a fashion discovery platform that helps you find clothing and footwear through search, personalized recommendations, and social shopping sessions. Products featured in Trenzy are offered for sale by third-party partner stores; Trenzy itself does not sell or ship products directly.',
                    ),
                    _section(
                      context,
                      '3. Accounts',
                      'You are responsible for safeguarding your account credentials and for all activity that occurs under your account. You must be at least 13 years old to use the app, and you must provide accurate information when creating an account.',
                    ),
                    _section(
                      context,
                      '4. Acceptable Use',
                      'You agree not to misuse the service, including: submitting false information, attempting to access other users\u2019 accounts, interfering with the service\u2019s operation, scraping content at scale, or using the service for any unlawful purpose.',
                    ),
                    _section(
                      context,
                      '5. Purchases & Partner Stores',
                      'When you are redirected to a partner store to complete a purchase, the sale is governed by that partner\u2019s own terms, pricing, return, and shipping policies. Trenzy is not responsible for the availability, quality, or delivery of items sold by partner stores.',
                    ),
                    _section(
                      context,
                      '6. Intellectual Property',
                      'The Trenzy app, including its design, text, graphics, and software, is owned by or licensed to Trenzy. You may not copy, modify, or redistribute the app or its content without permission. Product information and images remain the property of their respective owners.',
                    ),
                    _section(
                      context,
                      '7. Limitation of Liability',
                      'The service is provided "as is" without warranties of any kind. To the maximum extent permitted by law, Trenzy shall not be liable for any indirect, incidental, or consequential damages arising from your use of the app.',
                    ),
                    _section(
                      context,
                      '8. Changes to These Terms',
                      'We may update these Terms from time to time. Material changes will be communicated within the app. Continued use of the app after changes take effect constitutes acceptance of the revised Terms.',
                    ),
                    _section(
                      context,
                      '9. Termination',
                      'We may suspend or terminate your access if you violate these Terms. You may stop using the app at any time. You can also request account deletion from Settings.',
                    ),
                    _section(
                      context,
                      '10. Contact',
                      'Questions about these Terms can be directed to support through the app\u2019s Help & Support section.',
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
