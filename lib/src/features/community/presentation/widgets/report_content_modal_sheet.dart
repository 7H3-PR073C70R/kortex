import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

enum ReportReason {
  academicMisinformation(
    label: 'Academic Misinformation',
    description:
        'Incorrect formulas, false solutions, or misleading exam answers.',
    icon: Icons.science_outlined,
  ),
  inappropriateContent(
    label: 'Inappropriate or Offensive',
    description: 'Profanity, offensive remarks, or prohibited media.',
    icon: Icons.warning_amber_rounded,
  ),
  spam(
    label: 'Spam or Commercial Promotion',
    description: 'Advertising, external links, or duplicate spam posts.',
    icon: Icons.campaign_outlined,
  ),
  harassment(
    label: 'Harassment or Hostility',
    description: 'Bullying, targeted disrespect, or aggressive behavior.',
    icon: Icons.security_rounded,
  ),
  other(
    label: 'Other Concern',
    description: 'Other issue violating community learning standards.',
    icon: Icons.flag_outlined,
  )
  ;

  const ReportReason({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

class ReportContentModalSheet extends HookWidget {
  const ReportContentModalSheet({
    required this.contentType,
    required this.contentId,
    this.postId,
    this.contentTitle,
    super.key,
  });

  final String contentType;
  final String contentId;
  final String? postId;
  final String? contentTitle;

  static Future<bool?> show(
    BuildContext context, {
    required String contentType,
    required String contentId,
    String? postId,
    String? contentTitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (ctx) => ReportContentModalSheet(
        contentType: contentType,
        contentId: contentId,
        postId: postId,
        contentTitle: contentTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedReason = useState<ReportReason>(
      ReportReason.academicMisinformation,
    );
    final detailsController = useTextEditingController();
    final isSubmitting = useState<bool>(false);

    Future<void> submitReport() async {
      isSubmitting.value = true;
      unawaited(HapticFeedback.mediumImpact());

      try {
        if (locator.isRegistered<CommunityRemoteDataSource>()) {
          final dataSource = locator<CommunityRemoteDataSource>();
          await dataSource.reportContent(
            contentType: contentType,
            contentId: contentId,
            postId: postId,
            reason: selectedReason.value.label,
            details: detailsController.text.trim().isNotEmpty
                ? detailsController.text.trim()
                : null,
          );
        }

        AppFeedback.heavy();
        if (context.mounted) {
          Navigator.of(context).pop(true);
          context.showSnackBar(
            message:
                'Report submitted. Our moderation team will review this discussion within 24 hours.',
            type: SnackBarType.success,
          );
        }
      } on Object catch (_) {
        if (context.mounted) {
          Navigator.of(context).pop(true);
          context.showSnackBar(
            message:
                'Report received. Thank you for keeping our learning community safe.',
            type: SnackBarType.success,
          );
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? colors.surfacePrimary : colors.surfaceSecondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(60),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 100 : 30),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withAlpha(60),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.error.withAlpha(isDark ? 50 : 25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.error.withAlpha(100),
                            ),
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            color: colors.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Discussion',
                                style: typography.title3.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                contentTitle != null
                                    ? 'Reviewing "$contentTitle"'
                                    : 'Help keep Kortex safe and academically accurate.',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Report reasons list
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why are you reporting this?',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          ...ReportReason.values.map((reason) {
                            final isSelected = selectedReason.value == reason;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: PlatformHoverBuilder(
                                builder: (context, isHovered, child) => ShrinkableButton(
                                  onTap: () {
                                    unawaited(HapticFeedback.selectionClick());
                                    selectedReason.value = reason;
                                  },
                                  child: AnimatedContainer(
                                    duration: AppMotion.snappy,
                                    curve: AppMotion.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colors.primary.withAlpha(
                                              isDark ? 40 : 25,
                                            )
                                          : isHovered
                                          ? (isDark
                                                ? colors.surfaceElevated
                                                : colors.surfacePrimary)
                                          : colors.surfacePrimary.withAlpha(
                                              isDark ? 160 : 220,
                                            ),
                                      borderRadius: AppRadius.radiusCard,
                                      border: Border.all(
                                        color: isSelected
                                            ? colors.primary
                                            : isHovered
                                            ? colors.primary.withAlpha(
                                                isDark ? 80 : 50,
                                              )
                                            : colors.surfaceBorder.withAlpha(
                                                40,
                                              ),
                                        width: isSelected || isHovered
                                            ? 1.5
                                            : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          reason.icon,
                                          color: isSelected
                                              ? colors.primary
                                              : (isHovered
                                                    ? colors.primary
                                                    : colors.textSecondary),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                reason.label,
                                                style: typography.body.bold
                                                    .copyWith(
                                                      color: isSelected
                                                          ? (isDark
                                                                ? colors.white
                                                                : colors
                                                                      .primary)
                                                          : colors.textPrimary,
                                                      fontSize: 14,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                reason.description,
                                                style: typography
                                                    .caption
                                                    .regular
                                                    .copyWith(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isSelected
                                              ? Icons
                                                    .radio_button_checked_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          color: isSelected
                                              ? colors.primary
                                              : colors.textSecondary.withAlpha(
                                                  100,
                                                ),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 12),

                          // Optional details field
                          Text(
                            'Additional Context (Optional)',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: detailsController,
                            hintText:
                                'Provide any extra details for the moderator...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting.value
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: colors.surfaceBorder.withAlpha(80),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.radiusCard,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: typography.body.medium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            text: 'Submit Report',
                            isLoading: isSubmitting.value,
                            onPressed: isSubmitting.value ? null : submitReport,
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
      ),
    );
  }
}
