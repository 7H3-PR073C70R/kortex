import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Subpage displaying app version, documentation, support, and legal links.
class AboutSupportPage extends StatelessWidget {
  const AboutSupportPage({super.key});

  static const String discordUrl = 'https://discord.gg/kortex';
  static const String docsUrl = 'https://docs.kortexify.com';
  static const String privacyPolicyUrl = 'https://kortexify.com/privacy';
  static const String termsUrl = 'https://kortexify.com/terms';

  Future<void> _launchExternalUrl(BuildContext context, String url) async {
    AppFeedback.light();
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Opening $url',
          );
        }
      }
    } on Object catch (_) {
      if (context.mounted) {
        context.showSnackBar(
          message: 'Could not open link.',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About & Support',
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              // 1. Kortexify Brand Hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withAlpha(40),
                      colors.surfaceSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.primary.withAlpha(80),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.syllabotAccent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kortexify',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next-Gen STEM & Exam Mastery Engine',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfacePrimary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Text(
                        'v1.0.0+1 • Production STEM Engine',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Resources & Community Links
              _buildLinkCard(
                icon: Icons.forum_rounded,
                title: 'Community Discord & Study Rooms',
                subtitle: 'Join study rooms, share decks, and get help',
                onTap: () => _launchExternalUrl(context, discordUrl),
                colors: colors,
                typography: typography,
              ),
              const SizedBox(height: 12),
              _buildLinkCard(
                icon: Icons.help_outline_rounded,
                title: 'Documentation & Knowledgebase',
                subtitle: 'Guides on Syllabot AI and FSRS spaced repetition',
                onTap: () => _launchExternalUrl(context, docsUrl),
                colors: colors,
                typography: typography,
              ),
              const SizedBox(height: 12),
              _buildLinkCard(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we securely store and encrypt your data',
                onTap: () => _launchExternalUrl(context, privacyPolicyUrl),
                colors: colors,
                typography: typography,
              ),
              const SizedBox(height: 12),
              _buildLinkCard(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'End user license agreements and policies',
                onTap: () => _launchExternalUrl(context, termsUrl),
                colors: colors,
                typography: typography,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(80),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
