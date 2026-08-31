import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_cubit.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_state.dart';

void main() {
  group('AudioWorkspaceCubit Test Suite', () {
    late AudioWorkspaceCubit cubit;

    setUp(() {
      cubit = AudioWorkspaceCubit();
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial state has idle statuses and default speed 1.0', () {
      expect(cubit.state.recordingStatus, equals(AudioRecordingStatus.idle));
      expect(cubit.state.playbackStatus, equals(AudioPlaybackStatus.idle));
      expect(cubit.state.playbackSpeed, equals(1.0));
      expect(cubit.state.transcribedText, isEmpty);
    });

    blocTest<AudioWorkspaceCubit, AudioWorkspaceState>(
      'startVoiceRecording transitions status to listening',
      build: AudioWorkspaceCubit.new,
      act: (cubit) => cubit.startVoiceRecording(),
      expect: () => [
        const AudioWorkspaceState(
          recordingStatus: AudioRecordingStatus.listening,
          liveSoundLevel: 0.1,
        ),
      ],
    );

    blocTest<AudioWorkspaceCubit, AudioWorkspaceState>(
      'updateTranscribedText updates transcription string in state',
      build: AudioWorkspaceCubit.new,
      act: (cubit) => cubit.updateTranscribedText('What is photosynthesis?'),
      expect: () => [
        const AudioWorkspaceState(
          transcribedText: 'What is photosynthesis?',
        ),
      ],
    );

    blocTest<AudioWorkspaceCubit, AudioWorkspaceState>(
      'setPlaybackSpeed updates playbackSpeed in state',
      build: AudioWorkspaceCubit.new,
      act: (cubit) => cubit.setPlaybackSpeed(1.25),
      expect: () => [
        const AudioWorkspaceState(
          playbackSpeed: 1.25,
        ),
      ],
    );

    blocTest<AudioWorkspaceCubit, AudioWorkspaceState>(
      'playText starts playback and stopPlayback terminates it',
      build: AudioWorkspaceCubit.new,
      act: (cubit) async {
        await cubit.playText('Quantum mechanics explanation');
        await cubit.stopPlayback();
      },
      expect: () => [
        const AudioWorkspaceState(
          playbackStatus: AudioPlaybackStatus.playing,
          currentlyReadingText: 'Quantum mechanics explanation',
        ),
        const AudioWorkspaceState(
          playbackStatus: AudioPlaybackStatus.stopped,
        ),
      ],
    );
  });
}
