import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/conversation_session_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_deck_from_chat_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/get_chat_history_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';

class _FakeSyllabotRepository implements SyllabotRepository {
  List<String> tokensToYield = ['Euler', '-Lagrange', ' Equation'];

  @override
  Stream<String> streamResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType preferredEngine,
    List<ChatMessageEntity> contextHistory = const [],
  }) async* {
    for (final token in tokensToYield) {
      yield token;
    }
  }

  @override
  Future<Either<Failure, List<ConversationSessionEntity>>>
  getChatSessions() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, ConversationSessionEntity>> createChatSession({
    required String title,
    required SocraticMode socraticMode,
  }) async {
    return Right(
      ConversationSessionEntity(
        id: 's_test',
        userId: 'u_test',
        title: title,
        socraticMode: socraticMode,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getSessionMessages({
    required String sessionId,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, void>> deleteChatSession({
    required String sessionId,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllChatSessions() async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, DeckEntity>> generateDeckFromChat({
    required String sessionId,
    required String deckTitle,
    required String courseCode,
    List<ChatMessageEntity> messages = const [],
  }) async {
    return Right(
      DeckEntity(
        id: 'deck_$sessionId',
        title: deckTitle,
        subject: courseCode,
        totalCards: 5,
        dueCards: 5,
        masteryRate: 0,
        category: 'AI Generated',
      ),
    );
  }

  @override
  Future<Either<Failure, void>> purgeExpiredAiCache() async {
    return const Right(null);
  }
}

void main() {
  group('SyllabotChatBloc', () {
    late _FakeSyllabotRepository repository;
    late StreamSyllabotResponseUseCase streamUseCase;
    late GetChatHistoryUseCase getHistoryUseCase;
    late GenerateDeckFromChatUseCase generateDeckUseCase;
    late SyllabotChatBloc bloc;

    setUp(() {
      repository = _FakeSyllabotRepository();
      streamUseCase = StreamSyllabotResponseUseCase(repository);
      getHistoryUseCase = GetChatHistoryUseCase(repository);
      generateDeckUseCase = GenerateDeckFromChatUseCase(repository);
      bloc = SyllabotChatBloc(
        streamResponseUseCase: streamUseCase,
        getChatHistoryUseCase: getHistoryUseCase,
        generateDeckUseCase: generateDeckUseCase,
      );
    });

    tearDown(() {
      unawaited(bloc.close());
    });

    test('initial state has idle status and default socratic mode', () {
      expect(bloc.state.status, SyllabotStatus.idle);
      expect(bloc.state.socraticMode, SocraticMode.stepByStep);
      expect(bloc.state.engineType, ExecutionEngineType.cloudSupabase);
      expect(bloc.state.messages, isEmpty);
    });

    test('mode and engine changes update state properly', () async {
      bloc.add(const ChangeSocraticModeEvent(SocraticMode.examSim));
      await expectLater(
        bloc.stream,
        emits(
          predicate<SyllabotChatState>(
            (s) => s.socraticMode == SocraticMode.examSim,
          ),
        ),
      );

      bloc.add(const ChangeEngineTypeEvent(ExecutionEngineType.localOnDevice));
      await expectLater(
        bloc.stream,
        emits(
          predicate<SyllabotChatState>(
            (s) => s.engineType == ExecutionEngineType.localOnDevice,
          ),
        ),
      );
    });

    test('StartNewSessionEvent clears current state', () async {
      bloc.add(const StartNewSessionEvent());
      await expectLater(
        bloc.stream,
        emits(
          predicate<SyllabotChatState>(
            (s) =>
                s.status == SyllabotStatus.idle &&
                s.messages.isEmpty &&
                s.sessionId.startsWith('session_'),
          ),
        ),
      );
    });

    test('ConvertToDeckEvent creates a deck successfully', () async {
      bloc.add(
        const ConvertToDeckEvent(
          sessionId: 'session_123',
          deckTitle: 'Mechanics Deck',
          courseCode: 'PHYS 301',
        ),
      );

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SyllabotChatState>(
            (s) => s.status == SyllabotStatus.generatingDeck,
          ),
          predicate<SyllabotChatState>(
            (s) =>
                s.status == SyllabotStatus.deckGenerated &&
                s.generatedDeck?.title == 'Mechanics Deck',
          ),
        ]),
      );
    });
  });
}
