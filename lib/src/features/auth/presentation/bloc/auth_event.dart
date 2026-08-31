import 'package:equatable/equatable.dart';

/// Base class for all authentication events.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
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

/// Dispatched when a user requests a password reset link.
class AuthResetPasswordRequested extends AuthEvent {
  const AuthResetPasswordRequested({
    required this.email,
  });

  final String email;

  @override
  List<Object?> get props => [email];
}
