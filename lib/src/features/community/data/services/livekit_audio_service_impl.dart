import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/community/domain/services/livekit_audio_service.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

/// Production LiveKit audio RTC implementation for peer voice study rooms.
class LiveKitAudioServiceImpl implements LiveKitAudioService {
  LiveKitAudioServiceImpl({lk.Room? room}) : _room = room;

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;

  bool _isMicEnabled = false;
  bool _isConnected = false;

  final _speakingParticipantsController =
      StreamController<Set<String>>.broadcast();
  final _micStateController = StreamController<bool>.broadcast();
  final _connectionStateController =
      StreamController<LiveAudioConnectionState>.broadcast();

  @override
  bool get isMicrophoneEnabled => _isMicEnabled;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<Set<String>> get speakingParticipantsStream =>
      _speakingParticipantsController.stream;

  @override
  Stream<bool> get microphoneStateStream => _micStateController.stream;

  @override
  Stream<LiveAudioConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomId,
    required String userId,
  }) async {
    if (_isConnected) {
      await disconnect();
    }

    _connectionStateController.add(LiveAudioConnectionState.connecting);

    if (url.isEmpty || token.isEmpty) {
      developer.log(
        'LiveKitAudioService: Cannot connect to room $roomId with empty URL or token',
        name: 'LiveKitAudio',
      );
      _isConnected = false;
      _connectionStateController.add(LiveAudioConnectionState.failed);
      return;
    }

    try {
      final room = _room ??
          lk.Room(
            roomOptions: const lk.RoomOptions(
              defaultAudioPublishOptions: lk.AudioPublishOptions(
                name: 'scholar_audio',
              ),
              adaptiveStream: true,
              dynacast: true,
            ),
          );
      _room = room;

      _listener = room.createListener();
      _setupRoomEventListeners(_listener!);

      await room.connect(url, token);

      _isConnected = true;
      _connectionStateController.add(LiveAudioConnectionState.connected);
      developer.log(
        'LiveKitAudioService: Connected to room $roomId successfully',
        name: 'LiveKitAudio',
      );
    } on Object catch (e, s) {
      developer.log(
        'LiveKitAudioService: Connection error: $e',
        error: e,
        stackTrace: s,
        name: 'LiveKitAudio',
      );
      _isConnected = false;
      _connectionStateController.add(LiveAudioConnectionState.failed);
    }
  }

  void _setupRoomEventListeners(lk.EventsListener<lk.RoomEvent> listener) {
    listener
      ..on<lk.ActiveSpeakersChangedEvent>((event) {
        final speakers = event.speakers
            .map((p) => p.identity)
            .where((id) => id.isNotEmpty)
            .toSet();
        _speakingParticipantsController.add(speakers);
      })
      ..on<lk.RoomDisconnectedEvent>((_) {
        _isConnected = false;
        _connectionStateController.add(LiveAudioConnectionState.disconnected);
        _speakingParticipantsController.add({});
      })
      ..on<lk.RoomReconnectingEvent>((_) {
        _connectionStateController.add(LiveAudioConnectionState.reconnecting);
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        _isConnected = true;
        _connectionStateController.add(LiveAudioConnectionState.connected);
      });
  }

  @override
  Future<bool> setMicrophoneEnabled({required bool enabled}) async {
    if (enabled) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (status != PermissionStatus.granted) {
        developer.log(
          'LiveKitAudioService: Microphone permission denied (status: $status)',
          name: 'LiveKitAudio',
        );
        _isMicEnabled = false;
        _micStateController.add(false);
        return false;
      }
    }

    _isMicEnabled = enabled;
    _micStateController.add(enabled);

    try {
      final local = _room?.localParticipant;
      if (local != null) {
        await local.setMicrophoneEnabled(enabled);
      }
      return true;
    } on Object catch (e) {
      developer.log('LiveKit setMicrophoneEnabled error: $e', name: 'LiveKitAudio');
      return false;
    }
  }

  @override
  Future<bool> isMicrophonePermissionPermanentlyDenied() async {
    try {
      final status = await Permission.microphone.status;
      return status.isPermanentlyDenied;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return true;
      status = await Permission.microphone.request();
      return status.isGranted;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _room?.disconnect();
      await _listener?.dispose();
    } on Object catch (_) {}

    _room = null;
    _listener = null;
    _isConnected = false;
    _isMicEnabled = false;

    _micStateController.add(false);
    _speakingParticipantsController.add({});
    _connectionStateController.add(LiveAudioConnectionState.disconnected);
  }

  @visibleForTesting
  void simulateSpeaker(String userId, {required bool isSpeaking}) {
    if (isSpeaking) {
      _speakingParticipantsController.add({userId});
    } else {
      _speakingParticipantsController.add({});
    }
  }
}
