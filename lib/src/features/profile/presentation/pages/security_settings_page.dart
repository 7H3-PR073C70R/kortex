import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/domain/use_cases/send_password_reset_email_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_display_name_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_password_use_case.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_access_tab.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_account_data_tab.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_action_coordinator.dart';
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
    this.actionCoordinator,
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
  final SecurityActionCoordinator? actionCoordinator;

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
      actionCoordinator: actionCoordinator,
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
    this.actionCoordinator,
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
  final SecurityActionCoordinator? actionCoordinator;

  SecurityActionCoordinator get _coordinator =>
      actionCoordinator ??
      SecurityActionCoordinator(
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

    final coordinator = useMemoized(() => _coordinator);

    useEffect(() {
      unawaited(
        coordinator.loadInitialPreferences(
          biometricLockEnabled: biometricLockEnabled,
          backgroundLockTimeoutSeconds: backgroundLockTimeoutSeconds,
          twoFactorEnabled: twoFactorEnabled,
          activeTotpFactorId: activeTotpFactorId,
        ),
      );
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
                            ? SecurityAccessTab(
                                currentPasswordController:
                                    currentPasswordController,
                                newPasswordController: newPasswordController,
                                confirmPasswordController:
                                    confirmPasswordController,
                                hasMinLength: hasMinLength,
                                hasNumber: hasNumber,
                                hasSpecial: hasSpecial,
                                isUpdatingPassword: isUpdatingPassword.value,
                                biometricLockEnabled:
                                    biometricLockEnabled.value,
                                backgroundLockTimeoutSeconds:
                                    backgroundLockTimeoutSeconds.value,
                                twoFactorEnabled: twoFactorEnabled.value,
                                onUpdatePassword: () =>
                                    coordinator.handleUpdatePassword(
                                  context,
                                  newPasswordController: newPasswordController,
                                  confirmPasswordController:
                                      confirmPasswordController,
                                  currentPasswordController:
                                      currentPasswordController,
                                  isUpdatingPassword: isUpdatingPassword,
                                ),
                                onSendResetEmail: () =>
                                    coordinator.handleSendResetEmail(
                                  context,
                                  email,
                                ),
                                onBiometricLockChanged: (val) =>
                                    coordinator.handleBiometricLockChanged(
                                  context,
                                  enabled: val,
                                  biometricLockEnabled: biometricLockEnabled,
                                ),
                                onTimeoutChanged: (val) =>
                                    coordinator.handleTimeoutChanged(
                                  context,
                                  val,
                                  backgroundLockTimeoutSeconds,
                                ),
                                onTwoFactorChanged: (val) =>
                                    coordinator.handleTwoFactorChanged(
                                  context,
                                  enabled: val,
                                  twoFactorEnabled: twoFactorEnabled,
                                  activeTotpFactorId: activeTotpFactorId,
                                ),
                                onRevokeAllOthers: () =>
                                    coordinator.handleRevokeAllOthers(context),
                                onDeleteAccount: () =>
                                    coordinator.handleDeleteAccount(context),
                              )
                            : SecurityAccountDataTab(
                                displayName: displayName,
                                email: email,
                                onSaveDisplayName: (newName) =>
                                    coordinator.handleSaveDisplayName(
                                  context,
                                  newName,
                                ),
                                onExportDecks: () =>
                                    coordinator.handleExportDeckFlow(context),
                                onExportGdprBundle: () => coordinator
                                    .handleExportGdprDataBundle(context),
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
}
