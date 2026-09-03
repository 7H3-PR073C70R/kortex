import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_state.dart';
import 'package:kortex/src/shared/audio/client/speech_to_text_client.dart';
import 'package:kortex/src/shared/audio/client/text_to_speech_client.dart';

class AudioWorkspaceCubit extends Cubit<AudioWorkspaceState> {
  AudioWorkspaceCubit({
    SpeechToTextClient? sttClient,
    TextToSpeechClient? ttsClient,
  }) : _stt = sttClient ?? SpeechToTextClient(),
       _tts = ttsClient ?? TextToSpeechClient(),
       super(const AudioWorkspaceState());

  final SpeechToTextClient _stt;
  final TextToSpeechClient _tts;

  /// Initiates live microphone listening and audio level streaming.
  Future<void> startVoiceRecording() async {
    emit(
      state.copyWith(
        recordingStatus: AudioRecordingStatus.listening,
        transcribedText: '',
        liveSoundLevel: 0.1,
      ),
    );

    final success = await _stt.startListening(
      onResult: (words) {
        emit(state.copyWith(transcribedText: words));
      },
      onSoundLevelChange: (level) {
        if (state.isRecording) {
          emit(state.copyWith(liveSoundLevel: level));
        }
      },
    );

    if (!success) {
      emit(
        state.copyWith(
          recordingStatus: AudioRecordingStatus.error,
          errorMessage:
              'Microphone permissions or speech recognition unavailable',
        ),
      );
    }
  }

  /// Manually updates transcribed text string.
  void updateTranscribedText(String text) {
    emit(state.copyWith(transcribedText: text));
  }

  /// Finalizes voice recording and marks status as transcribed.
  Future<String> stopVoiceRecording() async {
    await _stt.stopListening();
    final resultText = state.transcribedText;
    emit(
      state.copyWith(
        recordingStatus: AudioRecordingStatus.transcribed,
        liveSoundLevel: 0,
      ),
    );
    return resultText;
  }

  /// Cancels microphone recording.
  Future<void> cancelVoiceRecording() async {
    await _stt.cancelListening();
    emit(
      state.copyWith(
        recordingStatus: AudioRecordingStatus.idle,
        transcribedText: '',
        liveSoundLevel: 0,
      ),
    );
  }

  /// Speaks the given text using synthesized speech.
  Future<void> playText(String text) async {
    await _tts.stop();
    emit(
      state.copyWith(
        playbackStatus: AudioPlaybackStatus.playing,
        currentlyReadingText: text,
      ),
    );

    await _tts.speak(
      text,
      rate: state.playbackSpeed,
      onComplete: () {
        emit(
          state.copyWith(
            playbackStatus: AudioPlaybackStatus.idle,
            currentlyReadingText: '',
          ),
        );
      },
    );
  }

  /// Stops TTS speech output.
  Future<void> stopPlayback() async {
    await _tts.stop();
    emit(
      state.copyWith(
        playbackStatus: AudioPlaybackStatus.stopped,
        currentlyReadingText: '',
      ),
    );
  }

  /// Adjusts TTS speech rate ($0.75\times, 1.0\times, 1.25\times, 1.5\times$).
  void setPlaybackSpeed(double speed) {
    emit(state.copyWith(playbackSpeed: speed));
    if (state.isPlaying && state.currentlyReadingText.isNotEmpty) {
      unawaited(playText(state.currentlyReadingText));
    }
  }
}
