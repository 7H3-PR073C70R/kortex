import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class MockSpeechToText extends Mock implements SpeechToText {}

class FakeSpeechListenOptions extends Fake implements SpeechListenOptions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSpeechToText mockSpeechToText;

  setUpAll(() {
    registerFallbackValue(FakeSpeechListenOptions());
  });

  setUp(() {
    mockSpeechToText = MockSpeechToText();
    when(() => mockSpeechToText.isListening).thenReturn(false);
  });

  group('SpeechToTextHandler', () {
    test('initializes successfully and reports isAvailable', () async {
      when(
        () => mockSpeechToText.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
          debugLogging: any<bool>(named: 'debugLogging'),
        ),
      ).thenAnswer((_) async => true);

      final handler = SpeechToTextHandler(
        speechToText: mockSpeechToText,
        onResult: (_) {},
        onListeningChanged: (_) {},
      );

      final available = await handler.initialize();
      expect(available, isTrue);
      expect(handler.isAvailable, isTrue);
    });

    test('concurrent initialize calls return same completed future', () async {
      final completer = Completer<bool>();
      when(
        () => mockSpeechToText.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
          debugLogging: any<bool>(named: 'debugLogging'),
        ),
      ).thenAnswer((_) => completer.future);

      final handler = SpeechToTextHandler(
        speechToText: mockSpeechToText,
        onResult: (_) {},
        onListeningChanged: (_) {},
      );

      final future1 = handler.initialize();
      final future2 = handler.initialize();

      completer.complete(true);

      final results = await Future.wait([future1, future2]);
      expect(results[0], isTrue);
      expect(results[1], isTrue);
      expect(handler.isAvailable, isTrue);
    });

    test('startListening triggers listen and notifies onListeningChanged',
        () async {
      when(
        () => mockSpeechToText.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
          debugLogging: any<bool>(named: 'debugLogging'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockSpeechToText.listen(
          onResult: any(named: 'onResult'),
          onSoundLevelChange: any(named: 'onSoundLevelChange'),
          listenOptions: any(named: 'listenOptions'),
        ),
      ).thenAnswer((_) async {});

      final listeningStates = <bool>[];
      final results = <String>[];

      final handler = SpeechToTextHandler(
        speechToText: mockSpeechToText,
        onResult: results.add,
        onListeningChanged: listeningStates.add,
      );

      await handler.startListening();

      expect(listeningStates, contains(true));
      verify(
        () => mockSpeechToText.listen(
          onResult: any(named: 'onResult'),
          onSoundLevelChange: any(named: 'onSoundLevelChange'),
          listenOptions: any(named: 'listenOptions'),
        ),
      ).called(1);
    });

    test('stopListening calls stop on SpeechToText and sets listening to false',
        () async {
      when(() => mockSpeechToText.stop()).thenAnswer((_) async {});

      final listeningStates = <bool>[];
      final handler = SpeechToTextHandler(
        speechToText: mockSpeechToText,
        onResult: (_) {},
        onListeningChanged: listeningStates.add,
      );

      await handler.stopListening();

      expect(listeningStates, [false]);
      verify(() => mockSpeechToText.stop()).called(1);
    });

    test('delivers recognized words to onResult and onResultWithFinal',
        () async {
      SpeechResultListener? capturedOnResult;

      when(
        () => mockSpeechToText.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
          debugLogging: any<bool>(named: 'debugLogging'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockSpeechToText.listen(
          onResult: any(named: 'onResult'),
          onSoundLevelChange: any(named: 'onSoundLevelChange'),
          listenOptions: any(named: 'listenOptions'),
        ),
      ).thenAnswer((invocation) async {
        capturedOnResult =
            invocation.namedArguments[#onResult] as SpeechResultListener?;
      });

      final results = <String>[];
      var finalResultCalled = false;

      final handler = SpeechToTextHandler(
        speechToText: mockSpeechToText,
        onResult: results.add,
        onResultWithFinal: (text, {required isFinal}) {
          if (isFinal) finalResultCalled = true;
        },
        onListeningChanged: (_) {},
      );

      await handler.startListening();

      expect(capturedOnResult, isNotNull);

      final fakeResult = SpeechRecognitionResult(
        [
          const SpeechRecognitionWords(
            'Explain quantum mechanics',
            null,
            0.95,
          ),
        ],
        ResultType.finalResult.value,
      );
      capturedOnResult!(fakeResult);

      expect(results, ['Explain quantum mechanics']);
      expect(finalResultCalled, isTrue);
    });
  });
}
