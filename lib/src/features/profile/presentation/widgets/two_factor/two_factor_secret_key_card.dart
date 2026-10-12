import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Step 2 card displaying the raw secret key for manual entry in authenticators.
class TwoFactorSecretKeyCard extends StatelessWidget {
  const TwoFactorSecretKeyCard({
    required this.secretKey,
    super.key,
  });

  final String secretKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(90),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Or Copy Secret Key Manually',
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 80 : 50),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    secretKey.isNotEmpty
                        ? secretKey
                        : 'Generating secret key...',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 13.5,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return AnimatedScale(
                      scale: isHovered ? 1.04 : 1.0,
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutCubic,
                      child: child,
                    );
                  },
                  child: ShrinkableButton(
                    onTap: secretKey.isEmpty
                        ? () {}
                        : () {
                            AppFeedback.selection();
                            unawaited(
                              Clipboard.setData(
                                ClipboardData(text: secretKey),
                              ),
                            );
                            context.showSnackBar(
                              message: 'Secret key copied to clipboard!',
                              type: SnackBarType.success,
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(25),
                        borderRadius: AppRadius.radiusBadge,
                        border: Border.all(
                          color: colors.primary.withAlpha(70),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
