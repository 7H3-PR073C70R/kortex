import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/lms_import/lms_oauth_result.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Card showing the connected LMS student account with quick disconnect action.
class LmsConnectedAccountCard extends StatelessWidget {
  const LmsConnectedAccountCard({
    required this.account,
    required this.isCanvas,
    required this.onDisconnect,
    super.key,
  });

  final LmsOAuthResult account;
  final bool isCanvas;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceTertiary,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.success.withAlpha(70),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.success.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: colors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lmsConnectedAsStudent(account.accountEmail),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCanvas
                      ? (account.canvasDomain ?? 'Canvas LMS')
                      : 'Google Classroom SSO',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return ShrinkableButton(
                onTap: () {
                  AppFeedback.light();
                  onDisconnect();
                },
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.error.withAlpha(30)
                        : colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(
                      AppRadius.badge,
                    ),
                  ),
                  child: Text(
                    l10n.lmsDisconnect,
                    style: typography.caption.medium.copyWith(
                      color: colors.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
