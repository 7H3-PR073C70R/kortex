import 'package:equatable/equatable.dart';

enum AudioRecordingStatus {
  idle,
  listening,
  transcribed,
  error,
}

enum AudioPlaybackStatus {
  idle,
  playing,
  paused,
  stopped,
}

class AudioWorkspaceState extends Equatable {
  const AudioWorkspaceState({
    this.recordingStatus = AudioRecordingStatus.idle,
    this.playbackStatus = AudioPlaybackStatus.idle,
    this.transcribedText = '',
    this.liveSoundLevel = 0.0,
    this.currentlyReadingText = '',
    this.playbackSpeed = 1.0,
    this.errorMessage,
  });

  final AudioRecordingStatus recordingStatus;
  final AudioPlaybackStatus playbackStatus;
  final String transcribedText;
  final double liveSoundLevel; // 0.0 to 1.0
  final String currentlyReadingText;
  final double playbackSpeed; // 0.75, 1.0, 1.25, 1.5
  final String? errorMessage;

  bool get isRecording => recordingStatus == AudioRecordingStatus.listening;
  bool get isPlaying => playbackStatus == AudioPlaybackStatus.playing;

  AudioWorkspaceState copyWith({
    AudioRecordingStatus? recordingStatus,
    AudioPlaybackStatus? playbackStatus,
    String? transcribedText,
    double? liveSoundLevel,
    String? currentlyReadingText,
    double? playbackSpeed,
    String? errorMessage,
  }) {
    return AudioWorkspaceState(
      recordingStatus: recordingStatus ?? this.recordingStatus,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      transcribedText: transcribedText ?? this.transcribedText,
      liveSoundLevel: liveSoundLevel ?? this.liveSoundLevel,
      currentlyReadingText: currentlyReadingText ?? this.currentlyReadingText,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    recordingStatus,
    playbackStatus,
    transcribedText,
    liveSoundLevel,
    currentlyReadingText,
    playbackSpeed,
    errorMessage,
  ];
}
