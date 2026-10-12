import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_flow_step.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating glassmorphic bottom chat input bar with password obscurity toggle
/// and animated submit button.
class AuthChatInputBar extends StatelessWidget {
  const AuthChatInputBar({
    required this.isTextFieldVisible,
    required this.currentFlow,
    required this.textController,
    required this.isPasswordObscured,
    required this.hasInputText,
    required this.isPasswordField,
    required this.hintText,
    required this.onSend,
    super.key,
  });

  final bool isTextFieldVisible;
  final ChatFlowStep currentFlow;
  final TextEditingController textController;
  final ValueNotifier<bool> isPasswordObscured;
  final ValueNotifier<bool> hasInputText;
  final bool isPasswordField;
  final String hintText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    if (!isTextFieldVisible) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final inputBorderColor = isDark
        ? colors.surfaceBorderHighlight.withAlpha(80)
        : colors.surfaceBorder.withAlpha(140);
    final borderHighlight = isDark
        ? colors.surfaceBorderHighlight.withAlpha(60)
        : colors.surfaceBorderHighlight.withAlpha(90);

    final isObscured = isPasswordObscured.value;
    final eyeIcon =
        isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined;
    final eyeTooltip = isObscured ? 'Show password' : 'Hide password';
    final side = BorderSide(color: inputBorderColor, width: 1.2);
    final pillRadius = BorderRadius.circular(24);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Padding(
        key: ValueKey(currentFlow),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                textField: true,
                label: l10n.authChatInputSemantics,
                hint: hintText,
                child: ClipRRect(
                  borderRadius: pillRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: TextField(
                      controller: textController,
                      autofocus: true,
                      textCapitalization:
                          currentFlow == ChatFlowStep.signUpName
                              ? TextCapitalization.words
                              : TextCapitalization.none,
                      keyboardType: isPasswordField
                          ? TextInputType.visiblePassword
                          : (currentFlow == ChatFlowStep.signUpName
                                ? TextInputType.name
                                : TextInputType.emailAddress),
                      obscureText: isPasswordField && isObscured,
                      style: typography.callout.regular.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: typography.footnote.regular.copyWith(
                          color: colors.textMuted,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? colors.surfaceSecondary.withAlpha(190)
                            : colors.surfacePrimary.withAlpha(220),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        suffixIcon: isPasswordField
                            ? IconButton(
                                tooltip: eyeTooltip,
                                icon: Icon(
                                  eyeIcon,
                                  size: 19,
                                  color: colors.textMuted,
                                ),
                                onPressed: () {
                                  isPasswordObscured.value = !isObscured;
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: pillRadius,
                          borderSide: side,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: pillRadius,
                          borderSide: side,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: pillRadius,
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 1.6,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: l10n.authChatSendSemantics,
              child: ShrinkableButton(
                onTap: hasInputText.value ? onSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasInputText.value
                        ? colors.primary
                        : borderHighlight,
                    boxShadow: hasInputText.value
                        ? [
                            BoxShadow(
                              color: colors.black.withAlpha(
                                isDark ? 50 : 25,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: hasInputText.value
                        ? colors.white
                        : colors.textMuted.withAlpha(140),
                    size: 20,
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
