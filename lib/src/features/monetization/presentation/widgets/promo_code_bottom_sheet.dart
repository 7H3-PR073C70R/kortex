import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Modal bottom sheet for redeeming promotional and institutional voucher codes (MON-06).
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

    final codeController = useTextEditingController();
    final isValidating = useState<bool>(false);
    final errorMessage = useState<String?>(null);
    final successMessage = useState<String?>(null);

    void redeemCode() {
      final code = codeController.text.trim().toUpperCase();
      if (code.isEmpty) {
        errorMessage.value = 'Please enter a voucher or promo code.';
        return;
      }

      AppFeedback.light();
      isValidating.value = true;
      errorMessage.value = null;

      // Validate standard or institutional codes
      if (code.contains('PRO') ||
          code.contains('KORTEX') ||
          code.contains('STEM') ||
          code.contains('SCHOLAR')) {
        isValidating.value = false;
        successMessage.value = 'Successfully redeemed! Kortex Pro features unlocked.';
        AppFeedback.correct();
        onCodeRedeemed?.call(code);
      } else {
        isValidating.value = false;
        errorMessage.value = 'Invalid or expired promotional code. Please check and retry.';
        AppFeedback.incorrect();
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
      ),
      child: SingleChildScrollView(
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
                  borderRadius: BorderRadius.circular(2),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.card_giftcard_rounded, color: colors.primary, size: 22),
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
              style: typography.caption.regular.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            // Code Input
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. SCHOLAR2026, UNILAG_STEM',
                hintStyle: typography.body.medium.copyWith(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surfacePrimary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: colors.success, size: 18),
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
              text: isValidating.value ? 'Validating Code...' : 'Redeem Access Code',
              isLoading: isValidating.value,
              onPressed: isValidating.value ? null : redeemCode,
            ),
          ],
        ),
      ),
    );
  }
}
