import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/ingestion/presentation/controllers/onboarding_stream_controller.dart';

void main() {
  group('OnboardingStreamController Sub-3s SLA & Buffer Guard Suite', () {
    test('Initial state is empty and non-streaming', () {
      final controller = OnboardingStreamController();
      expect(controller.currentState.cards, isEmpty);
      expect(controller.currentState.isStreaming, isFalse);
      expect(controller.currentState.isInitialReviewReady, isFalse);
    });

    test(
      'getCardOrPlaceholder returns synthesized placeholder during streaming',
      () {
        const card1 = GeneratedFlashcard(
          id: 'c1',
          front: 'Front 1',
          back: 'Back 1',
          explanation: 'Exp 1',
          isLocalInference: false,
        );

        const state = OnboardingStreamState(
          cards: [card1],
          isStreaming: true,
        );

        // Card at index 0 exists
        final cardAt0 = state.getCardOrPlaceholder(0);
        expect(cardAt0?.front, equals('Front 1'));
        expect(state.isCardSynthesizing(0), isFalse);

        // Card at index 1 is not yet in buffer -> Returns dynamic skeleton card
        final cardAt1 = state.getCardOrPlaceholder(1);
        expect(cardAt1?.id, equals('skeleton_card_1'));
        expect(cardAt1?.front, contains('Synthesizing card 2...'));
        expect(state.isCardSynthesizing(1), isTrue);

        // Beyond target count -> Returns null
        final cardAt25 = state.getCardOrPlaceholder(25);
        expect(cardAt25, isNull);
      },
    );

    test(
      'getCardOrPlaceholder returns null for missing cards when completed',
      () {
        const card1 = GeneratedFlashcard(
          id: 'c1',
          front: 'Front 1',
          back: 'Back 1',
          explanation: 'Exp 1',
          isLocalInference: false,
        );

        const state = OnboardingStreamState(
          cards: [card1],
          isCompleted: true,
        );

        expect(state.getCardOrPlaceholder(0)?.front, equals('Front 1'));
        expect(state.getCardOrPlaceholder(1), isNull);
      },
    );
  });
}
