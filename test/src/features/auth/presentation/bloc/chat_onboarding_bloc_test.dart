import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/auth/presentation/bloc/chat_onboarding_bloc.dart';

void main() {
  group('ChatOnboardingBloc Test Suite', () {
    late ChatOnboardingBloc bloc;

    setUp(() {
      bloc = ChatOnboardingBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state has empty messages', () {
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.isThinking, isFalse);
      expect(bloc.state.currentStep, 0);
    });

    blocTest<ChatOnboardingBloc, ChatOnboardingState>(
      'ChatOnboardingStarted adds welcome and track picker messages',
      build: () => bloc,
      act: (bloc) => bloc.add(const ChatOnboardingStarted()),
      verify: (bloc) {
        expect(bloc.state.messages.length, 2);
        expect(
          bloc.state.messages[1].embeddedWidgetType,
          EmbeddedWidgetType.trackPicker,
        );
      },
    );

    blocTest<ChatOnboardingBloc, ChatOnboardingState>(
      'ChatOnboardingTrackChosen appends user choice and AI goal slider '
      'message',
      build: () => bloc,
      seed: () => ChatOnboardingState(
        messages: [
          ChatOnboardingMessage(
            id: 'msg_welcome',
            sender: ChatSender.ai,
            text: 'Welcome',
            timestamp: DateTime(2026),
          ),
        ],
      ),
      act: (bloc) => bloc.add(const ChatOnboardingTrackChosen('JAMB')),
      wait: const Duration(milliseconds: 600),
      verify: (bloc) {
        expect(bloc.state.currentStep, 1);
        expect(bloc.state.messages.length, 3);
        expect(
          bloc.state.messages.last.embeddedWidgetType,
          EmbeddedWidgetType.goalSlider,
        );
      },
    );

    blocTest<ChatOnboardingBloc, ChatOnboardingState>(
      'ChatOnboardingGoalChosen appends user goal and AI summary ready message',
      build: () => bloc,
      seed: () => ChatOnboardingState(
        messages: [
          ChatOnboardingMessage(
            id: 'msg_1',
            sender: ChatSender.ai,
            text: 'Welcome',
            timestamp: DateTime(2026),
          ),
        ],
      ),
      act: (bloc) => bloc.add(
        const ChatOnboardingGoalChosen(
          dailyTarget: 30,
          retentionPercent: 85,
        ),
      ),
      wait: const Duration(milliseconds: 600),
      verify: (bloc) {
        expect(bloc.state.currentStep, 2);
        expect(bloc.state.messages.length, 3);
        expect(
          bloc.state.messages.last.embeddedWidgetType,
          EmbeddedWidgetType.summaryReady,
        );
      },
    );
  });
}
