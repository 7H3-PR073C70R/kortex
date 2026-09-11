import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionsStatus {
  initial,
  requesting,
  completed,
}

/// State tracking granted/denied permissions.
class PermissionsState extends Equatable {
  const PermissionsState({
    this.status = PermissionsStatus.initial,
    this.notificationsGranted = false,
    this.storageGranted = false,
  });

  final PermissionsStatus status;
  final bool notificationsGranted;
  final bool storageGranted;

  bool get isDone => status == PermissionsStatus.completed;

  PermissionsState copyWith({
    PermissionsStatus? status,
    bool? notificationsGranted,
    bool? storageGranted,
  }) {
    return PermissionsState(
      status: status ?? this.status,
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      storageGranted: storageGranted ?? this.storageGranted,
    );
  }

  @override
  List<Object?> get props => [status, notificationsGranted, storageGranted];
}

/// Cubit managing runtime permission requests.
class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit({LocalStorageService? localStorageService})
      : _localStorageService = localStorageService,
        super(const PermissionsState());

  final LocalStorageService? _localStorageService;

  Future<void> requestNotificationPermission() async {
    emit(state.copyWith(status: PermissionsStatus.requesting));
    final result = await Permission.notification.request();
    emit(
      state.copyWith(
        status: PermissionsStatus.initial,
        notificationsGranted: result.isGranted,
      ),
    );

    if (result.isGranted && locator.isRegistered<NotificationService>()) {
      try {
        final notifService = locator<NotificationService>();
        unawaited(notifService.requestPermission());
        final userStorage = locator.isRegistered<UserStorageService>()
            ? locator<UserStorageService>()
            : null;
        final userId = userStorage?.getUserId();
        if (userId != null && userId.isNotEmpty) {
          unawaited(notifService.syncDeviceTokenWithBackend(userId: userId));
        }
      } on Object catch (_) {}
    }
  }

  Future<void> requestStoragePermission() async {
    emit(state.copyWith(status: PermissionsStatus.requesting));
    // Use photos on iOS 14+, storage on Android <13
    final result = await Permission.storage.request();
    emit(
      state.copyWith(
        status: PermissionsStatus.initial,
        storageGranted: result.isGranted,
      ),
    );
  }

  void skipPermissions() {
    _markOnboardingCompleted();
    emit(state.copyWith(status: PermissionsStatus.completed));
  }

  void finishPermissions() {
    _markOnboardingCompleted();
    emit(state.copyWith(status: PermissionsStatus.completed));
  }

  void _markOnboardingCompleted() {
    try {
      final storage = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      unawaited(
        storage?.savePreference(
          key: PrefKeys.hasCompletedOnboarding,
          data: 'true',
        ),
      );
    } on Object catch (_) {}
  }
}
