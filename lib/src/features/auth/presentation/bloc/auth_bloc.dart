import 'package:bloc/bloc.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';

/// Main authentication BLoC coordinating domain use cases with robust
/// error boundaries for network and service failures.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginWithEmailUseCase loginWithEmailUseCase,
    required RegisterWithEmailUseCase registerWithEmailUseCase,
    required LoginWithSocialUseCase loginWithSocialUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
  }) : _loginWithEmailUseCase = loginWithEmailUseCase,
       _registerWithEmailUseCase = registerWithEmailUseCase,
       _loginWithSocialUseCase = loginWithSocialUseCase,
       _resetPasswordUseCase = resetPasswordUseCase,
       super(const AuthState()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthSocialLoginRequested>(_onSocialLoginRequested);
    on<AuthResetPasswordRequested>(_onResetPasswordRequested);
  }

  final LoginWithEmailUseCase _loginWithEmailUseCase;
  final RegisterWithEmailUseCase _registerWithEmailUseCase;
  final LoginWithSocialUseCase _loginWithSocialUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _loginWithEmailUseCase(
        LoginParams(email: event.email, password: event.password),
      );
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                failure.message ??
                'Authentication failed. Please check your credentials.',
          ),
        ),
        (user) => emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
          ),
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Network connection failed. Please check your connection.',
        ),
      );
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _registerWithEmailUseCase(
        RegisterParams(
          email: event.email,
          password: event.password,
          displayName: event.displayName,
        ),
      );
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                failure.message ??
                'Registration failed. Please check your details.',
          ),
        ),
        (user) => emit(
          state.copyWith(
            status: AuthStatus.needsEmailVerification,
            user: user,
            needsEmailVerification: true,
          ),
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Network connection failed. Please check your connection.',
        ),
      );
    }
  }

  Future<void> _onSocialLoginRequested(
    AuthSocialLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _loginWithSocialUseCase(
        SocialAuthParams(
          provider: event.provider,
          idToken: event.idToken,
          rawNonce: event.rawNonce,
        ),
      );
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                failure.message ?? 'Social login failed. Please try again.',
          ),
        ),
        (user) => emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
          ),
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Network connection failed. Please check your connection.',
        ),
      );
    }
  }

  Future<void> _onResetPasswordRequested(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _resetPasswordUseCase(
        ResetPasswordParams(email: event.email),
      );
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                failure.message ??
                'Failed to send password reset. Please check your email.',
          ),
        ),
        (_) => emit(
          state.copyWith(
            status: AuthStatus.resetSent,
          ),
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Network connection failed. Please check your connection.',
        ),
      );
    }
  }
}
