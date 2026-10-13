import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Details record for a Socratic reasoning mode (emoji icon, title, description).
typedef SocraticModeInfo = (String icon, String title, String desc);

/// Helper providing localized labels and icons for each [SocraticMode].
class SocraticModeDetailsHelper {
  const SocraticModeDetailsHelper._();

  static SocraticModeInfo getModeDetails(
    SocraticMode mode,
    AppLocalizations l10n,
  ) {
    return switch (mode) {
      SocraticMode.stepByStep => (
        '🪜',
        l10n.socraticModeStepByStepLabel,
        l10n.socraticModeStepByStepDesc,
      ),
      SocraticMode.directAnswer => (
        '⚡',
        l10n.socraticModeDirectAnswerLabel,
        l10n.socraticModeDirectAnswerDesc,
      ),
      SocraticMode.examSim => (
        '🎯',
        l10n.socraticModeExamSimLabel,
        l10n.socraticModeExamSimDesc,
      ),
      SocraticMode.deepResearch => (
        '🔬',
        l10n.socraticModeDeepResearchLabel,
        l10n.socraticModeDeepResearchDesc,
      ),
      SocraticMode.feynmanTeachBack => (
        '🧠',
        'Feynman Teach-Back',
        'Explain simply to Syllabot; AI diagnoses missing concepts and jargon',
      ),
    };
  }

  static String getModeShortLabel(
    SocraticMode mode,
    AppLocalizations l10n,
  ) {
    return switch (mode) {
      SocraticMode.stepByStep => l10n.socraticModeStepByStepShort,
      SocraticMode.directAnswer => l10n.socraticModeDirectAnswerShort,
      SocraticMode.examSim => l10n.socraticModeExamSimShort,
      SocraticMode.deepResearch => l10n.socraticModeDeepResearchShort,
      SocraticMode.feynmanTeachBack => 'Feynman Mode',
    };
  }
}

/// Modal bottom sheet / dialog for selecting active Syllabot [SocraticMode].
class SyllabotSocraticModeSheet extends StatelessWidget {
  const SyllabotSocraticModeSheet({
    required this.selectedMode,
    required this.onModeSelected,
    super.key,
  });

  final SocraticMode selectedMode;
  final ValueChanged<SocraticMode> onModeSelected;

  static Future<void> show({
    required BuildContext context,
    required SocraticMode currentMode,
    required ValueChanged<SocraticMode> onModeChanged,
  }) {
    return AppAdaptiveSheet.showActionMenu<void>(
      context: context,
      builder: (ctx) => SyllabotSocraticModeSheet(
        selectedMode: currentMode,
        onModeSelected: onModeChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return SafeArea(
      top: isDesktop,
      bottom: false,
      child: Align(
        alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: isDesktop
                  ? BorderRadius.circular(AppRadius.dialog)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.dialog),
                    ),
              boxShadow: isDesktop
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: isDesktop
                  ? 16
                  : MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDesktop) ...[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withAlpha(80),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.socraticModeSheetTitle,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (isDesktop)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        color: colors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.socraticModeSheetSubtitle,
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: SocraticMode.values.map((mode) {
                        final isSelected = mode == selectedMode;
                        final (icon, title, desc) =
                            SocraticModeDetailsHelper.getModeDetails(mode, l10n);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ShrinkableButton(
                            onTap: () {
                              onModeSelected(mode);
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary.withAlpha(25)
                                    : colors.surfaceSecondary,
                                borderRadius: AppRadius.radiusCard,
                                border: Border.all(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.surfaceBorder.withAlpha(80),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    icon,
                                    style: context.typography.body.regular.copyWith(
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: typography.body.bold.copyWith(
                                            color: isSelected
                                                ? colors.primary
                                                : colors.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          desc,
                                          style: typography.caption.regular.copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: colors.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
