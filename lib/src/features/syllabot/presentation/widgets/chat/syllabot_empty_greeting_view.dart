import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/syllabot/domain/entities/prompt_suggestion_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

/// Empty state greeting and tailored academic prompt suggestions for Syllabot.
class SyllabotEmptyGreetingView extends StatelessWidget {
  const SyllabotEmptyGreetingView({
    required this.textController,
    this.profile,
    super.key,
  });

  final TextEditingController textController;
  final CalibrationProfile? profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final suggestions = PromptSuggestionEntity.forProfile(profile);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SyllabotAvatar(size: 64),
              const SizedBox(height: 16),
              Text(
                l10n.syllabotTitle,
                style: typography.headline.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.syllabotEmptySubtitle,
                textAlign: TextAlign.center,
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 24),

              // Tailored Suggestion Cards
              ...suggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PlatformHoverBuilder(
                    builder: (context, isHovered, child) {
                      return ShrinkableButton(
                        onTap: () {
                          textController
                            ..text = s.text
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: s.text.length),
                            );
                        },
                        child: AnimatedContainer(
                          duration: AppMotion.snappy,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? colors.surfaceSecondary.withAlpha(200)
                                : colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: isHovered
                                  ? colors.primary.withAlpha(140)
                                  : colors.surfaceBorder.withAlpha(90),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                s.icon,
                                style: context.typography.body.regular
                                    .copyWith(fontSize: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.text,
                                      style: typography.body.medium.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.category,
                                      style: typography.caption.medium
                                          .copyWith(
                                            color: colors.primary,
                                            fontSize: 10.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: isHovered
                                    ? colors.primary
                                    : colors.textSecondary.withAlpha(120),
                                size: 13,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
