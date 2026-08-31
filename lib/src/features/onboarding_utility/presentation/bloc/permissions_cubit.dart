import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      notificationsGranted:
          notificationsGranted ?? this.notificationsGranted,
      storageGranted: storageGranted ?? this.storageGranted,
    );
  }

  @override
  List<Object?> get props => [status, notificationsGranted, storageGranted];
}

/// Cubit managing runtime permission requests.
class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit() : super(const PermissionsState());

  Future<void> requestNotificationPermission() async {
    emit(state.copyWith(status: PermissionsStatus.requesting));
    final result = await Permission.notification.request();
    emit(
      state.copyWith(
        status: PermissionsStatus.initial,
        notificationsGranted: result.isGranted,
      ),
    );
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
    emit(state.copyWith(status: PermissionsStatus.completed));
  }

  void finishPermissions() {
    emit(state.copyWith(status: PermissionsStatus.completed));
  }
}
