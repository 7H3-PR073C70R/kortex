import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/onboarding_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Top navigation toggle bar seamlessly switching between Conversational
/// AI Chat and Form Stepper modes.
class OnboardingModeToggleBar extends StatelessWidget {
  const OnboardingModeToggleBar({
    required this.activeMode,
    required this.onModeChanged,
    super.key,
  });

  final OnboardingMode activeMode;
  final ValueChanged<OnboardingMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isChat = activeMode == OnboardingMode.chat;

    return Semantics(
      label: isChat ? l10n.switchToFormView : l10n.switchToChatView,
      hint: 'Toggles between AI conversation and traditional stepper form view',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 40 : 25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // AI Chat Tab
            Expanded(
              child: _ToggleSegment(
                isSelected: isChat,
                icon: Icons.chat_bubble_outline_rounded,
                label: l10n.onboardingAiChatTitle,
                onTap: () {
                  if (!isChat) {
                    unawaited(HapticFeedback.selectionClick());
                    onModeChanged(OnboardingMode.chat);
                  }
                },
              ),
            ),
            const SizedBox(width: 4),

            // Form View Tab
            Expanded(
              child: _ToggleSegment(
                isSelected: !isChat,
                icon: Icons.format_list_bulleted_rounded,
                label: l10n.onboardingFormTitle,
                onTap: () {
                  if (isChat) {
                    unawaited(HapticFeedback.selectionClick());
                    onModeChanged(OnboardingMode.form);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool isSelected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withAlpha(220),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : isDark
              ? Colors.transparent
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withAlpha(50),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: typography.footnote.bold.copyWith(
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
