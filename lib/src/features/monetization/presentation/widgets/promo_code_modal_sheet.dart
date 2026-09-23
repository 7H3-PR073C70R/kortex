import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/monetization/domain/use_cases/redeem_promo_code_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Proper centered modal dialog for redeeming Kortex Pro promo codes.
/// Clamped for workstation viewports with concentric radii and tactile hover feedback.
class PromoCodeModalSheet extends StatefulWidget {
  const PromoCodeModalSheet({
    super.key,
    this.initialCode,
    this.onRedeemed,
  });

  final String? initialCode;
  final VoidCallback? onRedeemed;

  /// Displays the promo code redemption dialog modally.
  static Future<bool?> show(
    BuildContext context, {
    String? initialCode,
    VoidCallback? onRedeemed,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: context.colors.black.withAlpha(180),
      builder: (context) => PromoCodeModalSheet(
        initialCode: initialCode,
        onRedeemed: onRedeemed,
      ),
    );
  }

  @override
  State<PromoCodeModalSheet> createState() => _PromoCodeModalSheetState();
}

class _PromoCodeModalSheetState extends State<PromoCodeModalSheet> {
  late final TextEditingController _codeController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  int? _grantedDays;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final l10n = context.l10n;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = l10n.promoCodeEmptyError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    AppFeedback.selection();

    try {
      final redeemUseCase = locator<RedeemPromoCodeUseCase>();
      final result = await redeemUseCase(RedeemPromoCodeParams(code: code));

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                failure.message ??
                'Failed to redeem promo code. Please check your connection.';
          });
        },
        (redemption) {
          if (redemption.success ||
              redemption.errorCode == 'ALREADY_REDEEMED') {
            AppFeedback.celebration();
            setState(() {
              _isLoading = false;
              _isSuccess = true;
              _grantedDays = redemption.durationDays ?? 365;
            });
            widget.onRedeemed?.call();
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  redemption.message ??
                  'Invalid promo code. Please check and try again.';
            });
          }
        },
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Dialog(
      backgroundColor: colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ClipRRect(
          borderRadius: AppRadius.radiusDialog,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.all(22.r),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(245)
                    : colors.surfacePrimary.withAlpha(250),
                borderRadius: AppRadius.radiusDialog,
                border: Border.all(
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(90)
                      : colors.surfaceBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 160 : 40),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSuccess) ...[
                      // Success View
                      Center(
                        child: Container(
                          width: 64.r,
                          height: 64.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                colors.primary,
                                colors.syllabotAccent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.black.withAlpha(isDark ? 50 : 20),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: colors.white,
                            size: 34.sp,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        l10n.promoCodeActivatedTitle,
                        textAlign: TextAlign.center,
                        style: typography.title2.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 20.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        l10n.promoCodeActivatedDesc(_grantedDays ?? 365),
                        textAlign: TextAlign.center,
                        style: typography.body.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13.5.sp,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      AppButton(
                        text: l10n.promoCodeGetStarted,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ] else ...[
                      // Input View - Header with Close Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              borderRadius: AppRadius.radiusCard,
                            ),
                            child: Icon(
                              Icons.card_giftcard_rounded,
                              color: colors.primary,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.promoCodeTitle,
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 17.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  l10n.promoCodeSubtitle,
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              return IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isHovered
                                        ? colors.surfaceBorder.withAlpha(40)
                                        : colors.transparent,
                                    borderRadius: AppRadius.radiusMicro,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: isHovered
                                        ? colors.primary
                                        : colors.textSecondary,
                                    size: 20.sp,
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(context).maybePop(false),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),

                      AppTextField(
                        label: l10n.promoCodeInputLabel,
                        hintText: l10n.promoCodeInputHint,
                        controller: _codeController,
                        prefixIcon: Icon(
                          Icons.confirmation_number_outlined,
                          size: 20.sp,
                          color: colors.textSecondary,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_\-]'),
                          ),
                        ],
                        onFieldSubmitted: (_) => _redeem(),
                      ),

                      if (_errorMessage != null) ...[
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: colors.error.withAlpha(30),
                            borderRadius: AppRadius.radiusBadge,
                            border: Border.all(
                              color: colors.error.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: colors.error,
                                size: 16.sp,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: typography.caption.medium.copyWith(
                                    color: colors.error,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 18.h),
                      AppButton(
                        text: l10n.promoCodeApplyButton,
                        isLoading: _isLoading,
                        onPressed: _redeem,
                      ),
                    ],
                  ].animate(interval: 80.ms).fadeIn(duration: 250.ms, curve: Curves.easeOutQuint).slideY(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOutQuint),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
