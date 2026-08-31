import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_deck_from_chat_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/get_chat_history_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/query_document_context_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:mocktail/mocktail.dart';

class MockStreamSyllabotResponseUseCase extends Mock
    implements StreamSyllabotResponseUseCase {}

class MockGetChatHistoryUseCase extends Mock implements GetChatHistoryUseCase {}

class MockGenerateDeckFromChatUseCase extends Mock
    implements GenerateDeckFromChatUseCase {}

class MockQueryDocumentContextUseCase extends Mock
    implements QueryDocumentContextUseCase {}

void main() {
  group('SyllabotChatBloc SSE Streaming & Token Assembly Test Suite', () {
    late MockStreamSyllabotResponseUseCase mockStreamResponseUseCase;
    late MockGetChatHistoryUseCase mockGetChatHistoryUseCase;
    late MockGenerateDeckFromChatUseCase mockGenerateDeckUseCase;
    late MockQueryDocumentContextUseCase mockQueryDocumentContextUseCase;

    setUpAll(() {
      registerFallbackValue(SocraticMode.stepByStep);
      registerFallbackValue(ExecutionEngineType.cloudSupabase);
    });

    setUp(() {
      mockStreamResponseUseCase = MockStreamSyllabotResponseUseCase();
      mockGetChatHistoryUseCase = MockGetChatHistoryUseCase();
      mockGenerateDeckUseCase = MockGenerateDeckFromChatUseCase();
      mockQueryDocumentContextUseCase = MockQueryDocumentContextUseCase();
    });

    SyllabotChatBloc buildBloc({bool withRag = false}) => SyllabotChatBloc(
          streamResponseUseCase: mockStreamResponseUseCase,
          getChatHistoryUseCase: mockGetChatHistoryUseCase,
          generateDeckUseCase: mockGenerateDeckUseCase,
          queryDocumentContextUseCase:
              withRag ? mockQueryDocumentContextUseCase : null,
        );

    test('initial state has idle status and default socraticMode', () async {
      final bloc = buildBloc();
      expect(bloc.state.status, equals(SyllabotStatus.idle));
      expect(bloc.state.socraticMode, equals(SocraticMode.stepByStep));
      expect(bloc.state.engineType, equals(ExecutionEngineType.cloudSupabase));
      await bloc.close();
    });

    blocTest<SyllabotChatBloc, SyllabotChatState>(
      'SubmitPromptEvent streams tokens and completes into a bot message',
      build: () {
        when(
          () => mockStreamResponseUseCase(
            prompt: any(named: 'prompt'),
            sessionId: any(named: 'sessionId'),
            socraticMode: any(named: 'socraticMode'),
            preferredEngine: any(named: 'preferredEngine'),
            contextHistory: any(named: 'contextHistory'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable(
            ['Photosynthesis ', 'is ', 'vital.'],
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SubmitPromptEvent(
          prompt: 'What is photosynthesis?',
          sessionId: 'session_123',
          socraticMode: SocraticMode.stepByStep,
          engineType: ExecutionEngineType.cloudSupabase,
        ),
      ),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        expect(bloc.state.status, equals(SyllabotStatus.idle));
        expect(bloc.state.messages.length, equals(2));
        expect(
          bloc.state.messages.first.text,
          equals('What is photosynthesis?'),
        );
        expect(
          bloc.state.messages.last.text,
          equals('Photosynthesis is vital.'),
        );
      },
    );

    blocTest<SyllabotChatBloc, SyllabotChatState>(
      'SubmitPromptEvent queries RAG context and injects into stream history',
      build: () {
        const tChunks = [
          DocumentChunkEntity(
            id: 'chk_1',
            documentId: 'doc_bio',
            content: 'Chloroplasts absorb sunlight to produce ATP and NADPH.',
            similarityScore: 0.94,
          ),
        ];

        when(
          () => mockQueryDocumentContextUseCase(
            query: 'Explain light dependent reactions',
          ),
        ).thenAnswer((_) async => const Right(tChunks));

        when(
          () => mockStreamResponseUseCase(
            prompt: 'Explain light dependent reactions',
            sessionId: 'session_rag_1',
            socraticMode: SocraticMode.stepByStep,
            preferredEngine: ExecutionEngineType.cloudSupabase,
            contextHistory: any(
              named: 'contextHistory',
              that: isA<List<ChatMessageEntity>>().having(
                (l) => l.any((m) => m.text.contains('Chloroplasts absorb')),
                'contains RAG chunk snippet',
                isTrue,
              ),
            ),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable(
            ['Light reactions convert photons into ATP.'],
          ),
        );

        return buildBloc(withRag: true);
      },
      act: (bloc) => bloc.add(
        const SubmitPromptEvent(
          prompt: 'Explain light dependent reactions',
          sessionId: 'session_rag_1',
          socraticMode: SocraticMode.stepByStep,
          engineType: ExecutionEngineType.cloudSupabase,
        ),
      ),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        expect(bloc.state.messages.length, equals(2));
        expect(
          bloc.state.messages.last.text,
          equals('Light reactions convert photons into ATP.'),
        );
      },
    );

    blocTest<SyllabotChatBloc, SyllabotChatState>(
      'ChangeSocraticModeEvent updates socraticMode in state',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const ChangeSocraticModeEvent(SocraticMode.deepResearch),
      ),
      expect: () => [
        const SyllabotChatState(socraticMode: SocraticMode.deepResearch),
      ],
    );

    blocTest<SyllabotChatBloc, SyllabotChatState>(
      'ChangeEngineTypeEvent updates engineType in state',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const ChangeEngineTypeEvent(ExecutionEngineType.localOnDevice),
      ),
      expect: () => [
        const SyllabotChatState(engineType: ExecutionEngineType.localOnDevice),
      ],
    );
  });
}
