import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/shared/audio/client/speech_to_text_client.dart';

void main() {
  group('SpeechToTextClient Unit Test Suite', () {
    late SpeechToTextClient client;

    setUp(() {
      client = SpeechToTextClient();
    });

    test(
      'startListening sets isListening to true and streams decibels',
      () async {
        var receivedLevel = 0.0;
        final success = await client.startListening(
          onResult: (_) {},
          onSoundLevelChange: (level) {
            receivedLevel = level;
          },
        );

        expect(success, isTrue);
        expect(client.isListening, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(receivedLevel, greaterThan(0.0));

        await client.stopListening();
        expect(client.isListening, isFalse);
      },
    );

    test('cancelListening resets isListening', () async {
      await client.startListening(
        onResult: (_) {},
        onSoundLevelChange: (_) {},
      );
      expect(client.isListening, isTrue);

      await client.cancelListening();
      expect(client.isListening, isFalse);
    });
  });
}
