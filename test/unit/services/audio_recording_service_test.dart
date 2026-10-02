import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
    registerFallbackValue(Duration.zero);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        if (call.method == 'checkPermissionStatus') {
          return 0; // PermissionStatus.denied, falling back to recorder.hasPermission()
        }
        if (call.method == 'requestPermissions') {
          return {0: 1}; // microphone granted
        }
        return null;
      },
    );
  });

  group('AudioRecordingServiceImpl', () {
    late MockAudioRecorder mockRecorder;
    late AudioRecordingServiceImpl service;

    setUp(() {
      mockRecorder = MockAudioRecorder();
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      service = AudioRecordingServiceImpl(recorder: mockRecorder);
    });

    tearDown(() {
      service.dispose();
    });

    test('hasPermission returns true when recorder grants permission', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);

      final result = await service.hasPermission();

      expect(result, isTrue);
      verify(() => mockRecorder.hasPermission()).called(1);
    });

    test('isRecording delegates to AudioRecorder', () async {
      when(() => mockRecorder.isRecording()).thenAnswer((_) async => true);

      final result = await service.isRecording();

      expect(result, isTrue);
      verify(() => mockRecorder.isRecording()).called(1);
    });

    test('cancelRecording delegates to AudioRecorder.cancel()', () async {
      when(() => mockRecorder.cancel()).thenAnswer((_) async {});

      await service.cancelRecording();

      verify(() => mockRecorder.cancel()).called(1);
    });

    test('amplitudeStream normalizes dBFS into 0.0 - 1.0 range', () async {
      final ampController = StreamController<Amplitude>.broadcast();
      when(() => mockRecorder.onAmplitudeChanged(any()))
          .thenAnswer((_) => ampController.stream);
      when(() => mockRecorder.isRecording()).thenAnswer((_) async => false);
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});

      final recordedAmplitudes = <double>[];
      final sub = service.amplitudeStream.listen(recordedAmplitudes.add);

      await service.startRecording(customPath: '/tmp/test.m4a');

      // Emit -60 dB (silence) -> normalized 0.0
      ampController
        ..add(Amplitude(current: -60, max: -60))
        // Emit -30 dB (half) -> normalized 0.5
        ..add(Amplitude(current: -30, max: -30))
        // Emit 0 dB (max loudness) -> normalized 1.0
        ..add(Amplitude(current: 0, max: 0));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(recordedAmplitudes, [0.0, 0.5, 1.0]);

      await sub.cancel();
      await ampController.close();
    });
  });
}
