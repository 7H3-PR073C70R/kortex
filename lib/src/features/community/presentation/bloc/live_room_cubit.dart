import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/community/domain/services/livekit_audio_service.dart';

enum RoomViewMode { stage, whiteboard }

class LiveRoomState extends Equatable {
  const LiveRoomState({
    required this.room,
    this.remainingSeconds = 1500,
    this.isConnected = true,
    this.isAudioConnected = false,
    this.participants = const [],
    this.ephemeralParticipants = const [],
    this.activeSpeakerIds = const {},
    this.isHandRaised = false,
    this.isMuted = true,
    this.completedPomodoros = 0,
    this.activeViewMode = RoomViewMode.stage,
    this.activeGoal,
    this.ambientSoundTrack = 'lofi',
    this.isAmbientAudioPlaying = true,
    this.ambientAudioVolume = 0.5,
    this.isVoicePodEnabled = false,
    this.whiteboardStrokes = const [],
    this.whiteboardRedoStack = const [],
    this.chatMessages = const [],
    this.unreadChatCount = 0,
  });

  final StudyRoomEntity room;
  final int remainingSeconds;
  final bool isConnected;
  final bool isAudioConnected;
  final List<String> participants;
  final List<EphemeralParticipant> ephemeralParticipants;
  final Set<String> activeSpeakerIds;
  final bool isHandRaised;
  final bool isMuted;
  final int completedPomodoros;
  final RoomViewMode activeViewMode;
  final String? activeGoal;
  final String ambientSoundTrack;
  final bool isAmbientAudioPlaying;
  final double ambientAudioVolume;
  final bool isVoicePodEnabled;
  final List<WhiteboardStroke> whiteboardStrokes;
  final List<WhiteboardStroke> whiteboardRedoStack;
  final List<RoomChatMessage> chatMessages;
  final int unreadChatCount;

  String get formattedTimer {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get progress {
    final total = room.pomodoroDurationMinutes * 60;
    if (total == 0) return 1;
    return (total - remainingSeconds).clamp(0, total) / total;
  }

  LiveRoomState copyWith({
    StudyRoomEntity? room,
    int? remainingSeconds,
    bool? isConnected,
    bool? isAudioConnected,
    List<String>? participants,
    List<EphemeralParticipant>? ephemeralParticipants,
    Set<String>? activeSpeakerIds,
    bool? isHandRaised,
    bool? isMuted,
    int? completedPomodoros,
    RoomViewMode? activeViewMode,
    String? activeGoal,
    String? ambientSoundTrack,
    bool? isAmbientAudioPlaying,
    double? ambientAudioVolume,
    bool? isVoicePodEnabled,
    List<WhiteboardStroke>? whiteboardStrokes,
    List<WhiteboardStroke>? whiteboardRedoStack,
    List<RoomChatMessage>? chatMessages,
    int? unreadChatCount,
  }) {
    return LiveRoomState(
      room: room ?? this.room,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isConnected: isConnected ?? this.isConnected,
      isAudioConnected: isAudioConnected ?? this.isAudioConnected,
      participants: participants ?? this.participants,
      ephemeralParticipants:
          ephemeralParticipants ?? this.ephemeralParticipants,
      activeSpeakerIds: activeSpeakerIds ?? this.activeSpeakerIds,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isMuted: isMuted ?? this.isMuted,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      activeViewMode: activeViewMode ?? this.activeViewMode,
      activeGoal: activeGoal ?? this.activeGoal,
      ambientSoundTrack: ambientSoundTrack ?? this.ambientSoundTrack,
      isAmbientAudioPlaying:
          isAmbientAudioPlaying ?? this.isAmbientAudioPlaying,
      ambientAudioVolume: ambientAudioVolume ?? this.ambientAudioVolume,
      isVoicePodEnabled: isVoicePodEnabled ?? this.isVoicePodEnabled,
      whiteboardStrokes: whiteboardStrokes ?? this.whiteboardStrokes,
      whiteboardRedoStack: whiteboardRedoStack ?? this.whiteboardRedoStack,
      chatMessages: chatMessages ?? this.chatMessages,
      unreadChatCount: unreadChatCount ?? this.unreadChatCount,
    );
  }

  @override
  List<Object?> get props => [
    room,
    remainingSeconds,
    isConnected,
    isAudioConnected,
    participants,
    ephemeralParticipants,
    activeSpeakerIds,
    isHandRaised,
    isMuted,
    completedPomodoros,
    activeViewMode,
    activeGoal,
    ambientSoundTrack,
    isAmbientAudioPlaying,
    ambientAudioVolume,
    isVoicePodEnabled,
    whiteboardStrokes,
    whiteboardRedoStack,
    chatMessages,
    unreadChatCount,
  ];
}

class LiveRoomCubit extends Cubit<LiveRoomState> {
  LiveRoomCubit({
    required StudyRoomEntity initialRoom,
    required CommunityRepository repository,
    EphemeralRoomRepository? ephemeralRepository,
    LiveKitAudioService? audioService,
    String? currentUserId,
    String? currentUserName,
    String? currentUserAvatar,
  }) : _repository = repository,
       _ephemeralRepository = ephemeralRepository,
       _audioService = audioService ??
           (locator.isRegistered<LiveKitAudioService>()
               ? locator<LiveKitAudioService>()
               : null),
       _currentUserId = currentUserId ?? 'user_local',
       _currentUserName = currentUserName ?? 'Scholar',
       _currentUserAvatar = currentUserAvatar ?? '',
       super(
         LiveRoomState(
           room: initialRoom,
           remainingSeconds: initialRoom.pomodoroDurationMinutes * 60,
           participants: [currentUserName ?? 'You'],
         ),
       ) {
    _startTimer();
    _subscribeToRoom(initialRoom.id);
    _initEphemeralPresence(initialRoom.id);
    _initAudioRtc(initialRoom.id);
  }

  final CommunityRepository _repository;
  final EphemeralRoomRepository? _ephemeralRepository;
  final LiveKitAudioService? _audioService;
  final String _currentUserId;
  final String _currentUserName;
  final String _currentUserAvatar;

  Timer? _timer;
  StreamSubscription<StudyRoomEntity>? _roomSubscription;
  StreamSubscription<List<EphemeralParticipant>>? _presenceSubscription;
  StreamSubscription<PomodoroSyncEvent>? _syncSubscription;
  StreamSubscription<WhiteboardStroke>? _whiteboardSubscription;
  StreamSubscription<void>? _whiteboardClearSubscription;
  StreamSubscription<RoomChatMessage>? _chatSubscription;
  StreamSubscription<Set<String>>? _speakersSubscription;
  StreamSubscription<bool>? _micSubscription;
  StreamSubscription<LiveAudioConnectionState>? _audioConnSubscription;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds > 0) {
        final newRemaining = state.remainingSeconds - 1;
        emit(state.copyWith(remainingSeconds: newRemaining));

        // Periodic broadcast sync tick every 10 seconds (zero DB writes)
        if (newRemaining % 10 == 0 && _ephemeralRepository != null) {
          unawaited(
            _ephemeralRepository.broadcastPomodoroTick(
              roomId: state.room.id,
              remainingSeconds: newRemaining,
              pomodoroState: state.room.pomodoroState,
              senderId: _currentUserId,
            ),
          );
        }
      } else {
        unawaited(_handlePomodoroCompleted());
      }
    });
  }

  Future<void> _handlePomodoroCompleted() async {
    final nextState = state.room.isFocusing ? 'break' : 'focusing';
    final nextDuration = nextState == 'break'
        ? 5
        : state.room.pomodoroDurationMinutes;

    // Database Persistence Handshake: Record session upon block completion
    if (state.room.isFocusing && _ephemeralRepository != null) {
      await _ephemeralRepository.recordCompletedPomodoroSession(
        userId: _currentUserId,
        roomId: state.room.id,
        durationMinutes: state.room.pomodoroDurationMinutes,
        subject: state.room.subject,
      );
    }

    emit(
      state.copyWith(
        room: state.room.copyWith(pomodoroState: nextState),
        remainingSeconds: nextDuration * 60,
        completedPomodoros: state.room.isFocusing
            ? state.completedPomodoros + 1
            : state.completedPomodoros,
      ),
    );
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription = _repository.watchStudyRoom(roomId).listen(
      (updatedRoom) {
        if (!isClosed) {
          emit(state.copyWith(room: updatedRoom));
        }
      },
    );
  }

  void _initAudioRtc(String roomId) {
    final audio = _audioService;
    if (audio == null) return;

    _speakersSubscription = audio.speakingParticipantsStream.listen((speakers) {
      if (!isClosed) {
        emit(state.copyWith(activeSpeakerIds: speakers));
      }
    });

    _micSubscription = audio.microphoneStateStream.listen((enabled) {
      if (!isClosed) {
        final isMuted = !enabled;
        final updatedList = state.ephemeralParticipants.map((p) {
          if (p.userId == _currentUserId) {
            return p.copyWith(isMuted: isMuted);
          }
          return p;
        }).toList();

        emit(state.copyWith(
          isMuted: isMuted,
          ephemeralParticipants: updatedList,
        ));

        // If the hardware mic reverted to muted (e.g. permission denied), broadcast
        if (isMuted && _ephemeralRepository != null) {
          unawaited(
            _ephemeralRepository.broadcastMuteState(
              roomId: state.room.id,
              userId: _currentUserId,
              isMuted: true,
            ),
          );
        }
      }
    });

    _audioConnSubscription = audio.connectionStateStream.listen((connState) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isAudioConnected: connState == LiveAudioConnectionState.connected,
          ),
        );
      }
    });

    unawaited(
      () async {
        final tokenResult = await _repository.getLiveKitToken(
          roomId: roomId,
          userId: _currentUserId,
        );

        tokenResult.fold(
          (failure) {
            if (!isClosed) {
              emit(state.copyWith(isAudioConnected: false));
            }
          },
          (token) {
            if (token.isNotEmpty) {
              unawaited(
                audio.connect(
                  url: AppEnv.liveKitUrl,
                  token: token,
                  roomId: roomId,
                  userId: _currentUserId,
                ),
              );
            } else if (!isClosed) {
              emit(state.copyWith(isAudioConnected: false));
            }
          },
        );
      }(),
    );
  }

  void _initEphemeralPresence(String roomId) {
    final ephemeral = _ephemeralRepository;
    if (ephemeral == null) return;

    unawaited(
      ephemeral.joinRoomPresence(
        roomId: roomId,
        userId: _currentUserId,
        displayName: _currentUserName,
        avatarUrl: _currentUserAvatar,
      ),
    );

    _presenceSubscription = ephemeral
        .watchParticipants(roomId)
        .listen((participants) {
          if (!isClosed) {
            final names = participants.map((p) => p.displayName).toList();
            emit(
              state.copyWith(
                ephemeralParticipants: participants,
                participants: names.isNotEmpty ? names : state.participants,
              ),
            );
          }
        });

    _syncSubscription = ephemeral.watchPomodoroSync(roomId).listen((
      syncEvent,
    ) {
      if (!isClosed && syncEvent.senderId != _currentUserId) {
        // Correct clock drift if difference > 3 seconds
        if ((state.remainingSeconds - syncEvent.remainingSeconds).abs() > 3) {
          emit(
            state.copyWith(
              remainingSeconds: syncEvent.remainingSeconds,
              room: state.room.copyWith(pomodoroState: syncEvent.pomodoroState),
            ),
          );
        }
      }
    });

    _whiteboardSubscription = ephemeral.watchWhiteboardStrokes(roomId).listen((
      stroke,
    ) {
      if (!isClosed && stroke.userId != _currentUserId) {
        if (!state.whiteboardStrokes.any((s) => s.id == stroke.id)) {
          emit(
            state.copyWith(
              whiteboardStrokes: [...state.whiteboardStrokes, stroke],
            ),
          );
        }
      }
    });

    _whiteboardClearSubscription = ephemeral.watchWhiteboardClear(roomId).listen(
      (_) {
        if (!isClosed) {
          emit(state.copyWith(
            whiteboardStrokes: const [],
            whiteboardRedoStack: const [],
          ));
        }
      },
    );

    _chatSubscription = ephemeral.watchChatMessages(roomId).listen((
      chatMsg,
    ) {
      if (!isClosed && chatMsg.senderId != _currentUserId) {
        emit(
          state.copyWith(
            chatMessages: [...state.chatMessages, chatMsg],
            unreadChatCount: state.unreadChatCount + 1,
          ),
        );
      }
    });
  }

  void updateActiveGoal(String goal) {
    emit(state.copyWith(activeGoal: goal));
  }

  void setAmbientSoundTrack(String track) {
    emit(state.copyWith(ambientSoundTrack: track));
  }

  void toggleAmbientAudio() {
    emit(state.copyWith(isAmbientAudioPlaying: !state.isAmbientAudioPlaying));
  }

  void setAmbientVolume(double volume) {
    emit(state.copyWith(ambientAudioVolume: volume.clamp(0.0, 1.0)));
  }

  void toggleVoicePod() {
    emit(state.copyWith(isVoicePodEnabled: !state.isVoicePodEnabled));
  }

  void toggleHandRaise() {
    final nextState = !state.isHandRaised;
    final updatedList = state.ephemeralParticipants.map((p) {
      if (p.userId == _currentUserId) {
        return p.copyWith(isHandRaised: nextState);
      }
      return p;
    }).toList();
    if (!updatedList.any((p) => p.userId == _currentUserId)) {
      updatedList.add(
        EphemeralParticipant(
          userId: _currentUserId,
          displayName: _currentUserName,
          avatarUrl: _currentUserAvatar,
          isHandRaised: nextState,
          isMuted: state.isMuted,
        ),
      );
    }
    emit(state.copyWith(
      isHandRaised: nextState,
      ephemeralParticipants: updatedList,
    ));

    final repo = _ephemeralRepository;
    if (repo != null) {
      unawaited(
        repo.broadcastHandRaise(
          roomId: state.room.id,
          userId: _currentUserId,
          isHandRaised: nextState,
        ),
      );
    }
  }

  void toggleMicMute() {
    final nextMuted = !state.isMuted;
    final updatedList = state.ephemeralParticipants.map((p) {
      if (p.userId == _currentUserId) {
        return p.copyWith(isMuted: nextMuted);
      }
      return p;
    }).toList();
    if (!updatedList.any((p) => p.userId == _currentUserId)) {
      updatedList.add(
        EphemeralParticipant(
          userId: _currentUserId,
          displayName: _currentUserName,
          avatarUrl: _currentUserAvatar,
          isHandRaised: state.isHandRaised,
          isMuted: nextMuted,
        ),
      );
    }
    emit(state.copyWith(
      isMuted: nextMuted,
      ephemeralParticipants: updatedList,
    ));

    // Update LiveKit hardware microphone track publishing
    if (_audioService != null) {
      unawaited(_audioService.setMicrophoneEnabled(enabled: !nextMuted));
    }

    final repo = _ephemeralRepository;
    if (repo != null) {
      unawaited(
        repo.broadcastMuteState(
          roomId: state.room.id,
          userId: _currentUserId,
          isMuted: nextMuted,
        ),
      );
    }
  }

  void addWhiteboardStroke(WhiteboardStroke stroke) {
    final updated = List<WhiteboardStroke>.from(state.whiteboardStrokes)
      ..add(stroke);
    emit(state.copyWith(
      whiteboardStrokes: updated,
      whiteboardRedoStack: const [],
    ));
    unawaited(
      _ephemeralRepository?.broadcastWhiteboardStroke(
        roomId: state.room.id,
        stroke: stroke,
      ),
    );
  }

  void clearWhiteboard() {
    emit(state.copyWith(
      whiteboardStrokes: const [],
      whiteboardRedoStack: const [],
    ));
    unawaited(
      _ephemeralRepository?.broadcastWhiteboardClear(roomId: state.room.id),
    );
  }

  void undoWhiteboardStroke() {
    if (state.whiteboardStrokes.isEmpty) return;
    final updated = List<WhiteboardStroke>.from(state.whiteboardStrokes);
    final lastIndex = updated.lastIndexWhere((s) => s.userId == _currentUserId);
    if (lastIndex != -1) {
      final removed = updated.removeAt(lastIndex);
      final updatedRedo = List<WhiteboardStroke>.from(state.whiteboardRedoStack)
        ..add(removed);
      emit(state.copyWith(
        whiteboardStrokes: updated,
        whiteboardRedoStack: updatedRedo,
      ));
    }
  }

  void redoWhiteboardStroke() {
    if (state.whiteboardRedoStack.isEmpty) return;
    final updatedRedo = List<WhiteboardStroke>.from(state.whiteboardRedoStack);
    final strokeToRestore = updatedRedo.removeLast();
    final updatedStrokes = List<WhiteboardStroke>.from(state.whiteboardStrokes)
      ..add(strokeToRestore);
    emit(state.copyWith(
      whiteboardStrokes: updatedStrokes,
      whiteboardRedoStack: updatedRedo,
    ));
    unawaited(
      _ephemeralRepository?.broadcastWhiteboardStroke(
        roomId: state.room.id,
        stroke: strokeToRestore,
      ),
    );
  }

  void sendChatMessage(String text, {bool isReaction = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final msg = RoomChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId.hashCode}',
      senderId: _currentUserId,
      senderName: _currentUserName,
      senderAvatar: _currentUserAvatar,
      text: trimmed,
      timestamp: DateTime.now(),
      isReaction: isReaction,
    );
    final updated = List<RoomChatMessage>.from(state.chatMessages)..add(msg);
    emit(state.copyWith(chatMessages: updated));
    unawaited(
      _ephemeralRepository?.broadcastChatMessage(
        roomId: state.room.id,
        message: msg,
      ),
    );
  }

  void setRoomViewMode(RoomViewMode mode) {
    emit(state.copyWith(activeViewMode: mode));
  }

  void switchViewMode(RoomViewMode mode) => setRoomViewMode(mode);

  void markChatAsRead() {
    emit(state.copyWith(unreadChatCount: 0));
  }

  void toggleTimerPause() {
    if (state.room.isPaused) {
      emit(
        state.copyWith(
          room: state.room.copyWith(pomodoroState: 'focusing'),
        ),
      );
      _startTimer();
    } else {
      _timer?.cancel();
      emit(
        state.copyWith(
          room: state.room.copyWith(pomodoroState: 'paused'),
        ),
      );
    }

    final repo = _ephemeralRepository;
    if (repo != null) {
      unawaited(
        repo.broadcastPomodoroTick(
          roomId: state.room.id,
          remainingSeconds: state.remainingSeconds,
          pomodoroState: state.room.pomodoroState,
          senderId: _currentUserId,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _roomSubscription?.cancel();
    await _presenceSubscription?.cancel();
    await _syncSubscription?.cancel();
    await _whiteboardSubscription?.cancel();
    await _whiteboardClearSubscription?.cancel();
    await _chatSubscription?.cancel();
    await _speakersSubscription?.cancel();
    await _micSubscription?.cancel();
    await _audioConnSubscription?.cancel();
    await _audioService?.disconnect();
    await _ephemeralRepository?.leaveRoomPresence(state.room.id);
    return super.close();
  }
}
