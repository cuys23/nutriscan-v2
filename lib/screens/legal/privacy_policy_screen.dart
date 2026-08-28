import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/policy/policy_header.dart';
import 'package:nutriscan/widgets/policy/policy_section.dart';
import 'package:provider/provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(
              'Privacy Policy',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(IconlyLight.arrow_left, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const PolicyHeader(
                  title: 'Privacy Policy',
                  subtitle: 'Last updated: April 17, 2026',
                  icon: Icons.privacy_tip,
                ),
                const SizedBox(height: 24),

                // Content Sections
                const PolicySection(
                  title: 'Information We Collect',
                  content:
                      'We collect information you provide directly to us, such as when you create an account using Google Sign-In or email. We also collect images you upload for nutrition analysis to provide our core AI-powered services. Authentication and cloud storage are managed through Firebase.',
                  icon: Icons.collections,
                ),

                const PolicySection(
                  title: 'AI Processing (Groq)',
                  content:
                      'For food image analysis and nutrition estimation, we utilize Groq Cloud AI services. When you upload an image, it is temporarily processed by Groq to generate nutrition data. We do not use your personal images to train general AI models.',
                  icon: Icons.auto_awesome,
                ),

                const PolicySection(
                  title: 'Payments & Subscriptions',
                  content:
                      'We use Google Play Billing and Apple App Store In-App Purchases to handle premium subscriptions. All payment information is processed securely by Google or Apple; we do not store your credit card details on our own servers.',
                  icon: Icons.payment,
                ),

                const PolicySection(
                  title: 'Advertising (AdMob)',
                  content:
                      'We use Google AdMob to display advertisements. AdMob may collect and use certain data (like advertising IDs) to show personalized ads. Premium users can enjoy an ad-free experience.',
                  icon: Icons.ads_click,
                ),

                const PolicySection(
                  title: 'Data Security & Storage',
                  content:
                      'Your data is stored securely using Firebase Firestore and Firebase Auth. We implement industry-standard encryption and security measures provided by Google Cloud Platform to protect your information against unauthorized access.',
                  icon: Icons.security,
                ),

                const PolicySection(
                  title: 'Your Rights',
                  content:
                      'You have the right to access, update, or delete your personal information. You can delete your account and all associated data directly from the Settings menu in the app at any time.',
                  icon: Icons.person,
                ),

                const PolicySection(
                  title: 'Contact Us',
                  content:
                      'If you have any questions about this Privacy Policy, please contact us at support@nutriscan.ai. We are committed to protecting your privacy and being transparent about our data practices.',
                  icon: Icons.contact_support,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
