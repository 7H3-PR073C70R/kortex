import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/domain/use_cases/send_password_reset_email_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_display_name_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_password_use_case.dart';
import 'package:kortex/src/features/profile/presentation/widgets/active_sessions_list_widget.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_account_credentials_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_biometrics_and_mfa_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_danger_zone_card.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_data_portability_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_deck_picker_dialog.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_password_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_storage_cache_section.dart';
import 'package:kortex/src/shared/export/presentation/widgets/export_deck_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';

/// Consolidated Account & Security management page.
@RoutePage()
class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({
    super.key,
    this.initialTabIndex = 0,
    this.authBloc,
    this.localStorageService,
    this.biometricAuthService,
    this.userActivityService,
    this.userStorageService,
    this.updatePasswordUseCase,
    this.sendPasswordResetEmailUseCase,
    this.listMfaFactorsUseCase,
    this.unenrollMfaTotpUseCase,
    this.signOutOtherSessionsUseCase,
    this.updateDisplayNameUseCase,
    this.getUserDecksUseCase,
    this.getDeckCardsUseCase,
  });

  final int initialTabIndex;
  final AuthBloc? authBloc;
  final LocalStorageService? localStorageService;
  final BiometricAuthService? biometricAuthService;
  final UserActivityService? userActivityService;
  final UserStorageService? userStorageService;
  final UpdatePasswordUseCase? updatePasswordUseCase;
  final SendPasswordResetEmailUseCase? sendPasswordResetEmailUseCase;
  final ListMfaFactorsUseCase? listMfaFactorsUseCase;
  final UnenrollMfaTotpUseCase? unenrollMfaTotpUseCase;
  final SignOutOtherSessionsUseCase? signOutOtherSessionsUseCase;
  final UpdateDisplayNameUseCase? updateDisplayNameUseCase;
  final GetUserDecksUseCase? getUserDecksUseCase;
  final GetDeckCardsUseCase? getDeckCardsUseCase;

  @override
  Widget build(BuildContext context) {
    final effectiveAuthBloc = authBloc ??
        (locator.isRegistered<AuthBloc>() ? locator<AuthBloc>() : null);

    final view = SecuritySettingsView(
      initialTabIndex: initialTabIndex,
      localStorageService: localStorageService,
      biometricAuthService: biometricAuthService,
      userActivityService: userActivityService,
      userStorageService: userStorageService,
      updatePasswordUseCase: updatePasswordUseCase,
      sendPasswordResetEmailUseCase: sendPasswordResetEmailUseCase,
      listMfaFactorsUseCase: listMfaFactorsUseCase,
      unenrollMfaTotpUseCase: unenrollMfaTotpUseCase,
      signOutOtherSessionsUseCase: signOutOtherSessionsUseCase,
      updateDisplayNameUseCase: updateDisplayNameUseCase,
      getUserDecksUseCase: getUserDecksUseCase,
      getDeckCardsUseCase: getDeckCardsUseCase,
    );

    if (effectiveAuthBloc != null) {
      return BlocProvider<AuthBloc>.value(
        value: effectiveAuthBloc,
        child: view,
      );
    }

    return view;
  }
}

class SecuritySettingsView extends HookWidget {
  const SecuritySettingsView({
    required this.initialTabIndex,
    this.localStorageService,
    this.biometricAuthService,
    this.userActivityService,
    this.userStorageService,
    this.updatePasswordUseCase,
    this.sendPasswordResetEmailUseCase,
    this.listMfaFactorsUseCase,
    this.unenrollMfaTotpUseCase,
    this.signOutOtherSessionsUseCase,
    this.updateDisplayNameUseCase,
    this.getUserDecksUseCase,
    this.getDeckCardsUseCase,
    super.key,
  });

  final int initialTabIndex;
  final LocalStorageService? localStorageService;
  final BiometricAuthService? biometricAuthService;
  final UserActivityService? userActivityService;
  final UserStorageService? userStorageService;
  final UpdatePasswordUseCase? updatePasswordUseCase;
  final SendPasswordResetEmailUseCase? sendPasswordResetEmailUseCase;
  final ListMfaFactorsUseCase? listMfaFactorsUseCase;
  final UnenrollMfaTotpUseCase? unenrollMfaTotpUseCase;
  final SignOutOtherSessionsUseCase? signOutOtherSessionsUseCase;
  final UpdateDisplayNameUseCase? updateDisplayNameUseCase;
  final GetUserDecksUseCase? getUserDecksUseCase;
  final GetDeckCardsUseCase? getDeckCardsUseCase;

  LocalStorageService? get _storage =>
      localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  BiometricAuthService? get _biometrics =>
      biometricAuthService ??
      (locator.isRegistered<BiometricAuthService>()
          ? locator<BiometricAuthService>()
          : null);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedTabIndex = useState<int>(initialTabIndex);

    final currentPasswordController = useTextEditingController();
    final newPasswordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();

    final isUpdatingPassword = useState<bool>(false);
    final biometricLockEnabled = useState<bool>(false);
    final backgroundLockTimeoutSeconds = useState<int>(30);
    final twoFactorEnabled = useState<bool>(false);
    final activeTotpFactorId = useState<String?>(null);

    useEffect(() {
      final storage = _storage;
      if (storage != null) {
        final savedBiometric =
            storage.getPreference(key: '__biometric_lock_enabled') == 'true';
        biometricLockEnabled.value = savedBiometric;

        final savedTimeoutStr = storage.getPreference(
          key: '__biometric_lock_timeout_seconds',
        );
        if (savedTimeoutStr != null) {
          final parsed = int.tryParse(savedTimeoutStr);
          if (parsed != null && parsed >= 0) {
            backgroundLockTimeoutSeconds.value = parsed;
          }
        }
      }

      Future<void> loadMfa() async {
        final useCase = listMfaFactorsUseCase ??
            (locator.isRegistered<ListMfaFactorsUseCase>()
                ? locator<ListMfaFactorsUseCase>()
                : null);
        if (useCase != null) {
          final result = await useCase(const NoParams());
          if (result.isRight) {
            final factors =
                (result as Right<Failure, List<MfaFactorEntity>>).value;
            if (factors.isNotEmpty) {
              twoFactorEnabled.value = true;
              activeTotpFactorId.value = factors.first.id;
            }
          }
        }
      }

      unawaited(loadMfa());
      return null;
    }, const []);

    final newPasswordText = useValueListenable(newPasswordController).text;
    final hasMinLength = newPasswordText.length >= 8;
    final hasNumber = newPasswordText.contains(RegExp('[0-9]'));
    final hasSpecial = newPasswordText.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = state.userProfile;
        final displayName = profile?.displayName ??
            state.user?.displayName ??
            'Kortexify Scholar';
        final email =
            profile?.email ?? state.user?.email ?? 'scholar@kortexify.com';

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppAdaptiveAppBar(
            backgroundColor: colors.backgroundPrimary,
            titleText: 'Account & Security',
            breadcrumbs: [
              AppBreadcrumbItem(
                label: 'Profile & Settings',
                onTap: () => context.router.maybePop(),
              ),
              const AppBreadcrumbItem(label: 'Account & Security'),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    // Top Segmented Liquid Glass Pill Tab Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: AppLiquidGlassTabBar(
                        tabs: const ['Security & Access', 'Account & Data'],
                        selectedIndex: selectedTabIndex.value,
                        onTabSelected: (index) {
                          selectedTabIndex.value = index;
                        },
                      ),
                    ),

                    // Tab Content
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.snappy,
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
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
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityTab({
    required BuildContext context,
    required String email,
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
          SecurityPasswordSection(
            currentPasswordController: currentPasswordController,
            newPasswordController: newPasswordController,
            confirmPasswordController: confirmPasswordController,
            hasMinLength: hasMinLength,
            hasNumber: hasNumber,
            hasSpecial: hasSpecial,
            isUpdatingPassword: isUpdatingPassword.value,
            onUpdatePassword: () => _handleUpdatePassword(
              context,
              newPasswordController: newPasswordController,
              confirmPasswordController: confirmPasswordController,
              currentPasswordController: currentPasswordController,
              isUpdatingPassword: isUpdatingPassword,
            ),
            onSendResetEmail: () => _handleSendResetEmail(context, email),
          ),
          const SizedBox(height: 20),

          // 2. Biometric Lock & 2FA
          SecurityBiometricsAndMfaSection(
            biometricLockEnabled: biometricLockEnabled.value,
            backgroundLockTimeoutSeconds: backgroundLockTimeoutSeconds.value,
            twoFactorEnabled: twoFactorEnabled.value,
            onBiometricLockChanged: (val) => _handleBiometricLockChanged(
              context,
              val,
              biometricLockEnabled,
            ),
            onTimeoutChanged: (val) => _handleTimeoutChanged(
              context,
              val,
              backgroundLockTimeoutSeconds,
            ),
            onTwoFactorChanged: (val) => _handleTwoFactorChanged(
              context,
              val,
              twoFactorEnabled,
              activeTotpFactorId,
            ),
          ),
          const SizedBox(height: 20),

          // 3. Active Sessions & Device Management
          SecuritySectionContainer(
            title: 'Active Sessions & Device Management',
            subtitle: 'Review authorized devices connected to your account',
            child: ActiveSessionsListWidget(
              sessions: [
                DeviceSession(
                  id: 'current_session',
                  deviceName: Theme.of(context).platform == TargetPlatform.macOS
                      ? 'MacBook Pro / Desktop Workstation'
                      : Theme.of(context).platform == TargetPlatform.iOS
                      ? 'iPhone Scholar Workstation'
                      : Theme.of(context).platform == TargetPlatform.android
                      ? 'Android Scholar Device'
                      : 'Kortexify Web Client',
                  osType: Theme.of(context).platform == TargetPlatform.macOS
                      ? 'macos'
                      : Theme.of(context).platform == TargetPlatform.iOS
                      ? 'ios'
                      : Theme.of(context).platform == TargetPlatform.android
                      ? 'android'
                      : 'web',
                  ipAddress: '127.0.0.1 (Encrypted TLS)',
                  location: 'Current Device • Primary Session',
                  lastActive: DateTime.now(),
                  isCurrentDevice: true,
                ),
              ],
              onRevokeAllOthers: () => _handleRevokeAllOthers(context),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Danger Zone: Delete Account
          SecurityDangerZoneCard(
            onDeleteAccount: () => _handleDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDataTab({
    required BuildContext context,
    required String displayName,
    required String email,
  }) {
    return SingleChildScrollView(
      key: const ValueKey('account_data_tab'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Account Credentials
          SecurityAccountCredentialsSection(
            displayName: displayName,
            email: email,
            onSaveDisplayName: (newName) => _handleSaveDisplayName(
              context,
              newName,
            ),
          ),
          const SizedBox(height: 20),

          // 2. Data Portability & Export (Anki, PDF, CSV)
          SecurityDataPortabilitySection(
            onExportDecks: () => _handleExportDeckFlow(context),
            onExportGdprBundle: () => _handleExportGdprDataBundle(context),
          ),
          const SizedBox(height: 20),

          // 3. Storage & AI Cache Management
          const SecurityStorageCacheSection(),
        ],
      ),
    );
  }

  // ==========================================
  // ACTION HANDLERS
  // ==========================================

  Future<void> _handleUpdatePassword(
    BuildContext context, {
    required TextEditingController newPasswordController,
    required TextEditingController confirmPasswordController,
    required TextEditingController currentPasswordController,
    required ValueNotifier<bool> isUpdatingPassword,
  }) async {
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

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
    final useCase = updatePasswordUseCase ??
        (locator.isRegistered<UpdatePasswordUseCase>()
            ? locator<UpdatePasswordUseCase>()
            : null);

    if (useCase == null) {
      isUpdatingPassword.value = false;
      return;
    }

    final result = await useCase(newPass);
    isUpdatingPassword.value = false;

    if (result.isLeft) {
      final failure = (result as Left<Failure, void>).value;
      AppFeedback.heavy();
      if (context.mounted) {
        context.showSnackBar(
          message: 'Failed to update: ${failure.message ?? "Error"}',
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
  }

  Future<void> _handleSendResetEmail(
    BuildContext context,
    String email,
  ) async {
    AppFeedback.selection();
    final useCase = sendPasswordResetEmailUseCase ??
        (locator.isRegistered<SendPasswordResetEmailUseCase>()
            ? locator<SendPasswordResetEmailUseCase>()
            : null);
    if (useCase == null) return;

    final result = await useCase(email);
    if (result.isLeft) {
      final failure = (result as Left<Failure, void>).value;
      if (context.mounted) {
        context.showSnackBar(
          message: 'Failed to send reset link: ${failure.message ?? "Error"}',
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
  }

  Future<void> _handleBiometricLockChanged(
    BuildContext context,
    bool val,
    ValueNotifier<bool> biometricLockEnabled,
  ) async {
    AppFeedback.selection();
    final biometricService = _biometrics;
    if (biometricService == null) return;

    if (val) {
      final canAuth = await biometricService.canAuthenticate();
      if (!canAuth) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Biometrics is not available or enrolled on this device.',
            type: SnackBarType.error,
          );
        }
        return;
      }
      final authenticated = await biometricService.authenticate(
        localizedReason: 'Confirm biometrics to enable App Lock',
      );
      if (!authenticated) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Biometric verification was not completed.',
            type: SnackBarType.error,
          );
        }
        return;
      }
      await biometricService.setBiometricLockEnabled(enabled: true);
      biometricLockEnabled.value = true;
      if (context.mounted) {
        context.showSnackBar(
          message:
              'Biometric App Lock enabled! Kortexify will require authentication on launch.',
          type: SnackBarType.success,
        );
      }
    } else {
      await biometricService.setBiometricLockEnabled(enabled: false);
      biometricLockEnabled.value = false;
      if (context.mounted) {
        context.showSnackBar(message: 'Biometric App Lock disabled.');
      }
    }
  }

  Future<void> _handleTimeoutChanged(
    BuildContext context,
    int? newSeconds,
    ValueNotifier<int> backgroundLockTimeoutSeconds,
  ) async {
    if (newSeconds == null) return;
    AppFeedback.selection();
    backgroundLockTimeoutSeconds.value = newSeconds;
    final biometricService = _biometrics;
    if (biometricService != null) {
      await biometricService.setBackgroundLockTimeout(
        Duration(seconds: newSeconds),
      );
    }
    if (context.mounted) {
      context.showSnackBar(message: 'Auto-lock timeout updated.');
    }
  }

  Future<void> _handleTwoFactorChanged(
    BuildContext context,
    bool val,
    ValueNotifier<bool> twoFactorEnabled,
    ValueNotifier<String?> activeTotpFactorId,
  ) async {
    AppFeedback.selection();
    if (val) {
      final email = context.read<AuthBloc>().state.userProfile?.email ??
          context.read<AuthBloc>().state.user?.email ??
          (userStorageService?.getUserEmail() ??
              (locator.isRegistered<UserStorageService>()
                  ? locator<UserStorageService>().getUserEmail()
                  : null));
      final success = await context.router.push<bool>(
        TwoFactorSetupRoute(email: email),
      );
      if (success == true) {
        twoFactorEnabled.value = true;
      } else {
        twoFactorEnabled.value = false;
      }
    } else {
      final factorId = activeTotpFactorId.value;
      if (factorId != null) {
        final useCase = unenrollMfaTotpUseCase ??
            (locator.isRegistered<UnenrollMfaTotpUseCase>()
                ? locator<UnenrollMfaTotpUseCase>()
                : null);
        if (useCase != null) {
          final result = await useCase(factorId);
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
        }
      } else {
        twoFactorEnabled.value = false;
      }
    }
  }

  Future<void> _handleRevokeAllOthers(BuildContext context) async {
    AppFeedback.medium();
    final useCase = signOutOtherSessionsUseCase ??
        (locator.isRegistered<SignOutOtherSessionsUseCase>()
            ? locator<SignOutOtherSessionsUseCase>()
            : null);
    if (useCase == null) return;

    final result = await useCase(const NoParams());
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
          message: 'Signed out of all other active sessions!',
          type: SnackBarType.success,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    context.read<AuthBloc>().add(const AuthAccountDeleteRequested());
    await context.router.root.replaceAll([const AuthRoute()]);
    if (context.mounted) {
      context.showSnackBar(
        message: 'Your account and data have been completely purged.',
        type: SnackBarType.success,
      );
    }
  }

  Future<void> _handleSaveDisplayName(
    BuildContext context,
    String newName,
  ) async {
    context.read<AuthBloc>().add(AuthDisplayNameUpdated(newName));
    final useCase = updateDisplayNameUseCase ??
        (locator.isRegistered<UpdateDisplayNameUseCase>()
            ? locator<UpdateDisplayNameUseCase>()
            : null);
    if (useCase == null) return;

    final result = await useCase(newName);
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
          context.read<AuthBloc>().add(const AuthProfileFetchRequested());
          context.showSnackBar(
            message: 'Display name updated to $newName',
            type: SnackBarType.success,
          );
        }
      },
    );
  }

  Future<void> _handleExportGdprDataBundle(BuildContext context) async {
    AppFeedback.medium();
    final authState = context.read<AuthBloc>().state;
    final userProfile = authState.userProfile;
    final user = authState.user;

    final activityService = userActivityService ??
        (locator.isRegistered<UserActivityService>()
            ? locator<UserActivityService>()
            : null);

    final analyticsSummary = activityService?.getAnalyticsSummary();
    final heatMapData = activityService?.getHeatMapData();

    var decks = <DeckEntity>[];
    final decksUseCase = getUserDecksUseCase ??
        (locator.isRegistered<GetUserDecksUseCase>()
            ? locator<GetUserDecksUseCase>()
            : null);

    if (decksUseCase != null) {
      final decksRes = await decksUseCase();
      decksRes.fold((_) {}, (list) => decks = list);
    }

    final dataBundle = {
      'export_metadata': {
        'format': 'Kortex GDPR Data Export',
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
      },
      'profile': {
        'id': user?.id ?? userProfile?.id,
        'email': user?.email ?? userProfile?.email,
        'displayName': userProfile?.displayName ?? user?.displayName,
        'targetTrack': userProfile?.targetTrack,
        'dailyCardTarget': userProfile?.dailyCardTarget,
        'streakDays': userProfile?.streakDays,
        'level': userProfile?.level,
        'isPro': userProfile?.isPro,
      },
      'study_analytics': analyticsSummary != null
          ? {
              'weeklyMinutesStudied': analyticsSummary.weeklyMinutesStudied,
              'totalCardsMastered': analyticsSummary.totalCardsMastered,
              'overallRetentionRate': analyticsSummary.overallRetentionRate,
              'currentStreakDays': analyticsSummary.currentStreakDays,
              'xpPoints': analyticsSummary.xpPoints,
              'academicRank': analyticsSummary.academicRank,
            }
          : null,
      'heat_map_activity': heatMapData
          ?.map((h) => {
                'dateIso': h.dateIso,
                'cardsReviewed': h.cardsReviewed,
                'minutesStudied': h.minutesStudied,
                'intensityLevel': h.intensityLevel,
              })
          .toList(),
      'decks_count': decks.length,
      'decks': decks
          .map((d) => {
                'id': d.id,
                'title': d.title,
                'subject': d.subject,
                'totalCards': d.totalCards,
                'dueCards': d.dueCards,
                'masteryRate': d.masteryRate,
              })
          .toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(dataBundle);
    await Clipboard.setData(ClipboardData(text: jsonString));

    if (context.mounted) {
      context.showSnackBar(
        message:
            'GDPR Data Bundle copied to Clipboard (${jsonString.length} bytes)',
        type: SnackBarType.success,
      );
    }
  }

  Future<void> _handleExportDeckFlow(BuildContext context) async {
    AppFeedback.light();
    final decksUseCase = getUserDecksUseCase ??
        (locator.isRegistered<GetUserDecksUseCase>()
            ? locator<GetUserDecksUseCase>()
            : null);

    if (decksUseCase == null) {
      context.showSnackBar(
        message: 'Deck export service unavailable',
        type: SnackBarType.error,
      );
      return;
    }

    final decksRes = await decksUseCase();
    var decks = <DeckEntity>[];
    decksRes.fold((_) {}, (list) => decks = list);

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

    await SecurityDeckPickerDialog.show(
      context: context,
      decks: decks,
      onSelectDeck: (deck) => unawaited(_openExportSheet(context, deck)),
    );
  }

  Future<void> _openExportSheet(BuildContext context, DeckEntity deck) async {
    var populatedDeck = deck;
    final cardsUseCase = getDeckCardsUseCase ??
        (locator.isRegistered<GetDeckCardsUseCase>()
            ? locator<GetDeckCardsUseCase>()
            : null);

    if (populatedDeck.cards.isEmpty && cardsUseCase != null) {
      final res = await cardsUseCase(deck.id);
      res.fold((_) {}, (cards) {
        populatedDeck = populatedDeck.copyWith(cards: cards);
      });
    }
    if (context.mounted) {
      await ExportDeckModalSheet.show(context, deck: populatedDeck);
    }
  }
}
