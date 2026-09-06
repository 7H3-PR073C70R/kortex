import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/data/services/livekit_audio_service_impl.dart';
import 'package:kortex/src/features/community/domain/services/livekit_audio_service.dart';

void main() {
  group('LiveKitAudioServiceImpl Unit Test Suite', () {
    late LiveKitAudioServiceImpl audioService;

    setUp(() {
      audioService = LiveKitAudioServiceImpl();
    });

    tearDown(() async {
      await audioService.disconnect();
    });

    test('connect fails immediately when url or token is empty', () async {
      final states = <LiveAudioConnectionState>[];
      final sub = audioService.connectionStateStream.listen(states.add);

      await audioService.connect(
        url: '',
        token: '',
        roomId: 'room-1',
        userId: 'user-1',
      );
      await Future<void>.delayed(Duration.zero);

      expect(audioService.isConnected, isFalse);
      expect(states, contains(LiveAudioConnectionState.failed));
      expect(states, isNot(contains(LiveAudioConnectionState.connected)));

      await sub.cancel();
    });

    test('disconnect updates connection state to disconnected', () async {
      final states = <LiveAudioConnectionState>[];
      final sub = audioService.connectionStateStream.listen(states.add);

      await audioService.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(audioService.isConnected, isFalse);
      expect(states, contains(LiveAudioConnectionState.disconnected));

      await sub.cancel();
    });
  });
}
