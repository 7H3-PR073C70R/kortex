import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';

/// Base class for all authentication events.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on cold start to verify session tokens.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Internal event fired when reactive AuthSessionStatus changes.
class AuthStatusChanged extends AuthEvent {
  const AuthStatusChanged(this.status);

  final AuthSessionStatus status;

  @override
  List<Object?> get props => [status];
}

/// Dispatched when a user attempts email/password login.
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Dispatched when a user attempts registration.
class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    this.displayName,
  });

  final String email;
  final String password;
  final String? displayName;

  @override
  List<Object?> get props => [email, password, displayName];
}

/// Dispatched when a user taps Google or Apple sign-in.
class AuthSocialLoginRequested extends AuthEvent {
  const AuthSocialLoginRequested({
    required this.provider,
    required this.idToken,
    this.rawNonce,
  });

  final String provider;
  final String idToken;
  final String? rawNonce;

  @override
  List<Object?> get props => [provider, idToken, rawNonce];
}

/// Dispatched when a user requests a magic sign-in link.
class AuthMagicLinkRequested extends AuthEvent {
  const AuthMagicLinkRequested({
    required this.email,
  });

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Dispatched when a user requests a password reset link.
class AuthResetPasswordRequested extends AuthEvent {
  const AuthResetPasswordRequested({
    required this.email,
  });

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Dispatched to refresh or load user profile and track details.
class AuthProfileFetchRequested extends AuthEvent {
  const AuthProfileFetchRequested();
}

/// Dispatched when user changes their track & daily goal in profile settings.
class AuthUpdateCourseTrackRequested extends AuthEvent {
  const AuthUpdateCourseTrackRequested({
    required this.track,
    required this.dailyTarget,
    this.retentionBenchmark = 0.85,
  });

  final String track;
  final int dailyTarget;
  final double retentionBenchmark;

  @override
  List<Object?> get props => [track, dailyTarget, retentionBenchmark];
}

/// Dispatched when user taps Sign Out.
class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
