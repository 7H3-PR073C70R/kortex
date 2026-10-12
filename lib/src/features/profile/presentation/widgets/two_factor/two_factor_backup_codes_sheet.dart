import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal dialog displaying 8-character 2FA recovery codes with copy and confirm actions.
abstract final class TwoFactorBackupCodesSheet {
  static Future<void> show(BuildContext context) async {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final random = math.Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final backupCodes = List.generate(8, (_) {
      final part1 =
          List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
      final part2 =
          List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
      return '$part1-$part2';
    });

    final formattedText = 'KORTEXIFY 2FA BACKUP CODES\n'
        'Keep these 8-character recovery codes in a safe place. Each code can only be used once.\n\n'
        '${backupCodes.join("\n")}';

    await AppAdaptiveSheet.showModal<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surfacePrimary,
                borderRadius: AppRadius.radiusDialog,
                border: Border.all(color: colors.surfaceBorder.withAlpha(90)),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 80 : 30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.warning.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.key_rounded,
                          color: colors.warning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Save 8-Character Recovery Codes',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 16.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'If you lose access to your authenticator app, these recovery codes are '
                    'the only way to log back into your account.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 8-Code Grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: AppRadius.radiusCard,
                      border:
                          Border.all(color: colors.surfaceBorder.withAlpha(60)),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: backupCodes.length,
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            borderRadius: AppRadius.radiusMicro,
                            border: Border.all(
                              color: colors.surfaceBorder.withAlpha(40),
                            ),
                          ),
                          child: Center(
                            child: SelectableText(
                              backupCodes[index],
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 13,
                                fontFamily: 'monospace',
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons: Copy All Codes
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () {
                            AppFeedback.selection();
                            unawaited(
                              Clipboard.setData(
                                ClipboardData(text: formattedText),
                              ),
                            );
                            ctx.showSnackBar(
                              message: 'Recovery codes copied to clipboard!',
                              type: SnackBarType.success,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: AppRadius.radiusCard,
                              border: Border.all(
                                color: colors.primary.withAlpha(70),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Copy All Codes',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
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
                  const SizedBox(height: 14),

                  // Done Button
                  ShrinkableButton(
                    onTap: () {
                      AppFeedback.correct();
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(true);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.syllabotAccent],
                        ),
                        borderRadius: AppRadius.radiusPanel,
                      ),
                      child: Center(
                        child: Text(
                          'I Have Saved My Recovery Codes',
                          style: typography.body.bold.copyWith(
                            color: colors.white,
                            fontSize: 14,
                          ),
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
    );
  }
}
