import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class SocraticModeSelector extends StatelessWidget {
  const SocraticModeSelector({
    required this.selectedMode,
    required this.onModeSelected,
    super.key,
  });

  final SocraticMode selectedMode;
  final ValueChanged<SocraticMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final modes = [
      (
        SocraticMode.stepByStep,
        l10n.socraticStepByStep,
        Icons.alt_route_rounded,
      ),
      (
        SocraticMode.directAnswer,
        l10n.socraticDirectAnswer,
        Icons.flash_on_rounded,
      ),
      (
        SocraticMode.examSim,
        l10n.socraticExamSim,
        Icons.quiz_rounded,
      ),
      (
        SocraticMode.deepResearch,
        l10n.socraticDeepResearch,
        Icons.menu_book_rounded,
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: modes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (mode, title, icon) = modes[index];
          final isSelected = mode == selectedMode;

          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onModeSelected(mode);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary.withAlpha(isDark ? 160 : 200)
                        : (isDark
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfacePrimary.withAlpha(160)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? colors.primary
                          : colors.textSecondary.withAlpha(40),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected ? Colors.white : colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: typography.footnote.medium.copyWith(
                          color: isSelected ? Colors.white : colors.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
