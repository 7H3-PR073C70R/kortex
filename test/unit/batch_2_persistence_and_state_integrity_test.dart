import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/repositories/community_repository_impl.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/logic/ebbinghaus_decay_calculator.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/data/repositories/past_questions_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_deck_from_chat_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/get_chat_history_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:mocktail/mocktail.dart';

class MockPastQuestionsLocalDataSource extends Mock
    implements PastQuestionsLocalDataSource {}

class MockPastQuestionsRemoteDataSource extends Mock
    implements PastQuestionsRemoteDataSource {}

class MockCommunityRemoteDataSource extends Mock
    implements CommunityRemoteDataSource {}

class MockUserStorageService extends Mock implements UserStorageService {}

class MockStreamSyllabotResponseUseCase extends Mock
    implements StreamSyllabotResponseUseCase {}

class MockGetChatHistoryUseCase extends Mock
    implements GetChatHistoryUseCase {}

class MockGenerateDeckFromChatUseCase extends Mock
    implements GenerateDeckFromChatUseCase {}

class InMemoryLocalStorageService implements LocalStorageService {
  final Map<String, String> data = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => data[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    this.data[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryLocalStorageService memoryStorage;

  setUp(() async {
    memoryStorage = InMemoryLocalStorageService();
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    locator.registerSingleton<LocalStorageService>(memoryStorage);
  });

  tearDown(() async {
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
  });

  group('Batch 2 Fix 1: Syllabot AI Settings & Persistence', () {
    late MockStreamSyllabotResponseUseCase mockStreamResponse;
    late MockGetChatHistoryUseCase mockGetChatHistory;
    late MockGenerateDeckFromChatUseCase mockGenerateDeck;

    setUp(() {
      mockStreamResponse = MockStreamSyllabotResponseUseCase();
      mockGetChatHistory = MockGetChatHistoryUseCase();
      mockGenerateDeck = MockGenerateDeckFromChatUseCase();
    });

    test('SyllabotChatBloc loads persisted SocraticMode on init', () async {
      await memoryStorage.savePreference(
        key: PrefKeys.syllabotSocraticMode,
        data: SocraticMode.examSim.name,
      );

      final bloc = SyllabotChatBloc(
        streamResponseUseCase: mockStreamResponse,
        getChatHistoryUseCase: mockGetChatHistory,
        generateDeckUseCase: mockGenerateDeck,
        localStorageService: memoryStorage,
      );

      expect(bloc.state.socraticMode, equals(SocraticMode.examSim));
    });

    test('ChangeSocraticModeEvent updates state and writes to LocalStorage',
        () async {
      final bloc = SyllabotChatBloc(
        streamResponseUseCase: mockStreamResponse,
        getChatHistoryUseCase: mockGetChatHistory,
        generateDeckUseCase: mockGenerateDeck,
        localStorageService: memoryStorage,
      );
      expect(bloc.state.socraticMode, equals(SocraticMode.stepByStep));

      bloc.add(const ChangeSocraticModeEvent(SocraticMode.deepResearch));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.socraticMode, equals(SocraticMode.deepResearch));
      expect(
        memoryStorage.getPreference(key: PrefKeys.syllabotSocraticMode),
        equals(SocraticMode.deepResearch.name),
      );
    });

    test('TextToSpeechHandler loads saved voice preferences and speech rate',
        () async {
      await memoryStorage.savePreference(
        key: PrefKeys.syllabotVoiceGender,
        data: VoiceGender.male.name,
      );
      await memoryStorage.savePreference(
        key: PrefKeys.syllabotSpeechRate,
        data: '1.25',
      );

      final handler = TextToSpeechHandler(
        localStorageService: memoryStorage,
      );

      expect(handler.voiceGender, equals(VoiceGender.male));
      expect(handler.speechRate, equals(1.25));

      await handler.setSpeechRate(1.5);
      expect(handler.speechRate, equals(1.5));
    });
  });

  group('Batch 2 Fix 2: Past Question Bookmarks Persistence', () {
    late MockPastQuestionsRemoteDataSource mockRemoteDataSource;
    late MockPastQuestionsLocalDataSource mockLocalDataSource;
    late PastQuestionsRepositoryImpl repository;

    const testQuestionModel = PastQuestionModel(
      id: 'q_chem_101',
      examType: ExamCategory.jamb,
      subject: 'Chemistry',
      year: 2023,
      questionNumber: 1,
      prompt: 'What is the atomic number of Carbon?',
      options: ['5', '6', '7', '8'],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation: 'Carbon has 6 protons.',
      topic: 'Periodic Table',
    );

    setUp(() {
      mockRemoteDataSource = MockPastQuestionsRemoteDataSource();
      mockLocalDataSource = MockPastQuestionsLocalDataSource();

      when(() => mockLocalDataSource.initialize()).thenAnswer((_) async {});
      when(() => mockLocalDataSource.isInitialized).thenReturn(true);
      when(
        () => mockLocalDataSource.getPastQuestions(
          examCategory: any(named: 'examCategory'),
          subject: any(named: 'subject'),
          year: any(named: 'year'),
          searchQuery: any(named: 'searchQuery'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [testQuestionModel]);

      when(
        () => mockRemoteDataSource.getPastQuestions(
          examCategory: any(named: 'examCategory'),
          subject: any(named: 'subject'),
          year: any(named: 'year'),
          searchQuery: any(named: 'searchQuery'),
        ),
      ).thenAnswer((_) async => [testQuestionModel]);
    });

    test('Loads pre-persisted bookmarks on repository initialization',
        () async {
      await memoryStorage.savePreference(
        key: PrefKeys.pastQuestionBookmarks,
        data: jsonEncode(['q_chem_101']),
      );

      repository = PastQuestionsRepositoryImpl(
        mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
        localStorageService: memoryStorage,
      );

      final result = await repository.getPastQuestions();
      expect(result.isRight, isTrue);

      result.fold(
        (failure) => fail('Should succeed: $failure'),
        (questions) {
          expect(questions.first.id, equals('q_chem_101'));
          expect(questions.first.isBookmarked, isTrue);
        },
      );
    });

    test('Toggling bookmark persists updated bookmark list to disk', () async {
      repository = PastQuestionsRepositoryImpl(
        mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
        localStorageService: memoryStorage,
      );

      // Initially not bookmarked
      final initialResult = await repository.getPastQuestions();
      initialResult.fold(
        (failure) => fail('Should succeed'),
        (questions) => expect(questions.first.isBookmarked, isFalse),
      );

      // Bookmark question
      final toggleResult =
          await repository.toggleBookmarkQuestion('q_chem_101');
      expect(toggleResult.isRight, isTrue);

      // Verify stored in LocalStorageService
      final raw = memoryStorage.getPreference(
        key: PrefKeys.pastQuestionBookmarks,
      );
      expect(raw, isNotNull);
      final bookmarked = jsonDecode(raw!) as List<dynamic>;
      expect(bookmarked, contains('q_chem_101'));

      // Verify subsequent fetch reflects bookmarked state
      final bookmarkedFetch = await repository.getPastQuestions();
      bookmarkedFetch.fold(
        (failure) => fail('Should succeed'),
        (questions) => expect(questions.first.isBookmarked, isTrue),
      );

      // Toggle off
      await repository.toggleBookmarkQuestion('q_chem_101');
      final updatedRaw = memoryStorage.getPreference(
        key: PrefKeys.pastQuestionBookmarks,
      );
      final unbookmarked = jsonDecode(updatedRaw!) as List<dynamic>;
      expect(unbookmarked, isNot(contains('q_chem_101')));
    });
  });

  group('Batch 2 Fix 3: Cloned Marketplace Decks Local Persistence', () {
    late MockCommunityRemoteDataSource mockRemoteDataSource;
    late MockUserStorageService mockUserStorage;
    late CommunityRepositoryImpl communityRepo;

    setUp(() {
      mockRemoteDataSource = MockCommunityRemoteDataSource();
      mockUserStorage = MockUserStorageService();

      when(() => mockUserStorage.getUserId()).thenReturn('user_local_123');
      when(() => mockRemoteDataSource.cloneSharedDeck('shared_deck_abc'))
          .thenAnswer((_) async => {
                'new_deck_id': 'cloned_deck_new_123',
                'title': 'JAMB Physics 2024 Mechanics',
                'subject': 'Physics',
                'cloned_cards_count': 25,
              });

      communityRepo = CommunityRepositoryImpl(
        mockRemoteDataSource,
        userStorage: mockUserStorage,
      );
    });

    test('cloneSharedDeck writes cloned deck into PrefKeys.persistedUserDecks',
        () async {
      final cloneResult =
          await communityRepo.cloneSharedDeck('shared_deck_abc');
      expect(cloneResult.isRight, isTrue);

      cloneResult.fold(
        (failure) => fail('Clone should succeed: $failure'),
        (clonedDeck) {
          expect(clonedDeck.id, equals('cloned_deck_new_123'));
          expect(clonedDeck.title, equals('JAMB Physics 2024 Mechanics'));
          expect(clonedDeck.totalCards, equals(25));
        },
      );

      // Verify written to local storage
      final rawDecks = memoryStorage.getPreference(
        key: PrefKeys.persistedUserDecks,
      );
      expect(rawDecks, isNotNull);

      final list = jsonDecode(rawDecks!) as List<dynamic>;
      expect(list.isNotEmpty, isTrue);
      final firstDeck = list.first as Map<String, dynamic>;
      expect(firstDeck['id'], equals('cloned_deck_new_123'));
      expect(firstDeck['title'], equals('JAMB Physics 2024 Mechanics'));
      expect(firstDeck['subject'], equals('Physics'));
      expect(firstDeck['total_cards'], equals(25));
    });
  });

  group('Batch 2 Fix 4: Ebbinghaus Decay & Analytics Timeframe Filter', () {
    const decayCalculator = EbbinghausDecayCalculator();

    test('calculateProjection computes requested day count dynamically', () {
      final sevenDays = decayCalculator.calculateProjection(
        projectionDays: 7,
        cardStabilities: [4.5, 6.2, 5.0],
      );
      expect(sevenDays.length, equals(7));
      expect(sevenDays.first.day, equals(0));
      expect(sevenDays.last.day, equals(6));

      final fourteenDays = decayCalculator.calculateProjection(
        projectionDays: 14,
        cardStabilities: [5.5, 7.8, 6.2],
      );
      expect(fourteenDays.length, equals(14));
      expect(fourteenDays.first.day, equals(0));
      expect(fourteenDays.last.day, equals(13));

      final twentyEightDays = decayCalculator.calculateProjection(
        projectionDays: 28,
        cardStabilities: [7.0, 10.5, 8.2],
      );
      expect(twentyEightDays.length, equals(28));
      expect(twentyEightDays.first.day, equals(0));
      expect(twentyEightDays.last.day, equals(27));
    });

    test('Retention decays monotonically across multi-day projections', () {
      final points = decayCalculator.calculateProjection(
        projectionDays: 14,
        cardStabilities: [4.0, 4.0],
      );

      for (var i = 1; i < points.length; i++) {
        expect(
          points[i].predictedRetention,
          lessThanOrEqualTo(points[i - 1].predictedRetention),
        );
      }
    });

    test('AnalyticsSummaryEntity handles dynamic slices without error', () {
      final now = DateTime.now();
      final heatMap = List.generate(28, (i) {
        return HeatMapDayEntity(
          date: now.subtract(Duration(days: 27 - i)),
          intensityLevel: i % 4,
          cardsReviewed: i * 2,
          minutesStudied: i * 5,
        );
      });

      final summary = AnalyticsSummaryEntity(
        currentStreakDays: 5,
        longestStreakDays: 12,
        weeklyMinutesStudied: 180,
        overallRetentionRate: 0.88,
        totalCardsMastered: 45,
        heatMapData: heatMap,
        xpPoints: 1200,
        academicRank: 'Neural Scholar II',
      );

      // Week slice
      final weekSlice = heatMap.sublist(heatMap.length - 7);
      expect(weekSlice.length, equals(7));

      // 30-Day slice
      final monthSlice = heatMap.sublist(heatMap.length - 28);
      expect(monthSlice.length, equals(28));

      expect(summary.totalCardsMastered, equals(45));
    });
  });
}
