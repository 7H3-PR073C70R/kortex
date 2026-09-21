import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Glassmorphic toggle button allowing users to switch between
/// Conversational AI Chat and Quick Form auth modes with WCAG announcements.
class ModeSwitchButton extends StatelessWidget {
  const ModeSwitchButton({
    required this.isChatMode,
    required this.onToggle,
    super.key,
  });

  final bool isChatMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final targetLabel = isChatMode
        ? l10n.authSwitchToForm
        : l10n.authSwitchToChat;
    final semanticLabel = l10n.authModeToggleSemantics(targetLabel);

    void handleToggle() {
      unawaited(HapticFeedback.lightImpact());
      unawaited(
        // ignore: deprecated_member_use, backward-compatible live a11y announcement
        SemanticsService.announce(
          l10n.authModeSwitchedAnnouncement(targetLabel),
          TextDirection.ltr,
        ),
      );
      onToggle();
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      hint: isChatMode ? l10n.authSwitchToFormHint : l10n.authSwitchToChatHint,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: handleToggle,
            child: ClipRRect(
              borderRadius: AppRadius.radiusPanel,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.radiusPanel,
                    color: isHovered
                        ? (isDark
                              ? colors.surfaceSecondary.withAlpha(200)
                              : colors.surfacePrimary)
                        : (isDark
                              ? colors.surfaceSecondary.withAlpha(140)
                              : colors.surfacePrimary.withAlpha(210)),
                    border: Border.all(
                      color: isHovered
                          ? colors.primary.withAlpha(140)
                          : (isDark
                                ? colors.surfaceBorderHighlight.withAlpha(100)
                                : colors.surfaceBorder),
                      width: isHovered ? 1.4 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isDark
                              ? (isHovered ? 50 : 30)
                              : (isHovered ? 30 : 15),
                        ),
                        blurRadius: isHovered ? 14 : 10,
                        offset: Offset(0, isHovered ? 4 : 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          isChatMode
                              ? Icons.format_list_bulleted_rounded
                              : Icons.auto_awesome_rounded,
                          key: ValueKey<bool>(isChatMode),
                          size: 15,
                          color: isChatMode ? colors.primary : colors.warning,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        targetLabel,
                        style: typography.caption.bold.copyWith(
                          color: isHovered
                              ? colors.primary
                              : colors.textPrimary,
                          letterSpacing: 0.2,
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
