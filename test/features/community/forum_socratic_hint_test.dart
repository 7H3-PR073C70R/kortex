import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/services/forum_socratic_hint_service.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockStreamSyllabotResponseUseCase extends Mock
    implements StreamSyllabotResponseUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLocalStorageService mockStorage;
  late LocalLlmEngineClient localClient;
  late MockStreamSyllabotResponseUseCase mockStreamUseCase;

  setUpAll(() async {
    mockStorage = MockLocalStorageService();
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    locator.registerSingleton<LocalStorageService>(mockStorage);

    registerFallbackValue(SocraticMode.stepByStep);
    registerFallbackValue(ExecutionEngineType.cloudRemote);
  });

  setUp(() {
    localClient = LocalLlmEngineClient();
    mockStreamUseCase = MockStreamSyllabotResponseUseCase();
  });

  group('Syllabot Socratic Hint Generation Tests (Zero-Fallback Policy)', () {
    test('Local LLM hint generation requires downloaded model and throws LocalLlmNotDownloadedException otherwise', () async {
      when(() => mockStorage.getPreference(key: '__local_llm_model_downloaded'))
          .thenReturn(null);
      when(() => mockStorage.getPreference(key: '__local_llm_model_path'))
          .thenReturn(null);

      const prompt =
          'You are Syllabot. A student in track "WAEC - Sciences" (Physics) posted: '
          'Need help: A catapult is used to project a stone. Which of the parameters determines its range?';

      expect(
        localClient.generate(
          prompt: prompt,
          systemInstruction: 'Provide a high-yield Socratic hint.',
        ),
        emitsError(isA<LocalLlmNotDownloadedException>()),
      );
    });

    test('ForumSocraticHintService.buildPrompt builds clean prompt without self-referential template echo', () {
      final post = ForumPostEntity(
        id: 'post-1',
        authorId: 'user-1',
        authorName: 'Alex',
        title: 'Projectile Motion in WAEC Physics',
        content: 'How does launch angle impact range on level ground?',
        track: 'WAEC',
        syllabusTag: 'Physics',
        createdAt: DateTime.now(),
        tags: const ['physics', 'mechanics'],
      );

      final prompt = ForumSocraticHintService.buildPrompt(post);
      expect(prompt, contains('WAEC'));
      expect(prompt, contains('Physics'));
      expect(prompt, contains('Projectile Motion in WAEC Physics'));
      expect(prompt, contains('💡 **Core Subject Principle**'));
      expect(prompt, contains('🎯 **Socratic Checkpoint**'));
    });

    test('ForumSocraticHintService detects and rejects template echoes', () {
      const corruptedEcho =
          '🤖 Syllabot Socratic Hint:\n\n'
          'Core Subject Principle: Explain the specific biological, chemical, physical or mathematical concept/definition involved in direct engagement with a question.\n'
          'Concept Breakdown & Distinctions: Analyze key differences between the subject matter and student misconceptions, highlighting specific mechanisms or options mentioned by students to arrive at a correct answer.\n'
          'Socratic Checkpoint: A sharp guiding question that empowers the student into dedicating themselves fully and making informed decisions, thus providing a clear direction for their response.';

      expect(ForumSocraticHintService.isTemplateOrGenericEcho(corruptedEcho), isTrue);

      const validHint =
          '💡 **Core Subject Principle**: In projectile motion, range is governed by R = (u^2 * sin(2*theta))/g.\n'
          '🔍 **Concept Breakdown & Key Distinctions**: The horizontal velocity is constant while gravity accelerates vertically.\n'
          '🎯 **Socratic Checkpoint**: What happens when the launch angle is 45 degrees?';

      expect(ForumSocraticHintService.isTemplateOrGenericEcho(validHint), isFalse);
    });

    test('ForumSocraticHintService throws SyllabotHintGenerationException when no AI engine is provided', () async {
      final post = ForumPostEntity(
        id: 'post-physics',
        authorId: 'user-1',
        authorName: 'Student',
        title: 'A catapult is used to project a stone. Which parameter determines range?',
        content: 'Options are velocity, angle, mass',
        track: 'WAEC',
        syllabusTag: 'Physics',
        createdAt: DateTime.now(),
      );

      expect(
        () => ForumSocraticHintService.generateHint(post: post),
        throwsA(isA<SyllabotHintGenerationException>()),
      );
    });

    test('ForumSocraticHintService throws SyllabotHintGenerationException when AI stream yields empty or errors', () async {
      final post = ForumPostEntity(
        id: 'post-chem',
        authorId: 'user-1',
        authorName: 'Student',
        title: 'Calculating limiting reactant in stoichiometry reaction',
        content: 'How do I know which reactant runs out first?',
        track: 'JAMB',
        syllabusTag: 'Chemistry',
        createdAt: DateTime.now(),
      );

      when(
        () => mockStreamUseCase.call(
          prompt: any(named: 'prompt'),
          sessionId: any(named: 'sessionId'),
          socraticMode: any(named: 'socraticMode'),
          preferredEngine: any(named: 'preferredEngine'),
        ),
      ).thenAnswer((_) => Stream.error(Exception('Network timeout')));

      expect(
        () => ForumSocraticHintService.generateHint(
          post: post,
          streamUseCase: mockStreamUseCase,
        ),
        throwsA(isA<SyllabotHintGenerationException>()),
      );
    });

    test('ForumSocraticHintService successfully formats and returns authentic AI response from StreamSyllabotResponseUseCase', () async {
      final post = ForumPostEntity(
        id: 'post-success',
        authorId: 'user-1',
        authorName: 'Alex',
        title: 'Why is the sky blue?',
        content: 'I want to understand Rayleigh scattering.',
        track: 'WAEC',
        syllabusTag: 'Physics',
        createdAt: DateTime.now(),
      );

      const aiResponse =
          r'💡 **Core Subject Principle**: Rayleigh scattering explains that light scattering is inversely proportional to the fourth power of wavelength ($I \propto 1/\lambda^4$).' '\n\n'
          '🔍 **Concept Breakdown & Key Distinctions**: Shorter blue wavelengths scatter much more strongly than longer red wavelengths.\n\n'
          '🎯 **Socratic Checkpoint**: Why does the sun appear red at sunset when viewed through a thicker atmosphere?';

      when(
        () => mockStreamUseCase.call(
          prompt: any(named: 'prompt'),
          sessionId: any(named: 'sessionId'),
          socraticMode: any(named: 'socraticMode'),
          preferredEngine: any(named: 'preferredEngine'),
        ),
      ).thenAnswer((_) => Stream.value(aiResponse));

      final result = await ForumSocraticHintService.generateHint(
        post: post,
        streamUseCase: mockStreamUseCase,
      );

      expect(result, startsWith('🤖 Syllabot Socratic Hint:'));
      expect(result, contains('Rayleigh scattering'));
      expect(result, contains('Core Subject Principle'));
    });
  });
}
