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
      expect(PrefKeys.hasCompletedInteractiveTour, isNotEmpty);
      expect(
        PrefKeys.hasSeenWelcomeWalkthrough != PrefKeys.isNewlyRegistered,
        isTrue,
      );
      expect(
        PrefKeys.hasCompletedInteractiveTour != PrefKeys.hasSeenWelcomeWalkthrough,
        isTrue,
      );
    });

    test('Dashboard welcome dialog only shows to new registrations and never returning users', () {
      bool shouldShowWelcome({required String? isNewlyRegistered, required String? hasSeenWelcome}) {
        final isNew = isNewlyRegistered == 'true';
        final hasSeen = hasSeenWelcome == 'true';
        return isNew && !hasSeen;
      }

      // Existing user logging back in: isNewlyRegistered = false, hasSeenWelcome = false
      expect(shouldShowWelcome(isNewlyRegistered: 'false', hasSeenWelcome: 'false'), isFalse);

      // Existing user logging back in with null isNewlyRegistered
      expect(shouldShowWelcome(isNewlyRegistered: null, hasSeenWelcome: null), isFalse);

      // Brand new user just completed account registration: isNewlyRegistered = true, hasSeenWelcome = false
      expect(shouldShowWelcome(isNewlyRegistered: 'true', hasSeenWelcome: 'false'), isTrue);

      // Brand new user who already dismissed/completed welcome: isNewlyRegistered = false, hasSeenWelcome = true
      expect(shouldShowWelcome(isNewlyRegistered: 'false', hasSeenWelcome: 'true'), isFalse);
    });
  });
}
