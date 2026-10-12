import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/auth/domain/entities/chat_auth_message.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_password_requirements_card.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';
import 'package:kortex/src/shared/widgets/typewriter_text.dart';

/// Syllabot AI message bubble with rich typewriter streaming and error feedback.
class AuthBotMessageBubble extends StatelessWidget {
  const AuthBotMessageBubble({
    required this.message,
    required this.colors,
    required this.typography,
    required this.isDark,
    this.isStreaming = false,
    this.livePasswordText,
    this.onStreamingTick,
    this.onStreamingComplete,
    super.key,
  });

  final ChatAuthMessage message;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final bool isStreaming;
  final String? livePasswordText;
  final VoidCallback? onStreamingTick;
  final VoidCallback? onStreamingComplete;

  @override
  Widget build(BuildContext context) {
    final isError = message.isError;

    return Semantics(
      container: true,
      label: isError
          ? 'Syllabot alert: ${message.text}'
          : 'Syllabot message: ${message.text}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SyllabotAvatar(
              size: 36,
              isError: isError,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isError
                          ? colors.error.withAlpha(isDark ? 55 : 30)
                          : (isDark
                                ? colors.surfaceSecondary.withAlpha(170)
                                : colors.surfacePrimary.withAlpha(220)),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: isError
                            ? colors.error
                            : (isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(70)
                                  : colors.surfaceBorder.withAlpha(140)),
                        width: isError ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(
                            isError ? (isDark ? 60 : 25) : (isDark ? 40 : 10),
                          ),
                          blurRadius: isError ? 12 : 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isError) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 13,
                                  color: colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Syllabot Alert',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        TypewriterText(
                          text: message.text,
                          isStreaming: isStreaming,
                          onTick: onStreamingTick,
                          onComplete: onStreamingComplete,
                          style: typography.callout.regular.copyWith(
                            color: isError ? colors.error : colors.textPrimary,
                            fontWeight: isError
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        if (message.step == ChatAuthStep.askPassword ||
                            message.text.contains(
                              'Almost there! Set a secure password',
                            )) ...[
                          AuthChatPasswordRequirementsCard(
                            password: livePasswordText ?? '',
                            colors: colors,
                            typography: typography,
                            isDark: isDark,
                          ),
                        ],
                        if (isError && message.onRetry != null) ...[
                          const SizedBox(height: 10),
                          Semantics(
                            button: true,
                            label: 'Retry last request',
                            child: Material(
                              color: colors.transparent,
                              child: InkWell(
                                onTap: message.onRetry,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.error.withAlpha(
                                      isDark ? 60 : 30,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colors.error.withAlpha(140),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        size: 15,
                                        color: colors.error,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Retry Request',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.error,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// User speech bubble with optional password obscurity masking.
class AuthUserMessageBubble extends HookWidget {
  const AuthUserMessageBubble({
    required this.message,
    required this.colors,
    required this.typography,
    super.key,
  });

  final ChatAuthMessage message;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    final isObscured = useState<bool>(message.isPasswordInput);
    final isPassword = message.isPasswordInput;
    final rawText = message.sensitiveValue ?? message.text;
    final displayText = isPassword && isObscured.value ? '••••••••' : rawText;

    return Semantics(
      container: true,
      label: 'Your response: ${isPassword ? "Password entered" : displayText}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(
                        context.isDarkMode ? 40 : 12,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayText,
                        style: typography.callout.regular.copyWith(
                          color: colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (isPassword) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: isObscured.value
                            ? 'Show password'
                            : 'Hide password',
                        child: GestureDetector(
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            isObscured.value = !isObscured.value;
                          },
                          child: Icon(
                            isObscured.value
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: colors.white.withAlpha(200),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated thinking indicator bubble with pulsing dots.
class AuthThinkingBubble extends HookWidget {
  const AuthThinkingBubble({
    required this.statusText,
    super.key,
  });

  final String statusText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(
      () {
        unawaited(controller.repeat());
        return null;
      },
      const [],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SyllabotAvatar(
            size: 36,
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(160)
                      : colors.surfacePrimary.withAlpha(220),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(70)
                        : colors.surfaceBorder.withAlpha(140),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 40 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(3, (i) {
                      return AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          final delay = i * 0.2;
                          final t = (controller.value - delay) % 1.0;
                          final curveValue = math.sin(t * math.pi);
                          final scale =
                              0.6 + (0.4 * (curveValue > 0 ? curveValue : 0));
                          final opacity =
                              0.4 + (0.6 * (curveValue > 0 ? curveValue : 0));

                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity.clamp(0.2, 1.0),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2.5,
                                ),
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == 1
                                      ? colors.syllabotAccent
                                      : colors.primary,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    const SizedBox(width: 10),
                    Text(
                      statusText,
                      style: typography.footnote.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
