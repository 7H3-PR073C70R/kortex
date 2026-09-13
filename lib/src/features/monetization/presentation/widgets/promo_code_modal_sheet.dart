import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/monetization/domain/use_cases/redeem_promo_code_use_case.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Modal bottom sheet for redeeming Kortex Pro promo codes.
class PromoCodeModalSheet extends StatefulWidget {
  const PromoCodeModalSheet({
    super.key,
    this.initialCode,
    this.onRedeemed,
  });

  final String? initialCode;
  final VoidCallback? onRedeemed;

  static Future<bool?> show(
    BuildContext context, {
    String? initialCode,
    VoidCallback? onRedeemed,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a promo code.';
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
            _errorMessage = failure.message ??
                'Failed to redeem promo code. Please check your internet connection.';
          });
        },
        (redemption) {
          if (redemption.success) {
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
              _errorMessage = redemption.message ??
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
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(240)
                      : colors.surfacePrimary.withAlpha(245),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(80)
                        : colors.surfaceBorder,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle pill
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withAlpha(80),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (_isSuccess) ...[
                      // Success View
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                colors.primary,
                                colors.primary.withAlpha(180),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withAlpha(100),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kortex Pro Activated!',
                        textAlign: TextAlign.center,
                        style: typography.title1.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Congratulations! You have unlocked ${_grantedDays ?? 365} days of Kortex Pro access. Enjoy unlimited AI generation, deep diagnostics, and full offline study powers.',
                        textAlign: TextAlign.center,
                        style: typography.body.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Get Started with Pro',
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      // Input View
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.card_giftcard_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Redeem Promo Code',
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Enter your special access code below',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      AppTextField(
                        label: 'Promo Code',
                        hintText: 'e.g. kotexify007',
                        controller: _codeController,
                        prefixIcon: const Icon(
                          Icons.confirmation_number_outlined,
                          size: 20,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_\-]'),
                          ),
                        ],
                        onFieldSubmitted: (_) => _redeem(),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.redAccent.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: typography.caption.medium.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      AppButton(
                        text: 'Apply Promo Code',
                        isLoading: _isLoading,
                        onPressed: _redeem,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
