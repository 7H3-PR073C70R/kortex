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
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/domain/use_cases/send_password_reset_email_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_display_name_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_password_use_case.dart';
import 'package:kortex/src/shared/export/presentation/widgets/export_deck_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Consolidated Account & Security management page.
///
/// Features tabbed controls to manage:
/// - Security & Access: Password change, Biometric App Lock, Supabase MFA 2FA,
///   active session invalidation, and Danger Zone account purge.
/// - Account & Data: Scholar credentials, Anki/CSV/PDF deck portability,
///   and local storage/image cache management.
@RoutePage()
class SecuritySettingsPage extends HookWidget {
  const SecuritySettingsPage({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedTabIndex = useState<int>(initialTabIndex);

    final currentPasswordController = useTextEditingController();
    final newPasswordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();

    final isUpdatingPassword = useState<bool>(false);
    final biometricLockEnabled = useState<bool>(false);
    final backgroundLockTimeoutSeconds = useState<int>(30);
    final twoFactorEnabled = useState<bool>(false);
    final activeTotpFactorId = useState<String?>(null);

    final storage = locator<LocalStorageService>();

    useEffect(() {
      final savedBiometric =
          storage.getPreference(key: '__biometric_lock_enabled') == 'true';
      biometricLockEnabled.value = savedBiometric;

      final savedTimeoutStr =
          storage.getPreference(key: '__biometric_lock_timeout_seconds');
      if (savedTimeoutStr != null) {
        final parsed = int.tryParse(savedTimeoutStr);
        if (parsed != null && parsed >= 0) {
          backgroundLockTimeoutSeconds.value = parsed;
        }
      }

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
        final profile = state.userProfile;
        final displayName =
            profile?.displayName ??
            state.user?.displayName ??
            'Kortexify Scholar';
        final email =
            profile?.email ?? state.user?.email ?? 'scholar@kortexify.com';

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Account & Security',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Segmented Pill Tab Bar
                _buildSegmentBar(
                  selectedTab: selectedTabIndex,
                  colors: colors,
                  typography: typography,
                ),

                // Tab Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        ?currentChild,
                      ],
                    ),
                    child: selectedTabIndex.value == 0
                        ? _buildSecurityTab(
                            context: context,
                            email: email,
                            colors: colors,
                            typography: typography,
                            isDark: isDark,
                            currentPasswordController:
                                currentPasswordController,
                            newPasswordController: newPasswordController,
                            confirmPasswordController:
                                confirmPasswordController,
                            hasMinLength: hasMinLength,
                            hasNumber: hasNumber,
                            hasSpecial: hasSpecial,
                            isUpdatingPassword: isUpdatingPassword,
                            biometricLockEnabled: biometricLockEnabled,
                            backgroundLockTimeoutSeconds:
                                backgroundLockTimeoutSeconds,
                            twoFactorEnabled: twoFactorEnabled,
                            activeTotpFactorId: activeTotpFactorId,
                          )
                        : _buildAccountDataTab(
                            context: context,
                            displayName: displayName,
                            email: email,
                            colors: colors,
                            typography: typography,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentBar({
    required ValueNotifier<int> selectedTab,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              title: 'Security & Access',
              icon: Icons.shield_outlined,
              isSelected: selectedTab.value == 0,
              onTap: () {
                AppFeedback.selection();
                selectedTab.value = 0;
              },
              colors: colors,
              typography: typography,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              title: 'Account & Data',
              icon: Icons.person_outline_rounded,
              isSelected: selectedTab.value == 1,
              onTap: () {
                AppFeedback.selection();
                selectedTab.value = 1;
              },
              colors: colors,
              typography: typography,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return ShrinkableButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.white : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.white : colors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: SECURITY & ACCESS
  // ==========================================

  Widget _buildSecurityTab({
    required BuildContext context,
    required String email,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
    required TextEditingController currentPasswordController,
    required TextEditingController newPasswordController,
    required TextEditingController confirmPasswordController,
    required bool hasMinLength,
    required bool hasNumber,
    required bool hasSpecial,
    required ValueNotifier<bool> isUpdatingPassword,
    required ValueNotifier<bool> biometricLockEnabled,
    required ValueNotifier<int> backgroundLockTimeoutSeconds,
    required ValueNotifier<bool> twoFactorEnabled,
    required ValueNotifier<String?> activeTotpFactorId,
  }) {
    return SingleChildScrollView(
      key: const ValueKey('security_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Password Change Card
          _buildSectionContainer(
            title: 'Password & Authentication',
            subtitle: 'Update your account password or request a reset link',
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

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ShrinkableButton(
                        onTap: () async {
                          final newPass = newPasswordController.text.trim();
                          final confirmPass =
                              confirmPasswordController.text.trim();

                          if (newPass.length < 8) {
                            AppFeedback.heavy();
                            context.showSnackBar(
                              message: 'Password must be at least 8 chars.',
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
                              await locator<UpdatePasswordUseCase>()(newPass);
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
                                message: 'Password updated successfully!',
                                type: SnackBarType.success,
                              );
                              currentPasswordController.clear();
                              newPasswordController.clear();
                              confirmPasswordController.clear();
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: isUpdatingPassword.value
                                ? AppLogoLoader(
                                    size: 18,
                                    color: colors.white,
                                    showMessage: false,
                                  )
                                : Text(
                                    'Update Password',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.white,
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
                            await locator<SendPasswordResetEmailUseCase>()(
                              email,
                            );
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
                          final canAuth =
                              await biometricService.canAuthenticate();
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
                          await biometricService.setBiometricLockEnabled(
                            enabled: true,
                          );
                          biometricLockEnabled.value = true;
                          if (context.mounted) {
                            context.showSnackBar(
                              message:
                                  'Biometric App Lock enabled! Kortexify '
                                  'will require authentication on launch.',
                              type: SnackBarType.success,
                            );
                          }
                        } else {
                          await biometricService.setBiometricLockEnabled(
                            enabled: false,
                          );
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
                if (biometricLockEnabled.value) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(70),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Lock Timeout',
                              style: typography.body.medium.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Re-arm lock when backgrounded',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        DropdownButton<int>(
                          value: const [0, 15, 30, 60, 300]
                                  .contains(backgroundLockTimeoutSeconds.value)
                              ? backgroundLockTimeoutSeconds.value
                              : 30,
                          underline: const SizedBox.shrink(),
                          dropdownColor: colors.surfacePrimary,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colors.textSecondary,
                            size: 18,
                          ),
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 12,
                          ),
                          onChanged: (newSeconds) async {
                            if (newSeconds == null) return;
                            AppFeedback.selection();
                            backgroundLockTimeoutSeconds.value = newSeconds;
                            await locator<BiometricAuthService>()
                                .setBackgroundLockTimeout(
                              Duration(seconds: newSeconds),
                            );
                            if (context.mounted) {
                              context.showSnackBar(
                                message: 'Auto-lock timeout updated.',
                              );
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Immediately')),
                            DropdownMenuItem(value: 15, child: Text('15 seconds')),
                            DropdownMenuItem(
                              value: 30,
                              child: Text('30 seconds (Default)'),
                            ),
                            DropdownMenuItem(value: 60, child: Text('1 minute')),
                            DropdownMenuItem(value: 300, child: Text('5 minutes')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
                                ? colors.success
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

          // 3. Active Sessions & Device Management
          _buildSectionContainer(
            title: 'Active Sessions & Device Management',
            subtitle: 'Review authorized devices connected to your account',
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
                          color: colors.success.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.phone_iphone_rounded,
                          color: colors.success,
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
                              style: typography.caption.regular.copyWith(
                                color: colors.success,
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
                      final failure = (result as Left<Failure, void>).value;
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
                              'Signed out of all other active sessions!',
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
                          color: colors.white,
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
    );
  }

  // ==========================================
  // TAB 2: ACCOUNT & DATA
  // ==========================================

  Widget _buildAccountDataTab({
    required BuildContext context,
    required String displayName,
    required String email,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return SingleChildScrollView(
      key: const ValueKey('account_data_tab'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Account Credentials
          _buildSectionContainer(
            title: 'Account Credentials',
            subtitle: 'Your identity across devices and cloud sync',
            colors: colors,
            typography: typography,
            child: Column(
              children: [
                _buildAccountRow(
                  label: 'Display Name',
                  value: displayName,
                  actionLabel: 'Edit',
                  onAction: () => _showEditNameDialog(
                    context,
                    displayName,
                  ),
                  colors: colors,
                  typography: typography,
                ),
                const Divider(height: 20),
                _buildAccountRow(
                  label: 'Email Address',
                  value: email,
                  actionLabel: 'Verified',
                  isVerified: true,
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Data Portability & Export (Anki, PDF, CSV)
          _buildSectionContainer(
            title: 'Data Portability & Export',
            subtitle: 'Export your flashcard decks and study notes',
            colors: colors,
            typography: typography,
            child: Column(
              children: [
                _buildExportOption(
                  icon: Icons.ios_share_rounded,
                  title: 'Export Study Decks (Anki, CSV, PDF)',
                  subtitle: 'Export active decks with full SRS intervals',
                  onTap: () => _exportDeckFlow(context),
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Storage & AI Cache Management
          _buildSectionContainer(
            title: 'Storage & AI Cache Management',
            subtitle: 'Free up local device memory without losing study data',
            colors: colors,
            typography: typography,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Syllabot & Image Cache',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      'Temporary audio, token & image buffers',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                ShrinkableButton(
                  onTap: () {
                    AppFeedback.light();
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    context.showSnackBar(
                      message: 'Local memory and image cache cleared!',
                      type: SnackBarType.success,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.primary.withAlpha(80),
                      ),
                    ),
                    child: Text(
                      'Clear Cache',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED SECTION CONTAINERS & HELPERS
  // ==========================================

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

  Widget _buildAccountRow({
    required String label,
    required String value,
    required String actionLabel,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    VoidCallback? onAction,
    bool isVerified = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: typography.body.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  actionLabel,
                  style: typography.caption.bold.copyWith(
                    color: colors.success,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        else
          ShrinkableButton(
            onTap: onAction ?? () {},
            child: Text(
              actionLabel,
              style: typography.caption.bold.copyWith(
                color: colors.primary,
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(80),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colors.textSecondary,
            ),
          ],
        ),
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
            ? colors.success.withAlpha(25)
            : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid
              ? colors.success.withAlpha(90)
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
                ? colors.success
                : colors.textSecondary.withAlpha(120),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: isValid ? colors.success : colors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ACTION FLOWS & DIALOGS
  // ==========================================

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    AppFeedback.selection();
    unawaited(
      AppDialog.show(
        context: context,
        title: 'Edit Display Name',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppTextField(
            controller: controller,
            hintText: 'Enter your scholar alias',
          ),
        ),
        primaryActionText: 'Save',
        onPrimaryAction: () async {
          final newName = controller.text.trim();
          if (newName.isNotEmpty) {
            Navigator.of(context).pop();
            context.read<AuthBloc>().add(AuthDisplayNameUpdated(newName));
            final result = await locator<UpdateDisplayNameUseCase>()(newName);
            result.fold(
              (failure) {
                if (context.mounted) {
                  context.showSnackBar(
                    message: 'Failed to update name: ${failure.message}',
                    type: SnackBarType.error,
                  );
                }
              },
              (_) {
                AppFeedback.light();
                if (context.mounted) {
                  context.read<AuthBloc>().add(
                    const AuthProfileFetchRequested(),
                  );
                  context.showSnackBar(
                    message: 'Display name updated to $newName',
                    type: SnackBarType.success,
                  );
                }
              },
            );
          }
        },
      ),
    );
  }

  Future<void> _exportDeckFlow(BuildContext context) async {
    AppFeedback.light();
    if (!locator.isRegistered<GetUserDecksUseCase>()) {
      context.showSnackBar(
        message: 'Deck export service unavailable',
        type: SnackBarType.error,
      );
      return;
    }

    final decksRes = await locator<GetUserDecksUseCase>()();
    var decks = <DeckEntity>[];
    decksRes.fold(
      (_) {},
      (list) => decks = list,
    );

    if (decks.isEmpty) {
      if (context.mounted) {
        context.showSnackBar(
          message: 'No study decks found to export. Create a deck first!',
        );
      }
      return;
    }

    if (!context.mounted) return;

    if (decks.length == 1) {
      await _openExportSheet(context, decks.first);
      return;
    }

    final colors = context.colors;
    final typography = context.typography;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: sheetContext.colors.surfacePrimary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Deck to Export',
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: decks.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final d = decks[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.style_rounded,
                        color: colors.primary,
                      ),
                      title: Text(
                        d.title,
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${d.totalCards} cards • ${d.subject}',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textSecondary,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_openExportSheet(context, d));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openExportSheet(BuildContext context, DeckEntity deck) async {
    var populatedDeck = deck;
    if (populatedDeck.cards.isEmpty &&
        locator.isRegistered<GetDeckCardsUseCase>()) {
      final res = await locator<GetDeckCardsUseCase>()(deck.id);
      res.fold((_) {}, (cards) {
        populatedDeck = populatedDeck.copyWith(cards: cards);
      });
    }
    if (context.mounted) {
      await ExportDeckModalSheet.show(context, deck: populatedDeck);
    }
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
        context.read<AuthBloc>().state.user?.email ??
        (locator.isRegistered<UserStorageService>()
            ? locator<UserStorageService>().getUserEmail()
            : null);
    final success = await context.router.push<bool>(
      TwoFactorSetupRoute(email: email),
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
                  locator<AuthModeCubit>().resetToAiChat();
                  context.read<AuthBloc>().add(const AuthSignOutRequested());
                  await context.router.root.replaceAll([const AuthRoute()]);
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
