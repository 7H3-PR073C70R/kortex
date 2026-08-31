import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  needsEmailVerification,
  resetSent,
  error,
}

/// State representation for authentication flows.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.needsEmailVerification = false,
  });

  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;
  final bool needsEmailVerification;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResetSent => status == AuthStatus.resetSent;
  bool get requiresOtp => status == AuthStatus.needsEmailVerification;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
    bool? needsEmailVerification,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      needsEmailVerification:
          needsEmailVerification ?? this.needsEmailVerification,
    );
  }

  @override
  List<Object?> get props =>
      [status, user, errorMessage, needsEmailVerification];
}
