import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/onboarding_utility/domain/use_cases/resend_otp_use_case.dart';
import 'package:kortex/src/features/onboarding_utility/domain/use_cases/verify_otp_use_case.dart';

enum OtpStatus {
  initial,
  loading,
  verified,
  error,
  resending,
  resent,
}

/// State for OTP verification flow.
class OtpState extends Equatable {
  const OtpState({
    this.status = OtpStatus.initial,
    this.secondsRemaining = 60,
    this.canResend = false,
    this.errorMessage,
  });

  final OtpStatus status;
  final int secondsRemaining;
  final bool canResend;
  final String? errorMessage;

  bool get isLoading => status == OtpStatus.loading;
  bool get isVerified => status == OtpStatus.verified;
  bool get isResending => status == OtpStatus.resending;

  OtpState copyWith({
    OtpStatus? status,
    int? secondsRemaining,
    bool? canResend,
    String? errorMessage,
  }) {
    return OtpState(
      status: status ?? this.status,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      canResend: canResend ?? this.canResend,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    secondsRemaining,
    canResend,
    errorMessage,
  ];
}

/// Cubit managing 6-digit OTP input, countdown timer, and resend flow.
class OtpCubit extends Cubit<OtpState> {
  OtpCubit({
    required VerifyOtpUseCase verifyOtpUseCase,
    required ResendOtpUseCase resendOtpUseCase,
  }) : _verifyOtpUseCase = verifyOtpUseCase,
       _resendOtpUseCase = resendOtpUseCase,
       super(const OtpState());

  final VerifyOtpUseCase _verifyOtpUseCase;
  final ResendOtpUseCase _resendOtpUseCase;
  Timer? _countdownTimer;

  /// Starts the 60s countdown allowing "Resend Code" after expiry.
  void startCountdown() {
    _countdownTimer?.cancel();
    emit(state.copyWith(secondsRemaining: 60, canResend: false));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.secondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        emit(state.copyWith(secondsRemaining: 0, canResend: true));
      } else {
        emit(state.copyWith(secondsRemaining: remaining));
      }
    });
  }

  /// Submits the 6-digit [otp] for the given [email].
  Future<void> verifyOtp({
    required String email,
    required String otp,
  }) async {
    if (state.isLoading) return;
    emit(state.copyWith(status: OtpStatus.loading));
    final result = await _verifyOtpUseCase(email: email, otp: otp);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: OtpStatus.error,
          errorMessage: failure.message ?? 'Verification failed. Try again.',
        ),
      ),
      (_) => emit(state.copyWith(status: OtpStatus.verified)),
    );
  }

  /// Resends OTP code to [email].
  Future<void> resendOtp({required String email}) async {
    if (!state.canResend || state.isResending) return;
    emit(state.copyWith(status: OtpStatus.resending));
    final result = await _resendOtpUseCase(email: email);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: OtpStatus.error,
          errorMessage: failure.message ?? 'Could not resend. Try again.',
        ),
      ),
      (_) {
        emit(state.copyWith(status: OtpStatus.resent));
        startCountdown();
      },
    );
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
