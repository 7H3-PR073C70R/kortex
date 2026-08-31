import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_local_data_source.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/repositories/syllabot_repository_impl.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:mocktail/mocktail.dart';

class MockSyllabotRemoteDataSource extends Mock
    implements SyllabotRemoteDataSource {}

class MockSyllabotLocalDataSource extends Mock
    implements SyllabotLocalDataSource {}

void main() {
  group('Execution Engine Router & Fallback Unit Test Suite', () {
    late MockSyllabotRemoteDataSource mockRemoteDataSource;
    late MockSyllabotLocalDataSource mockLocalDataSource;
    late SyllabotRepositoryImpl repository;

    setUpAll(() {
      registerFallbackValue(SocraticMode.stepByStep);
      registerFallbackValue(ExecutionEngineType.cloudSupabase);
    });

    setUp(() {
      mockRemoteDataSource = MockSyllabotRemoteDataSource();
      mockLocalDataSource = MockSyllabotLocalDataSource();
      repository = SyllabotRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
      );
    });

    test(
      'routes directly to Local LLM when preferredEngine is localOnDevice',
      () async {
        when(
          () => mockLocalDataSource.generateOfflineResponse(
            prompt: any(named: 'prompt'),
            socraticMode: any(named: 'socraticMode'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable(['Local ', 'token ', 'stream']),
        );

        final stream = repository.streamResponse(
          prompt: 'Explain Newton Second Law',
          sessionId: 'session_1',
          socraticMode: SocraticMode.stepByStep,
          preferredEngine: ExecutionEngineType.localOnDevice,
        );

        final tokens = await stream.toList();
        expect(tokens.join(), equals('Local token stream'));

        verify(
          () => mockLocalDataSource.generateOfflineResponse(
            prompt: 'Explain Newton Second Law',
            socraticMode: SocraticMode.stepByStep,
          ),
        ).called(1);

        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test(
      'routes to Cloud Supabase engine when preferredEngine is cloudSupabase',
      () async {
        when(
          () => mockRemoteDataSource.streamResponse(
            prompt: any(named: 'prompt'),
            sessionId: any(named: 'sessionId'),
            socraticMode: any(named: 'socraticMode'),
            engine: any(named: 'engine'),
            contextHistory: any(named: 'contextHistory'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable(['Cloud ', 'Gemini ', 'response']),
        );

        final stream = repository.streamResponse(
          prompt: 'Derive quadratic equation',
          sessionId: 'session_2',
          socraticMode: SocraticMode.deepResearch,
          preferredEngine: ExecutionEngineType.cloudSupabase,
        );

        final tokens = await stream.toList();
        expect(tokens.join(), equals('Cloud Gemini response'));

        verify(
          () => mockRemoteDataSource.streamResponse(
            prompt: 'Derive quadratic equation',
            sessionId: 'session_2',
            socraticMode: SocraticMode.deepResearch,
            engine: ExecutionEngineType.cloudSupabase,
            contextHistory: any(named: 'contextHistory'),
          ),
        ).called(1);

        verifyZeroInteractions(mockLocalDataSource);
      },
    );

    test(
      'gracefully falls back to Local LLM when Cloud engine errors out',
      () async {
        final errorStreamController = StreamController<String>();

        when(
          () => mockRemoteDataSource.streamResponse(
            prompt: any(named: 'prompt'),
            sessionId: any(named: 'sessionId'),
            socraticMode: any(named: 'socraticMode'),
            engine: any(named: 'engine'),
            contextHistory: any(named: 'contextHistory'),
          ),
        ).thenAnswer((_) => errorStreamController.stream);

        when(
          () => mockLocalDataSource.generateOfflineResponse(
            prompt: any(named: 'prompt'),
            socraticMode: any(named: 'socraticMode'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable(
            ['Fallback ', 'offline ', 'explanation'],
          ),
        );

        final stream = repository.streamResponse(
          prompt: 'Explain thermodynamics',
          sessionId: 'session_3',
          socraticMode: SocraticMode.examSim,
          preferredEngine: ExecutionEngineType.cloudSupabase,
        );

        errorStreamController.addError(
          Exception('Network timeout: Supabase Edge Unreachable'),
        );

        final tokens = await stream.toList();
        expect(tokens.join(), equals('Fallback offline explanation'));

        verify(
          () => mockLocalDataSource.generateOfflineResponse(
            prompt: 'Explain thermodynamics',
            socraticMode: SocraticMode.examSim,
          ),
        ).called(1);
      },
    );
  });
}
