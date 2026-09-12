import 'dart:async';

/// Connection state for LiveKit peer audio transport
enum LiveAudioConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Abstract contract for LiveKit peer-to-peer real-time audio transport
abstract class LiveKitAudioService {
  /// Connects to a LiveKit room via WebRTC audio pipeline
  Future<void> connect({
    required String url,
    required String token,
    required String roomId,
    required String userId,
  });

  /// Disconnects from the current room and releases audio tracks
  Future<void> disconnect();

  /// Toggles microphone audio track publishing. Returns true if successful.
  Future<bool> setMicrophoneEnabled({required bool enabled});

  /// Checks if microphone permission has been permanently denied by the user.
  Future<bool> isMicrophonePermissionPermanentlyDenied() async => false;

  /// Prompts the system microphone permission dialog.
  Future<bool> requestMicrophonePermission() async => false;

  /// Opens the device app settings screen for granting permissions.
  Future<bool> openAppSettings() async => false;

  /// Whether local microphone is currently unmuted
  bool get isMicrophoneEnabled;

  /// Whether WebRTC peer connection to room is active
  bool get isConnected;

  /// Stream of active speaker participant IDs (drives pulsating glowing avatars)
  Stream<Set<String>> get speakingParticipantsStream;

  /// Stream of local microphone muted/unmuted state
  Stream<bool> get microphoneStateStream;

  /// Toggles low-data mode (Opus 16kbps mono constraint to reduce cellular usage).
  Future<void> setLowDataMode({required bool enabled}) async {}

  /// Whether low-data mode is active
  bool get isLowDataMode => false;

  /// Stream of WebRTC connection status updates
  Stream<LiveAudioConnectionState> get connectionStateStream;
}
