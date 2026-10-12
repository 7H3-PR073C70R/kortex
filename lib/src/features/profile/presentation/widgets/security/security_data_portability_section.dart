import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Data Portability & Export section for Anki/PDF/CSV decks and GDPR bundles.
class SecurityDataPortabilitySection extends StatelessWidget {
  const SecurityDataPortabilitySection({
    required this.onExportDecks,
    required this.onExportGdprBundle,
    super.key,
  });

  final VoidCallback onExportDecks;
  final VoidCallback onExportGdprBundle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SecuritySectionContainer(
      title: 'Data Portability & Export',
      subtitle: 'Export your flashcard decks and study notes',
      child: Column(
        children: [
          _buildExportOption(
            icon: Icons.ios_share_rounded,
            title: 'Export Study Decks (Anki, CSV, PDF)',
            subtitle: 'Export active decks with full SRS intervals',
            onTap: onExportDecks,
            colors: colors,
            typography: typography,
          ),
          const Divider(height: 1),
          _buildExportOption(
            icon: Icons.download_for_offline_outlined,
            title: 'Export Account Data (GDPR JSON Bundle)',
            subtitle:
                'Download complete structured JSON archive of all study progress',
            onTap: onExportGdprBundle,
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: Curves.easeOutCubic,
          transform: isHovered
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          child: child,
        );
      },
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: AppRadius.radiusCard,
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
                  borderRadius: AppRadius.radiusCard,
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
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
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
      ),
    );
  }
}
