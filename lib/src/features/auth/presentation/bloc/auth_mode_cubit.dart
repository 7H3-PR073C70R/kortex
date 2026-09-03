import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

enum AuthMode {
  chat,
  form,
}

enum AuthFormType {
  login,
  register,
}

/// State representing active auth presentation mode and form tab.
class AuthModeState extends Equatable {
  const AuthModeState({
    this.mode = AuthMode.chat,
    this.formType = AuthFormType.login,
  });

  final AuthMode mode;
  final AuthFormType formType;

  bool get isChat => mode == AuthMode.chat;
  bool get isForm => mode == AuthMode.form;
  bool get isLogin => formType == AuthFormType.login;
  bool get isRegister => formType == AuthFormType.register;

  AuthModeState copyWith({
    AuthMode? mode,
    AuthFormType? formType,
  }) {
    return AuthModeState(
      mode: mode ?? this.mode,
      formType: formType ?? this.formType,
    );
  }

  @override
  List<Object?> get props => [mode, formType];
}

/// Cubit managing dual mode (AI Chat vs Quick Form) transitions.
class AuthModeCubit extends Cubit<AuthModeState> {
  AuthModeCubit() : super(const AuthModeState());

  void toggleMode() {
    emit(
      state.copyWith(
        mode: state.isChat ? AuthMode.form : AuthMode.chat,
      ),
    );
  }

  void setMode(AuthMode mode) {
    emit(state.copyWith(mode: mode));
  }

  void toggleFormType() {
    emit(
      state.copyWith(
        formType: state.isLogin ? AuthFormType.register : AuthFormType.login,
      ),
    );
  }

  void setFormType(AuthFormType formType) {
    emit(state.copyWith(formType: formType));
  }
}
