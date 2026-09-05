import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/auth_verify_otp_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/observe_auth_state_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/update_course_track_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/features/profile/data/client/profile_api_client.dart';

/// Main authentication BLoC coordinating domain use cases and reactive state.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginWithEmailUseCase loginWithEmailUseCase,
    required RegisterWithEmailUseCase registerWithEmailUseCase,
    required LoginWithSocialUseCase loginWithSocialUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required ObserveAuthStateUseCase observeAuthStateUseCase,
    required UpdateCourseTrackUseCase updateCourseTrackUseCase,
    required AuthVerifyOtpUseCase verifyOtpUseCase,
    required AuthRepository authRepository,
  }) : _loginWithEmailUseCase = loginWithEmailUseCase,
       _registerWithEmailUseCase = registerWithEmailUseCase,
       _loginWithSocialUseCase = loginWithSocialUseCase,
       _resetPasswordUseCase = resetPasswordUseCase,
       _observeAuthStateUseCase = observeAuthStateUseCase,
       _updateCourseTrackUseCase = updateCourseTrackUseCase,
       _verifyOtpUseCase = verifyOtpUseCase,
       _authRepository = authRepository,
       super(const AuthState()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
    on<AuthSocialLoginRequested>(_onSocialLoginRequested);
    on<AuthMagicLinkRequested>(_onMagicLinkRequested);
    on<AuthResetPasswordRequested>(_onResetPasswordRequested);
    on<AuthProfileFetchRequested>(_onProfileFetchRequested);
    on<AuthUpdateCourseTrackRequested>(_onUpdateCourseTrackRequested);
    on<AuthAvatarUpdated>(_onAvatarUpdated);
    on<AuthDisplayNameUpdated>(_onDisplayNameUpdated);
    on<AuthStreakIncremented>(_onStreakIncremented);
    on<AuthSignOutRequested>(_onSignOutRequested);

    _authSubscription = _observeAuthStateUseCase().listen((status) {
      if (!isClosed) {
        add(AuthStatusChanged(status));
      }
    });
  }

  final LoginWithEmailUseCase _loginWithEmailUseCase;
  final RegisterWithEmailUseCase _registerWithEmailUseCase;
  final LoginWithSocialUseCase _loginWithSocialUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final ObserveAuthStateUseCase _observeAuthStateUseCase;
  final UpdateCourseTrackUseCase _updateCourseTrackUseCase;
  final AuthVerifyOtpUseCase _verifyOtpUseCase;
  final AuthRepository _authRepository;

  StreamSubscription<AuthSessionStatus>? _authSubscription;

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final profileRes = await _authRepository.getUserProfile();
    profileRes.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          sessionStatus: AuthSessionStatus.unauthenticated,
        ),
      ),
      (profile) {
        if (profile.id.isEmpty && profile.email.isEmpty) {
          emit(
            state.copyWith(
              status: AuthStatus.unauthenticated,
              sessionStatus: AuthSessionStatus.unauthenticated,
            ),
          );
          return;
        }

        final session = profile.isOnboarded
            ? AuthSessionStatus.authenticatedComplete
            : AuthSessionStatus.authenticatedNeedsOnboarding;
        emit(
          state.copyWith(
            status: profile.isOnboarded
                ? AuthStatus.authenticated
                : AuthStatus.needsOnboarding,
            sessionStatus: session,
            userProfile: profile,
          ),
        );
        if (profile.id.isNotEmpty) {
          try {
            unawaited(RevenueCatService.instance.init(profile.id));
          } on Object catch (_) {}
        }
      },
    );
  }

  void _onAuthStatusChanged(
    AuthStatusChanged event,
    Emitter<AuthState> emit,
  ) {
    emit(
      state.copyWith(
        sessionStatus: event.status,
        status: event.status == AuthSessionStatus.authenticatedComplete
            ? AuthStatus.authenticated
            : event.status == AuthSessionStatus.authenticatedNeedsOnboarding
            ? AuthStatus.needsOnboarding
            : AuthStatus.unauthenticated,
      ),
    );
  }

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
                'Authentication failed. Please check credentials.',
          ),
        ),
        (user) {
          emit(
            state.copyWith(
              status: AuthStatus.authenticated,
              sessionStatus: AuthSessionStatus.authenticatedComplete,
              user: user,
            ),
          );
          if (user.id.isNotEmpty) {
            try {
              unawaited(RevenueCatService.instance.init(user.id));
            } on Object catch (_) {}
          }
          add(const AuthProfileFetchRequested());
        },
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
                failure.message ?? 'Registration failed. Please check details.',
          ),
        ),
        (user) {
          final hasActiveSession =
              user.token != null && user.token!.trim().isNotEmpty;
          if (hasActiveSession) {
            unawaited(
              locator<LocalStorageService>().savePreference(
                key: PrefKeys.isNewlyRegistered,
                data: 'true',
              ),
            );
            unawaited(
              locator<LocalStorageService>().deletePreference(
                key: PrefKeys.hasSeenWelcomeWalkthrough,
              ),
            );
            emit(
              state.copyWith(
                status: AuthStatus.needsOnboarding,
                sessionStatus: AuthSessionStatus.authenticatedNeedsOnboarding,
                needsEmailVerification: false,
                user: user,
              ),
            );
            add(const AuthProfileFetchRequested());
          } else {
            emit(
              state.copyWith(
                status: AuthStatus.needsEmailVerification,
                sessionStatus: AuthSessionStatus.unauthenticated,
                needsEmailVerification: true,
                user: user,
              ),
            );
          }
        },
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

  Future<void> _onVerifyOtpRequested(
    AuthVerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _verifyOtpUseCase(
        AuthVerifyOtpParams(
          email: event.email,
          token: event.token,
          type: event.type,
        ),
      );
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                failure.message ??
                'Invalid or expired verification code. Please try again.',
          ),
        ),
        (user) {
          unawaited(
            locator<LocalStorageService>().savePreference(
              key: PrefKeys.isNewlyRegistered,
              data: 'true',
            ),
          );
          unawaited(
            locator<LocalStorageService>().deletePreference(
              key: PrefKeys.hasSeenWelcomeWalkthrough,
            ),
          );
          emit(
            state.copyWith(
              status: AuthStatus.needsOnboarding,
              sessionStatus: AuthSessionStatus.authenticatedNeedsOnboarding,
              needsEmailVerification: false,
              user: user,
            ),
          );
          add(const AuthProfileFetchRequested());
        },
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
            errorMessage: failure.message ?? 'Social login failed.',
          ),
        ),
        (user) {
          emit(
            state.copyWith(
              status: AuthStatus.authenticated,
              sessionStatus: AuthSessionStatus.authenticatedComplete,
              user: user,
            ),
          );
          if (user.id.isNotEmpty) {
            try {
              unawaited(RevenueCatService.instance.init(user.id));
            } on Object catch (_) {}
          }
          add(const AuthProfileFetchRequested());
        },
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Social login connection failed.',
        ),
      );
    }
  }

  Future<void> _onMagicLinkRequested(
    AuthMagicLinkRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final res = await _authRepository.sendMagicLink(email: event.email);
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message ?? 'Failed to send magic link.',
        ),
      ),
      (_) => emit(
        state.copyWith(
          status: AuthStatus.magicLinkSent,
          isMagicLinkSent: true,
        ),
      ),
    );
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
            errorMessage: failure.message ?? 'Password reset failed.',
          ),
        ),
        (_) => emit(
          state.copyWith(status: AuthStatus.resetSent),
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Password reset connection failed.',
        ),
      );
    }
  }

  Future<void> _onProfileFetchRequested(
    AuthProfileFetchRequested event,
    Emitter<AuthState> emit,
  ) async {
    final res = await _authRepository.getUserProfile();
    res.fold(
      (_) {},
      (profile) {
        var mergedProfile = profile;
        try {
          final liveStreak = locator<UserActivityService>().getCurrentStreak();
          if (liveStreak > profile.streakDays) {
            mergedProfile = profile.copyWith(streakDays: liveStreak);
          }
        } on Object catch (_) {}
        emit(
          state.copyWith(
            userProfile: mergedProfile,
            sessionStatus: mergedProfile.isOnboarded
                ? AuthSessionStatus.authenticatedComplete
                : AuthSessionStatus.authenticatedNeedsOnboarding,
          ),
        );
        try {
          unawaited(
            locator<NotificationService>()
                .syncDeviceTokenWithBackend(userId: profile.id),
          );
        } on Object catch (_) {}
        if (profile.id.isNotEmpty) {
          try {
            unawaited(RevenueCatService.instance.init(profile.id));
          } on Object catch (_) {}
        }
      },
    );
  }

  Future<void> _onUpdateCourseTrackRequested(
    AuthUpdateCourseTrackRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.userProfile != null) {
      emit(
        state.copyWith(
          userProfile: state.userProfile!.copyWith(
            targetTrack: event.track,
            dailyCardTarget: event.dailyTarget,
            retentionBenchmark: event.retentionBenchmark,
          ),
        ),
      );
    }
    final res = await _updateCourseTrackUseCase(
      track: event.track,
      dailyTarget: event.dailyTarget,
      retentionBenchmark: event.retentionBenchmark,
    );
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message ?? 'Failed to update track.',
        ),
      ),
      (profile) {
        var mergedProfile = profile;
        try {
          final liveStreak = locator<UserActivityService>().getCurrentStreak();
          if (liveStreak > profile.streakDays) {
            mergedProfile = profile.copyWith(streakDays: liveStreak);
          }
        } on Object catch (_) {}
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            userProfile: profile.id.isNotEmpty ? mergedProfile : state.userProfile,
          ),
        );
      },
    );
  }

  void _onAvatarUpdated(
    AuthAvatarUpdated event,
    Emitter<AuthState> emit,
  ) {
    if (state.userProfile != null) {
      emit(
        state.copyWith(
          userProfile: state.userProfile!.copyWith(photoUrl: event.photoUrl),
        ),
      );
    }
  }

  void _onDisplayNameUpdated(
    AuthDisplayNameUpdated event,
    Emitter<AuthState> emit,
  ) {
    if (state.userProfile != null) {
      emit(
        state.copyWith(
          userProfile: state.userProfile!.copyWith(
            displayName: event.displayName,
          ),
        ),
      );
    }
  }

  void _onStreakIncremented(
    AuthStreakIncremented event,
    Emitter<AuthState> emit,
  ) {
    if (state.userProfile != null) {
      var liveStreak = 0;
      try {
        liveStreak = locator<UserActivityService>().getCurrentStreak();
      } on Object catch (_) {}

      final updatedStreak = liveStreak > 0
          ? liveStreak
          : (state.userProfile!.streakDays <= 0
              ? 1
              : state.userProfile!.streakDays + 1);

      emit(
        state.copyWith(
          userProfile: state.userProfile!.copyWith(streakDays: updatedStreak),
        ),
      );

      // Persist to Supabase profiles table
      try {
        unawaited(
          locator<ProfileApiClient>().updateProfile(
            userId: state.userProfile!.id,
            streakDays: updatedStreak,
          ),
        );
      } on Object catch (_) {}
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await locator<LocalStorageService>().deletePreference(
        key: PrefKeys.hasSeenWelcomeWalkthrough,
      );
      await locator<LocalStorageService>().deletePreference(
        key: PrefKeys.isNewlyRegistered,
      );
    } on Object catch (_) {}
    await _authRepository.signOut();
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
