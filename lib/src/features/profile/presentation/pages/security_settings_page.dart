import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/domain/use_cases/send_password_reset_email_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_password_use_case.dart';
import 'package:kortex/src/features/profile/presentation/pages/two_factor_setup_page.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Comprehensive security and account control page.
/// Supports password change, session invalidation, Supabase MFA 2FA,
/// Biometric App Lock, and Danger Zone data purge through clean architecture.
class SecuritySettingsPage extends HookWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final currentPasswordController = useTextEditingController();
    final newPasswordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();

    final isUpdatingPassword = useState<bool>(false);
    final biometricLockEnabled = useState<bool>(false);
    final twoFactorEnabled = useState<bool>(false);
    final activeTotpFactorId = useState<String?>(null);

    final storage = locator<LocalStorageService>();

    useEffect(() {
      final savedBiometric =
          storage.getPreference(key: '__biometric_lock_enabled') == 'true';
      biometricLockEnabled.value = savedBiometric;

      Future<void> loadMfa() async {
        final result = await locator<ListMfaFactorsUseCase>()(const NoParams());
        if (result.isRight) {
          final factors =
              (result as Right<Failure, List<MfaFactorEntity>>).value;
          if (factors.isNotEmpty) {
            twoFactorEnabled.value = true;
            activeTotpFactorId.value = factors.first.id;
          }
        }
      }

      unawaited(loadMfa());
      return null;
    }, const []);

    // Password strength evaluator
    final newPasswordText = useValueListenable(newPasswordController).text;
    final hasMinLength = newPasswordText.length >= 8;
    final hasNumber = newPasswordText.contains(RegExp('[0-9]'));
    final hasSpecial = newPasswordText.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final email =
            state.userProfile?.email ??
            state.user?.email ??
            'scholar@kortexify.com';

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Security & Access Control',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Password Change Card
                  _buildSectionContainer(
                    title: 'Password & Authentication',
                    subtitle:
                        'Update your account password or request a reset link',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: currentPasswordController,
                          hintText: 'Current Password',
                          isPassword: true,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: newPasswordController,
                          hintText: 'New Password (min. 8 characters)',
                          isPassword: true,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: confirmPasswordController,
                          hintText: 'Confirm New Password',
                          isPassword: true,
                        ),
                        const SizedBox(height: 12),

                        // Password Strength Indicators
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildStrengthTag(
                              label: '8+ Chars',
                              isValid: hasMinLength,
                              colors: colors,
                              typography: typography,
                            ),
                            _buildStrengthTag(
                              label: 'Number (0-9)',
                              isValid: hasNumber,
                              colors: colors,
                              typography: typography,
                            ),
                            _buildStrengthTag(
                              label: 'Special Symbol',
                              isValid: hasSpecial,
                              colors: colors,
                              typography: typography,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Update Password Action Button
                        Row(
                          children: [
                            Expanded(
                              child: ShrinkableButton(
                                onTap: () async {
                                  final newPass = newPasswordController.text
                                      .trim();
                                  final confirmPass = confirmPasswordController
                                      .text
                                      .trim();

                                  if (newPass.length < 8) {
                                    AppFeedback.heavy();
                                    context.showSnackBar(
                                      message:
                                          'Password must be at least 8 chars.',
                                      type: SnackBarType.error,
                                    );
                                    return;
                                  }

                                  if (newPass != confirmPass) {
                                    AppFeedback.heavy();
                                    context.showSnackBar(
                                      message: 'Passwords do not match.',
                                      type: SnackBarType.error,
                                    );
                                    return;
                                  }

                                  isUpdatingPassword.value = true;
                                  final result =
                                      await locator<UpdatePasswordUseCase>()(
                                        newPass,
                                      );
                                  isUpdatingPassword.value = false;

                                  if (result.isLeft) {
                                    final failure =
                                        (result as Left<Failure, void>).value;
                                    AppFeedback.heavy();
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            'Failed to update: '
                                            '${failure.message ?? "Error"}',
                                        type: SnackBarType.error,
                                      );
                                    }
                                  } else {
                                    AppFeedback.light();
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            'Password updated successfully!',
                                        type: SnackBarType.success,
                                      );
                                      currentPasswordController.clear();
                                      newPasswordController.clear();
                                      confirmPasswordController.clear();
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: isUpdatingPassword.value
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Update Password',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ShrinkableButton(
                              onTap: () async {
                                AppFeedback.selection();
                                final result =
                                    await locator<
                                      SendPasswordResetEmailUseCase
                                    >()(email);
                                if (result.isLeft) {
                                  final failure =
                                      (result as Left<Failure, void>).value;
                                  if (context.mounted) {
                                    context.showSnackBar(
                                      message:
                                          'Failed to send reset link: '
                                          '${failure.message ?? "Error"}',
                                      type: SnackBarType.error,
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    context.showSnackBar(
                                      message: 'Reset link sent to $email',
                                      type: SnackBarType.success,
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfacePrimary,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colors.surfaceBorder.withAlpha(90),
                                  ),
                                ),
                                child: Text(
                                  'Send Reset Email',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Biometric Lock & 2FA
                  _buildSectionContainer(
                    title: 'App Lock & Two-Factor Authentication',
                    subtitle:
                        'Protect your study notes with biometrics & '
                        'Authenticator App (TOTP)',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biometric App Lock',
                                  style: typography.body.medium.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  'Require Face ID / Fingerprint on launch',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: biometricLockEnabled.value,
                              activeTrackColor: colors.primary,
                              onChanged: (val) async {
                                AppFeedback.selection();
                                final biometricService =
                                    locator<BiometricAuthService>();
                                if (val) {
                                  final canAuth = await biometricService
                                      .canAuthenticate();
                                  if (!canAuth) {
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            'Biometrics is not available or enrolled on this device.',
                                        type: SnackBarType.error,
                                      );
                                    }
                                    return;
                                  }
                                  final authenticated = await biometricService
                                      .authenticate(
                                        localizedReason:
                                            'Confirm biometrics to enable App Lock',
                                      );
                                  if (!authenticated) {
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            'Biometric verification was not completed.',
                                        type: SnackBarType.error,
                                      );
                                    }
                                    return;
                                  }
                                  await biometricService
                                      .setBiometricLockEnabled(enabled: true);
                                  biometricLockEnabled.value = true;
                                  if (context.mounted) {
                                    context.showSnackBar(
                                      message:
                                          'Biometric App Lock enabled! Kortex '
                                          'will require authentication on '
                                          'launch.',
                                      type: SnackBarType.success,
                                    );
                                  }
                                } else {
                                  await biometricService
                                      .setBiometricLockEnabled(enabled: false);
                                  biometricLockEnabled.value = false;
                                  if (context.mounted) {
                                    context.showSnackBar(
                                      message: 'Biometric App Lock disabled.',
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Two-Factor Auth (TOTP)',
                                  style: typography.body.medium.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  twoFactorEnabled.value
                                      ? 'Active • Authenticator linked'
                                      : 'Require 6-digit TOTP code on login',
                                  style: typography.caption.regular.copyWith(
                                    color: twoFactorEnabled.value
                                        ? const Color(0xFF10B981)
                                        : colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: twoFactorEnabled.value,
                              activeTrackColor: colors.primary,
                              onChanged: (val) async {
                                AppFeedback.selection();
                                if (val) {
                                  await _enrollTotp(
                                    context,
                                    twoFactorEnabled,
                                    activeTotpFactorId,
                                    colors,
                                    typography,
                                  );
                                } else {
                                  await _unenrollTotp(
                                    context,
                                    twoFactorEnabled,
                                    activeTotpFactorId,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Active Sessions & Sign Out Everywhere
                  _buildSectionContainer(
                    title: 'Active Sessions & Device Management',
                    subtitle:
                        'Review authorized devices connected to your account',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.surfaceBorder.withAlpha(70),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.phone_iphone_rounded,
                                  color: Color(0xFF10B981),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Mobile Device',
                                      style: typography.body.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Active Now • Authorized Session',
                                      style: typography.caption.regular
                                          .copyWith(
                                            color: const Color(0xFF10B981),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ShrinkableButton(
                          onTap: () async {
                            AppFeedback.medium();
                            final result =
                                await locator<SignOutOtherSessionsUseCase>()(
                                  const NoParams(),
                                );
                            if (result.isLeft) {
                              final failure =
                                  (result as Left<Failure, void>).value;
                              if (context.mounted) {
                                context.showSnackBar(
                                  message: failure.message ?? 'Sign out failed',
                                  type: SnackBarType.error,
                                );
                              }
                            } else {
                              if (context.mounted) {
                                context.showSnackBar(
                                  message:
                                      'Signed out of all other active '
                                      'sessions!',
                                  type: SnackBarType.success,
                                );
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.error.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.error.withAlpha(80),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Sign Out All Other Devices',
                                style: typography.caption.bold.copyWith(
                                  color: colors.error,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Danger Zone: Delete Account
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.error.withAlpha(isDark ? 25 : 12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.error.withAlpha(isDark ? 90 : 60),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danger Zone',
                          style: typography.body.bold.copyWith(
                            color: colors.error,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Permanently delete your account, synced flashcard '
                          'decks, and Syllabot conversation history.',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ShrinkableButton(
                          onTap: () => _confirmAccountDeletion(
                            context,
                            colors,
                            typography,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Delete Account & Purge Data',
                                style: typography.caption.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required Widget child,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStrengthTag({
    required String label,
    required bool isValid,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isValid
            ? const Color(0xFF10B981).withAlpha(25)
            : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid
              ? const Color(0xFF10B981).withAlpha(90)
              : colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isValid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: isValid
                ? const Color(0xFF10B981)
                : colors.textSecondary.withAlpha(120),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: isValid ? const Color(0xFF10B981) : colors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enrollTotp(
    BuildContext context,
    ValueNotifier<bool> twoFactorEnabled,
    ValueNotifier<String?> activeTotpFactorId,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) async {
    final email =
        context.read<AuthBloc>().state.userProfile?.email ??
        'scholar@kortexify.com';
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TwoFactorSetupPage(email: email),
      ),
    );
    if (success == true) {
      twoFactorEnabled.value = true;
    } else {
      twoFactorEnabled.value = false;
    }
  }

  Future<void> _unenrollTotp(
    BuildContext context,
    ValueNotifier<bool> twoFactorEnabled,
    ValueNotifier<String?> activeTotpFactorId,
  ) async {
    final factorId = activeTotpFactorId.value;
    if (factorId != null) {
      final result = await locator<UnenrollMfaTotpUseCase>()(factorId);
      if (result.isLeft) {
        final failure = (result as Left<Failure, void>).value;
        if (context.mounted) {
          context.showSnackBar(
            message: 'Could not disable 2FA: ${failure.message ?? "Error"}',
            type: SnackBarType.error,
          );
        }
      } else {
        twoFactorEnabled.value = false;
        activeTotpFactorId.value = null;
        if (context.mounted) {
          context.showSnackBar(
            message: 'Two-Factor Authentication disabled.',
          );
        }
      }
    } else {
      twoFactorEnabled.value = false;
    }
  }

  void _confirmAccountDeletion(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    AppFeedback.heavy();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Account Permanently?',
            style: typography.title3.bold.copyWith(
              color: colors.error,
            ),
          ),
          content: Text(
            'This action is irreversible. All your study streak data, '
            'flashcard decks, and AI notes will be completely purged from '
            'our servers.',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await locator<DeleteAccountUseCase>()(const NoParams());

                if (context.mounted) {
                  context.read<AuthBloc>().add(const AuthSignOutRequested());
                  await context.router.root.replaceAll([const LoginRoute()]);
                  if (context.mounted) {
                    context.showSnackBar(
                      message: 'Your account and data have been purged.',
                      type: SnackBarType.success,
                    );
                  }
                }
              },
              child: Text(
                'Delete Forever',
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
