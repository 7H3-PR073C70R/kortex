import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsOnboarding,
  needsEmailVerification,
  magicLinkSent,
  resetSent,
  error,
}

/// State representation for authentication and session management.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.sessionStatus = AuthSessionStatus.unauthenticated,
    this.user,
    this.userProfile,
    this.errorMessage,
    this.needsEmailVerification = false,
    this.isMagicLinkSent = false,
  });

  final AuthStatus status;
  final AuthSessionStatus sessionStatus;
  final UserEntity? user;
  final UserProfileEntity? userProfile;
  final String? errorMessage;
  final bool needsEmailVerification;
  final bool isMagicLinkSent;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated =>
      sessionStatus == AuthSessionStatus.authenticatedComplete ||
      sessionStatus == AuthSessionStatus.authenticatedNeedsOnboarding;
  bool get isFullyAuthenticated =>
      sessionStatus == AuthSessionStatus.authenticatedComplete;
  bool get needsOnboarding =>
      sessionStatus == AuthSessionStatus.authenticatedNeedsOnboarding;
  bool get isResetSent => status == AuthStatus.resetSent;
  bool get requiresOtp => status == AuthStatus.needsEmailVerification;

  AuthState copyWith({
    AuthStatus? status,
    AuthSessionStatus? sessionStatus,
    UserEntity? user,
    UserProfileEntity? userProfile,
    String? errorMessage,
    bool? needsEmailVerification,
    bool? isMagicLinkSent,
  }) {
    return AuthState(
      status: status ?? this.status,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      user: user ?? this.user,
      userProfile: userProfile ?? this.userProfile,
      errorMessage: errorMessage,
      needsEmailVerification:
          needsEmailVerification ?? this.needsEmailVerification,
      isMagicLinkSent: isMagicLinkSent ?? this.isMagicLinkSent,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sessionStatus,
    user,
    userProfile,
    errorMessage,
    needsEmailVerification,
    isMagicLinkSent,
  ];
}
