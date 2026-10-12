import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/domain/use_cases/send_password_reset_email_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_display_name_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_password_use_case.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_deck_picker_dialog.dart';
import 'package:kortex/src/shared/export/presentation/widgets/export_deck_modal_sheet.dart';

/// Coordinator for actions in the Security & Account settings view.
class SecurityActionCoordinator {
  const SecurityActionCoordinator({
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

  Future<void> loadInitialPreferences({
    required ValueNotifier<bool> biometricLockEnabled,
    required ValueNotifier<int> backgroundLockTimeoutSeconds,
    required ValueNotifier<bool> twoFactorEnabled,
    required ValueNotifier<String?> activeTotpFactorId,
  }) async {
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

  Future<void> handleUpdatePassword(
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

  Future<void> handleSendResetEmail(
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

  Future<void> handleBiometricLockChanged(
    BuildContext context, {
    required bool enabled,
    required ValueNotifier<bool> biometricLockEnabled,
  }) async {
    AppFeedback.selection();
    final biometricService = _biometrics;
    if (biometricService == null) return;

    if (enabled) {
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

  Future<void> handleTimeoutChanged(
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

  Future<void> handleTwoFactorChanged(
    BuildContext context, {
    required bool enabled,
    required ValueNotifier<bool> twoFactorEnabled,
    required ValueNotifier<String?> activeTotpFactorId,
  }) async {
    AppFeedback.selection();
    if (enabled) {
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

  Future<void> handleRevokeAllOthers(BuildContext context) async {
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

  Future<void> handleDeleteAccount(BuildContext context) async {
    context.read<AuthBloc>().add(const AuthAccountDeleteRequested());
    await context.router.root.replaceAll([const AuthRoute()]);
    if (context.mounted) {
      context.showSnackBar(
        message: 'Your account and data have been completely purged.',
        type: SnackBarType.success,
      );
    }
  }

  Future<void> handleSaveDisplayName(
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

  Future<void> handleExportGdprDataBundle(BuildContext context) async {
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

  Future<void> handleExportDeckFlow(BuildContext context) async {
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
