import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State holding draft auth inputs for seamless synchronization
/// between Chat & Form.
class AuthDraftState extends Equatable {
  const AuthDraftState({
    this.email = '',
    this.password = '',
    this.displayName = '',
    this.promoCode = '',
  });

  final String email;
  final String password;
  final String displayName;
  final String promoCode;

  AuthDraftState copyWith({
    String? email,
    String? password,
    String? displayName,
    String? promoCode,
  }) {
    return AuthDraftState(
      email: email ?? this.email,
      password: password ?? this.password,
      displayName: displayName ?? this.displayName,
      promoCode: promoCode ?? this.promoCode,
    );
  }

  @override
  List<Object?> get props => [email, password, displayName, promoCode];
}

/// Cubit synchronizing credentials between conversational AI chat
/// and standard form.
class AuthDraftCubit extends Cubit<AuthDraftState> {
  AuthDraftCubit() : super(const AuthDraftState());

  void updateEmail(String email) {
    emit(state.copyWith(email: email));
  }

  void updatePassword(String password) {
    emit(state.copyWith(password: password));
  }

  void updateDisplayName(String displayName) {
    emit(state.copyWith(displayName: displayName));
  }

  void updatePromoCode(String promoCode) {
    emit(state.copyWith(promoCode: promoCode));
  }

  void clear() {
    emit(const AuthDraftState());
  }
}
