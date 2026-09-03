import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

class SyllabotQuickPromptBar extends HookWidget {
  const SyllabotQuickPromptBar({
    this.insightText,
    super.key,
  });

  final String? insightText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final controller = useTextEditingController();
    final hasText = useState<bool>(false);

    useEffect(
      () {
        void listener() {
          hasText.value = controller.text.trim().isNotEmpty;
        }

        controller.addListener(listener);
        return () => controller.removeListener(listener);
      },
      [controller],
    );

    void handleSubmit() {
      final text = controller.text.trim();
      if (text.isEmpty) return;

      unawaited(HapticFeedback.lightImpact());
      controller.clear();
      unawaited(
        context.navigateTo(
          MainRoute(
            children: [SyllabotChatRoute(initialPrompt: text)],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily AI Insight Pill
        if (insightText != null && insightText!.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 40 : 20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 90 : 60),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 15,
                  color: colors.syllabotAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insightText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.footnote.medium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Floating Glassmorphic Input Bar
        Semantics(
          container: true,
          label: l10n.dashboardAskSyllabotSemantics,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(190)
                      : colors.surfacePrimary.withAlpha(225),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(80)
                        : colors.surfaceBorder.withAlpha(140),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 40 : 10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SyllabotAvatar(size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => handleSubmit(),
                        style: typography.callout.regular.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.dashboardAskSyllabotHint,
                          hintStyle: typography.footnote.regular.copyWith(
                            color: colors.textMuted,
                            fontSize: 12.5,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Semantics(
                      button: true,
                      label: l10n.dashboardSendPromptSemantics,
                      child: ShrinkableButton(
                        onTap: handleSubmit,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasText.value
                                ? colors.primary
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          60,
                                        )
                                      : colors.surfaceBorderHighlight.withAlpha(
                                          90,
                                        )),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: hasText.value
                                ? Colors.white
                                : colors.textMuted.withAlpha(140),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
