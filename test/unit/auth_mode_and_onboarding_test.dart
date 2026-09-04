import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';

void main() {
  group('AuthModeCubit & PrefKeys Suite', () {
    test('AuthModeCubit starts in AI Chat mode and can toggle to Form and back', () {
      final cubit = AuthModeCubit();
      expect(cubit.state.mode, AuthMode.chat);
      expect(cubit.state.isChat, isTrue);
      expect(cubit.state.isForm, isFalse);

      cubit.toggleMode();
      expect(cubit.state.mode, AuthMode.form);
      expect(cubit.state.isChat, isFalse);
      expect(cubit.state.isForm, isTrue);

      cubit.resetToAiChat();
      expect(cubit.state.mode, AuthMode.chat);
      expect(cubit.state.isChat, isTrue);
      expect(cubit.state.formType, AuthFormType.login);
    });

    test('PrefKeys constants are uniquely defined for new user welcome flow', () {
      expect(PrefKeys.hasSeenWelcomeWalkthrough, isNotEmpty);
      expect(PrefKeys.isNewlyRegistered, isNotEmpty);
      expect(
        PrefKeys.hasSeenWelcomeWalkthrough != PrefKeys.isNewlyRegistered,
        isTrue,
      );
    });
  });
}
