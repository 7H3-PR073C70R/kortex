import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_enroll_result_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/presentation/widgets/two_factor/two_factor_backup_codes_sheet.dart';
import 'package:kortex/src/features/profile/presentation/widgets/two_factor/two_factor_error_view.dart';
import 'package:kortex/src/features/profile/presentation/widgets/two_factor/two_factor_qr_code_card.dart';
import 'package:kortex/src/features/profile/presentation/widgets/two_factor/two_factor_secret_key_card.dart';
import 'package:kortex/src/features/profile/presentation/widgets/two_factor/two_factor_shimmer_skeleton.dart';
import 'package:kortex/src/features/profile/presentation/widgets/two_factor/two_factor_verify_card.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

export '../widgets/two_factor/two_factor_backup_codes_sheet.dart';
export '../widgets/two_factor/two_factor_error_view.dart';
export '../widgets/two_factor/two_factor_qr_code_card.dart';
export '../widgets/two_factor/two_factor_secret_key_card.dart';
export '../widgets/two_factor/two_factor_shimmer_skeleton.dart';
export '../widgets/two_factor/two_factor_verify_card.dart';

@RoutePage()
class TwoFactorSetupPage extends HookWidget {
  const TwoFactorSetupPage({
    super.key,
    this.email,
    this.initialSecret,
    this.initialFactorId,
    this.initialTotpUri,
    this.issuer = 'Kortexify',
    this.userStorageService,
    this.enrollMfaTotpUseCase,
    this.verifyMfaTotpUseCase,
  });

  final String? email;
  final String? initialSecret;
  final String? initialFactorId;
  final String? initialTotpUri;
  final String issuer;
  final UserStorageService? userStorageService;
  final EnrollMfaTotpUseCase? enrollMfaTotpUseCase;
  final VerifyMfaTotpUseCase? verifyMfaTotpUseCase;

  UserStorageService? get _effectiveUserStorage {
    if (userStorageService != null) return userStorageService;
    try {
      if (locator.isRegistered<UserStorageService>()) {
        return locator<UserStorageService>();
      }
    } on Object {
      // Ignored
    }
    return null;
  }

  EnrollMfaTotpUseCase? get _effectiveEnrollUseCase {
    if (enrollMfaTotpUseCase != null) return enrollMfaTotpUseCase;
    try {
      if (locator.isRegistered<EnrollMfaTotpUseCase>()) {
        return locator<EnrollMfaTotpUseCase>();
      }
    } on Object {
      // Ignored
    }
    return null;
  }

  VerifyMfaTotpUseCase? get _effectiveVerifyUseCase {
    if (verifyMfaTotpUseCase != null) return verifyMfaTotpUseCase;
    try {
      if (locator.isRegistered<VerifyMfaTotpUseCase>()) {
        return locator<VerifyMfaTotpUseCase>();
      }
    } on Object {
      // Ignored
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final resolvedEmail = useMemoized(() {
      if (email != null && email!.trim().isNotEmpty) {
        return email!.trim();
      }
      final storage = _effectiveUserStorage;
      if (storage != null) {
        final storedEmail = storage.getUserEmail();
        if (storedEmail != null && storedEmail.trim().isNotEmpty) {
          return storedEmail.trim();
        }
      }
      return 'scholar@kortexify.com';
    }, [email, _effectiveUserStorage]);

    final secretState = useState<String>(initialSecret ?? '');
    final factorIdState = useState<String?>(initialFactorId);
    final totpUriState = useState<String>(() {
      if (initialTotpUri != null && initialTotpUri!.isNotEmpty) {
        return initialTotpUri!;
      }
      if (initialSecret != null && initialSecret!.isNotEmpty) {
        return 'otpauth://totp/$issuer:${Uri.encodeComponent(resolvedEmail)}?secret=$initialSecret&issuer=${Uri.encodeComponent(issuer)}';
      }
      return '';
    }());
    final isEnrolling = useState<bool>(
      initialSecret == null || initialSecret!.isEmpty,
    );
    final enrollmentErrorState = useState<String?>(null);
    final isVerifying = useState<bool>(false);
    final codeController = useTextEditingController();

    Future<void> enroll() async {
      isEnrolling.value = true;
      enrollmentErrorState.value = null;
      try {
        final enrollUseCase = _effectiveEnrollUseCase;
        if (enrollUseCase == null) {
          enrollmentErrorState.value =
              'Authentication service unavailable. Please try again.';
          return;
        }
        final result = await enrollUseCase(const NoParams());
        if (result.isRight) {
          final enrollRes =
              (result as Right<Failure, MfaEnrollResultEntity>).value;
          secretState.value = enrollRes.secret;
          factorIdState.value = enrollRes.factorId;
          final uri = enrollRes.uri;
          totpUriState.value = (uri != null && uri.isNotEmpty)
              ? uri
              : 'otpauth://totp/$issuer:${Uri.encodeComponent(resolvedEmail)}?secret=${enrollRes.secret}&issuer=${Uri.encodeComponent(issuer)}';
        } else {
          final failure =
              (result as Left<Failure, MfaEnrollResultEntity>).value;
          enrollmentErrorState.value =
              failure.message ??
              'Failed to initialize 2FA enrollment. Please try again.';
        }
      } on Object catch (_) {
        enrollmentErrorState.value =
            'Could not connect to authentication server. Please check your connection and retry.';
      } finally {
        isEnrolling.value = false;
      }
    }

    // Initialize TOTP Enrollment if not provided
    useEffect(() {
      if (initialSecret != null && initialSecret!.isNotEmpty) return null;
      unawaited(enroll());
      return null;
    }, const []);

    Future<void> handleVerify() async {
      final code = codeController.text.trim();
      if (code.length < 6) {
        AppFeedback.heavy();
        context.showSnackBar(
          message: 'Please enter the full 6-digit code.',
          type: SnackBarType.error,
        );
        return;
      }

      final factorId = factorIdState.value;
      if (factorId == null || factorId.isEmpty) {
        AppFeedback.heavy();
        context.showSnackBar(
          message: '2FA factor not initialized. Please retry enrollment.',
          type: SnackBarType.error,
        );
        return;
      }

      final verifyUseCase = _effectiveVerifyUseCase;
      if (verifyUseCase == null) {
        context.showSnackBar(
          message: 'Verification service unavailable.',
          type: SnackBarType.error,
        );
        return;
      }

      isVerifying.value = true;
      AppFeedback.medium();

      final result = await verifyUseCase(
        VerifyMfaTotpParams(
          factorId: factorId,
          code: code,
        ),
      );

      isVerifying.value = false;

      if (result.isRight) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Two-Factor Authentication enabled!',
            type: SnackBarType.success,
          );
          await TwoFactorBackupCodesSheet.show(context);
        }
      } else {
        final failure = (result as Left<Failure, void>).value;
        if (context.mounted) {
          context.showSnackBar(
            message:
                failure.message ??
                'Invalid verification code. Please check your authenticator clock.',
            type: SnackBarType.error,
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: colors.backgroundPrimary,
        titleText: 'Set Up Two-Factor Authentication',
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Security & Access',
            onTap: () => Navigator.of(context).pop(false),
          ),
          const AppBreadcrumbItem(label: 'Two-Factor Authentication'),
        ],
      ),
      body: SafeArea(
        child: isEnrolling.value
            ? const TwoFactorShimmerSkeleton()
            : (enrollmentErrorState.value != null && secretState.value.isEmpty)
                ? TwoFactorErrorView(
                    errorMessage: enrollmentErrorState.value!,
                    onRetry: () => unawaited(enroll()),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Protect your Kortexify scholar account and study notes '
                              'by enabling two-factor authentication (TOTP).',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TwoFactorQrCodeCard(
                              totpUri: totpUriState.value,
                            ),
                            const SizedBox(height: 18),
                            TwoFactorSecretKeyCard(
                              secretKey: secretState.value,
                            ),
                            const SizedBox(height: 18),
                            TwoFactorVerifyCard(
                              codeController: codeController,
                              isVerifying: isVerifying.value,
                              onVerify: handleVerify,
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
