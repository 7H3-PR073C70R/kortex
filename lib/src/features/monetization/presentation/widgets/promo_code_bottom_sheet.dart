import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/monetization/data/datasources/promo_code_remote_data_source.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Modal bottom sheet for redeeming promotional and institutional voucher codes (MON-06).
/// Clamped for desktop/tablet workstations with concentric radii.
class PromoCodeBottomSheet extends HookWidget {
  const PromoCodeBottomSheet({
    super.key,
    this.onCodeRedeemed,
  });

  final ValueChanged<String>? onCodeRedeemed;

  static Future<void> show(
    BuildContext context, {
    ValueChanged<String>? onCodeRedeemed,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => PromoCodeBottomSheet(onCodeRedeemed: onCodeRedeemed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final codeController = useTextEditingController();
    final isValidating = useState<bool>(false);
    final errorMessage = useState<String?>(null);
    final successMessage = useState<String?>(null);

    Future<void> redeemCode() async {
      final code = codeController.text.trim().toUpperCase();
      if (code.isEmpty) {
        errorMessage.value = 'Please enter a voucher or promo code.';
        return;
      }

      AppFeedback.light();
      isValidating.value = true;
      errorMessage.value = null;

      try {
        if (locator.isRegistered<PromoCodeRemoteDataSource>()) {
          final remote = locator<PromoCodeRemoteDataSource>();
          final res = await remote.redeemPromoCode(code: code);
          isValidating.value = false;

          if (res.success) {
            successMessage.value =
                res.message ?? 'Successfully redeemed! Kortex Pro unlocked.';
            if (locator.isRegistered<UserStorageService>()) {
              await locator<UserStorageService>().saveProStatus(isPro: true);
            }
            if (locator.isRegistered<SubscriptionGuard>()) {
              unawaited(locator<SubscriptionGuard>().isProAuthoritative());
            }
            AppFeedback.correct();
            onCodeRedeemed?.call(code);
            return;
          } else {
            errorMessage.value =
                res.message ?? 'Invalid or expired promotional code.';
            AppFeedback.incorrect();
            return;
          }
        }
      } on Object catch (e) {
        isValidating.value = false;
        errorMessage.value = 'Failed to redeem promo code: $e';
        AppFeedback.incorrect();
        return;
      }

      // Fallback verification for demo/testing codes if remote datasource isn't registered
      isValidating.value = false;
      if (code.contains('PRO') ||
          code.contains('KORTEX') ||
          code.contains('STEM') ||
          code.contains('SCHOLAR')) {
        successMessage.value =
            'Successfully redeemed! Kortex Pro features unlocked.';
        if (locator.isRegistered<UserStorageService>()) {
          await locator<UserStorageService>().saveProStatus(isPro: true);
        }
        AppFeedback.correct();
        onCodeRedeemed?.call(code);
      } else {
        errorMessage.value =
            'Invalid or expired promotional code. Please check and retry.';
        AppFeedback.incorrect();
      }
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: AppRadius.radiusMicro,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.radiusCard,
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Redeem Voucher / Promo Code',
                        style: typography.title2.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter an institutional student access code or partner voucher to unlock Kortex Pro features.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // Code Input
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: l10n.monetizationPromoHint,
                    hintStyle: typography.body.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                    filled: true,
                    fillColor: colors.surfacePrimary,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusCard,
                      borderSide: BorderSide(color: colors.surfaceBorder),
                    ),
                    errorText: errorMessage.value,
                  ),
                ),
                if (successMessage.value != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: colors.success.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: colors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            successMessage.value!,
                            style: typography.caption.regular.copyWith(
                              color: colors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Redeem Button
                AppButton(
                  text: isValidating.value
                      ? 'Validating Code...'
                      : 'Redeem Access Code',
                  isLoading: isValidating.value,
                  onPressed: isValidating.value ? null : redeemCode,
                ),
              ].animate(interval: 80.ms).fadeIn(duration: 250.ms, curve: Curves.easeOutQuint).slideY(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOutQuint),
            ),
          ),
        ),
      ),
    );
  }
}
