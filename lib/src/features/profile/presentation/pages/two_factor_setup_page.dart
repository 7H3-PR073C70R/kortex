import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_enroll_result_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

@RoutePage()
class TwoFactorSetupPage extends HookWidget {
  const TwoFactorSetupPage({
    super.key,
    this.email = 'scholar@kortexify.com',
    this.initialSecret,
    this.initialFactorId,
    this.initialTotpUri,
  });

  final String email;
  final String? initialSecret;
  final String? initialFactorId;
  final String? initialTotpUri;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final secretState = useState<String>(
      initialSecret ?? 'MJ6YDJSONHTA3IXIW7JSX2USKBC67XTN',
    );
    final factorIdState = useState<String?>(initialFactorId);
    final totpUriState = useState<String>(
      initialTotpUri ??
          'otpauth://totp/Kortex:$email?secret=${secretState.value}&issuer=Kortex',
    );
    final isEnrolling = useState<bool>(false);
    final isVerifying = useState<bool>(false);
    final codeController = useTextEditingController();

    // Initialize TOTP Enrollment if not provided
    useEffect(() {
      if (initialSecret != null && initialSecret!.isNotEmpty) return null;

      Future<void> enroll() async {
        isEnrolling.value = true;
        try {
          final result =
              await locator<EnrollMfaTotpUseCase>()(const NoParams());
          if (result.isRight) {
            final enrollRes =
                (result as Right<Failure, MfaEnrollResultEntity>).value;
            secretState.value = enrollRes.secret;
            factorIdState.value = enrollRes.factorId;
            final uri = enrollRes.uri;
            totpUriState.value = (uri != null && uri.isNotEmpty)
                ? uri
                : 'otpauth://totp/Kortex:$email?secret=${enrollRes.secret}&issuer=Kortex';
          }
        } on Object catch (_) {
          // Fallback to offline standard secret key
        } finally {
          isEnrolling.value = false;
        }
      }

      unawaited(enroll());
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Set Up Two-Factor Authentication',
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 17.5,
          ),
        ),
      ),
      body: SafeArea(
        child: isEnrolling.value
            ? _buildShimmerLoadingSkeleton(colors, isDark)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protect your Kortex scholar account and study notes '
                      'by enabling two-factor authentication (TOTP).',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step 1: QR Code Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '1',
                                    style: typography.caption.bold.copyWith(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Scan QR Code with Authenticator App',
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(20),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: totpUriState.value,
                              size: 190,
                              gapless: false,
                              errorStateBuilder: (cxt, err) {
                                return const SizedBox(
                                  height: 190,
                                  child: Center(
                                    child: Text(
                                      'Could not generate QR',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Compatible with Google Authenticator, Authy, '
                            '1Password, Microsoft Authenticator',
                            textAlign: TextAlign.center,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Step 2: Copy Key Manually Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '2',
                                    style: typography.caption.bold.copyWith(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Or Copy Secret Key Manually',
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    colors.primary.withAlpha(isDark ? 80 : 50),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    secretState.value,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 13.5,
                                      letterSpacing: 1.2,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ShrinkableButton(
                                  onTap: () {
                                    AppFeedback.selection();
                                    unawaited(
                                      Clipboard.setData(
                                        ClipboardData(text: secretState.value),
                                      ),
                                    );
                                    context.showSnackBar(
                                      message:
                                          'Secret key copied to clipboard!',
                                      type: SnackBarType.success,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colors.primary.withAlpha(70),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.copy_rounded,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Copy',
                                          style: typography.caption.bold
                                              .copyWith(
                                            color: colors.primary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Step 3: Enter 6-Digit Code Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '3',
                                    style: typography.caption.bold.copyWith(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Enter 6-Digit Code from Authenticator',
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: codeController,
                            hintText: '123456',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Verify & Enable Action Button
                    ShrinkableButton(
                      onTap: isVerifying.value
                          ? () {}
                          : () async {
                              final code = codeController.text.trim();
                              if (code.length < 6) {
                                AppFeedback.heavy();
                                context.showSnackBar(
                                  message:
                                      'Please enter the full 6-digit code.',
                                  type: SnackBarType.error,
                                );
                                return;
                              }

                              isVerifying.value = true;
                              AppFeedback.medium();

                              final factorId =
                                  factorIdState.value ?? 'local_totp_factor';
                              final result =
                                  await locator<VerifyMfaTotpUseCase>()(
                                VerifyMfaTotpParams(
                                  factorId: factorId,
                                  code: code,
                                ),
                              );

                              isVerifying.value = false;

                              if (result.isRight) {
                                if (context.mounted) {
                                  context.showSnackBar(
                                    message:
                                        'Two-Factor Authentication enabled!',
                                    type: SnackBarType.success,
                                  );
                                  Navigator.of(context).pop(true);
                                }
                              } else {
                                final failure =
                                    (result as Left<Failure, void>).value;
                                if (context.mounted) {
                                  context.showSnackBar(
                                    message: failure.message ??
                                        'Invalid verification code. Please '
                                        'check your authenticator clock.',
                                    type: SnackBarType.error,
                                  );
                                }
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.syllabotAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(isDark ? 80 : 40),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isVerifying.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                               : Text(
                                  'Verify & Enable 2FA',
                                  style: typography.body.bold.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildShimmerLoadingSkeleton(
    AppThemeColorsExtension colors,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header description skeleton
          const ShimmerPlaceholder(height: 14, width: 280, borderRadius: 6),
          const SizedBox(height: 6),
          const ShimmerPlaceholder(height: 14, width: 200, borderRadius: 6),
          const SizedBox(height: 20),

          // Step 1: QR Code Card Skeleton
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(90),
              ),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    ShimmerPlaceholder(
                      height: 24,
                      width: 24,
                      borderRadius: 12,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ShimmerPlaceholder(
                        height: 16,
                        width: 200,
                        borderRadius: 6,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                ShimmerPlaceholder(
                  height: 190,
                  width: 190,
                  borderRadius: 16,
                ),
                SizedBox(height: 14),
                ShimmerPlaceholder(
                  height: 12,
                  width: 220,
                  borderRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Step 2: Copy Secret Key Skeleton
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(90),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerPlaceholder(
                      height: 24,
                      width: 24,
                      borderRadius: 12,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ShimmerPlaceholder(
                        height: 16,
                        width: 180,
                        borderRadius: 6,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                ShimmerPlaceholder(height: 48, borderRadius: 14),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Step 3: Verify Code Skeleton
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(90),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerPlaceholder(
                      height: 24,
                      width: 24,
                      borderRadius: 12,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ShimmerPlaceholder(
                        height: 16,
                        width: 160,
                        borderRadius: 6,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                ShimmerPlaceholder(height: 50, borderRadius: 14),
                SizedBox(height: 16),
                ShimmerPlaceholder(height: 52, borderRadius: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
