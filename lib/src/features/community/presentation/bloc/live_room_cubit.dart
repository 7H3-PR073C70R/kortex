import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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
    this.cardsReviewedInSprint = 0,
    this.recentActivityTicker = const [],
    this.lastReactionEmoji,
    this.isCoOpSprintActive = false,
    this.coOpSprintDeckTitle,
    this.coOpSprintTargetCards = 10,
    this.coOpSprintRemainingSeconds = 180,
    this.coOpSprintCompletedParticipants = const {},
    this.isSyllabotBuddyActive = false,
    this.isLocalUserAway = false,
    this.isGoalAchieved = false,
    this.showGoalVerificationModal = false,
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
  final int cardsReviewedInSprint;
  final List<String> recentActivityTicker;
  final String? lastReactionEmoji;
  final bool isCoOpSprintActive;
  final String? coOpSprintDeckTitle;
  final int coOpSprintTargetCards;
  final int coOpSprintRemainingSeconds;
  final Map<String, int> coOpSprintCompletedParticipants;
  final bool isSyllabotBuddyActive;
  final bool isLocalUserAway;
  final bool isGoalAchieved;
  final bool showGoalVerificationModal;

  String get formattedTimer {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedSprintTimer {
    final minutes = (coOpSprintRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (coOpSprintRemainingSeconds % 60).toString().padLeft(2, '0');
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
    int? cardsReviewedInSprint,
    List<String>? recentActivityTicker,
    String? lastReactionEmoji,
    bool? isCoOpSprintActive,
    String? coOpSprintDeckTitle,
    int? coOpSprintTargetCards,
    int? coOpSprintRemainingSeconds,
    Map<String, int>? coOpSprintCompletedParticipants,
    bool? isSyllabotBuddyActive,
    bool? isLocalUserAway,
    bool? isGoalAchieved,
    bool? showGoalVerificationModal,
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
      cardsReviewedInSprint:
          cardsReviewedInSprint ?? this.cardsReviewedInSprint,
      recentActivityTicker:
          recentActivityTicker ?? this.recentActivityTicker,
      lastReactionEmoji: lastReactionEmoji ?? this.lastReactionEmoji,
      isCoOpSprintActive: isCoOpSprintActive ?? this.isCoOpSprintActive,
      coOpSprintDeckTitle: coOpSprintDeckTitle ?? this.coOpSprintDeckTitle,
      coOpSprintTargetCards:
          coOpSprintTargetCards ?? this.coOpSprintTargetCards,
      coOpSprintRemainingSeconds:
          coOpSprintRemainingSeconds ?? this.coOpSprintRemainingSeconds,
      coOpSprintCompletedParticipants:
          coOpSprintCompletedParticipants ??
          this.coOpSprintCompletedParticipants,
      isSyllabotBuddyActive:
          isSyllabotBuddyActive ?? this.isSyllabotBuddyActive,
      isLocalUserAway: isLocalUserAway ?? this.isLocalUserAway,
      isGoalAchieved: isGoalAchieved ?? this.isGoalAchieved,
      showGoalVerificationModal:
          showGoalVerificationModal ?? this.showGoalVerificationModal,
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
    cardsReviewedInSprint,
    recentActivityTicker,
    lastReactionEmoji,
    isCoOpSprintActive,
    coOpSprintDeckTitle,
    coOpSprintTargetCards,
    coOpSprintRemainingSeconds,
    coOpSprintCompletedParticipants,
    isSyllabotBuddyActive,
    isLocalUserAway,
    isGoalAchieved,
    showGoalVerificationModal,
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
    unawaited(_initAmbientAudio());
    _startSyllabotBuddyCheck();
  }

  final CommunityRepository _repository;
  final EphemeralRoomRepository? _ephemeralRepository;
  final LiveKitAudioService? _audioService;
  final String _currentUserId;
  final String _currentUserName;
  final String _currentUserAvatar;
  final AudioPlayer _ambientPlayer = AudioPlayer();

  // Bundled local audio assets (assets/audio/) — avoids CDN 403 failures on iOS/macOS.
  // All four tracks are 10-second seamless loops at 22050 Hz stereo WAV.
  static const Map<String, String> _trackAssets = {
    'Lo-Fi Beats': 'audio/lofi.wav',
    'Gentle Rain': 'audio/rain.wav',
    'Binaural 40Hz': 'audio/binaural.wav',
    'Library Silence': 'audio/silence.wav',
    // Legacy / short-key aliases used by older state and the creation sheet
    'lofi': 'audio/lofi.wav',
    'rain': 'audio/rain.wav',
    'binaural': 'audio/binaural.wav',
    'silence': 'audio/silence.wav',
    'library': 'audio/silence.wav', // alias used by CreateStudyRoomSheet
  };

  Timer? _timer;
  Timer? _sprintTimer;
  Timer? _buddyTimer;
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

    final hasGoal = state.activeGoal != null && state.activeGoal!.trim().isNotEmpty;
    emit(
      state.copyWith(
        room: state.room.copyWith(pomodoroState: nextState),
        remainingSeconds: nextDuration * 60,
        completedPomodoros: state.room.isFocusing
            ? state.completedPomodoros + 1
            : state.completedPomodoros,
        showGoalVerificationModal: hasGoal && state.room.isFocusing,
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
        activeGoal: state.activeGoal,
      ),
    );

    _presenceSubscription = ephemeral
        .watchParticipants(roomId)
        .listen((participants) {
          if (!isClosed) {
            var updated = List<EphemeralParticipant>.from(participants);
            final otherHumans = updated.where(
              (p) => p.userId != _currentUserId && !p.isAiBuddy,
            );

            if (state.isSyllabotBuddyActive && otherHumans.isEmpty) {
              if (!updated.any((p) => p.isAiBuddy)) {
                updated.add(
                  EphemeralParticipant(
                    userId: 'syllabot_buddy_${state.room.id}',
                    displayName: 'Syllabot AI (Study Buddy)',
                    avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=syllabot',
                    isAiBuddy: true,
                    joinedAt: DateTime.now(),
                  ),
                );
              }
            } else if (otherHumans.isNotEmpty && state.isSyllabotBuddyActive) {
              updated = updated.where((p) => !p.isAiBuddy).toList();
            }

            final names = updated.map((p) => p.displayName).toList();
            emit(
              state.copyWith(
                ephemeralParticipants: updated,
                participants: names.isNotEmpty ? names : state.participants,
                isSyllabotBuddyActive: otherHumans.isEmpty && state.isSyllabotBuddyActive,
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
        final tickerMsg = '${chatMsg.senderName}: ${chatMsg.text}';
        final updatedTicker = [tickerMsg, ...state.recentActivityTicker.take(4)];
        emit(
          state.copyWith(
            chatMessages: [...state.chatMessages, chatMsg],
            unreadChatCount: state.unreadChatCount + 1,
            recentActivityTicker: updatedTicker,
            lastReactionEmoji: chatMsg.isReaction ? chatMsg.text : state.lastReactionEmoji,
          ),
        );
      }
    });
  }

  void logCardReviewed([int count = 1]) {
    final updatedCount = state.cardsReviewedInSprint + count;
    final message = '🎯 You completed $updatedCount flashcards in this sprint!';
    final updatedTicker = [message, ...state.recentActivityTicker.take(4)];
    emit(state.copyWith(
      cardsReviewedInSprint: updatedCount,
      recentActivityTicker: updatedTicker,
    ));
    sendChatMessage(
      'Reviewed $updatedCount cards in this sprint 🔥',
      isReaction: true,
    );
  }

  void startCoOpSprint({
    String deckTitle = '3-Min Focus Sprint',
    int targetCards = 10,
  }) {
    _sprintTimer?.cancel();
    final message = '⚡ Co-Op Sprint Started: $deckTitle ($targetCards Cards)';
    final updatedTicker = [message, ...state.recentActivityTicker.take(4)];
    emit(state.copyWith(
      isCoOpSprintActive: true,
      coOpSprintDeckTitle: deckTitle,
      coOpSprintTargetCards: targetCards,
      coOpSprintRemainingSeconds: 180,
      recentActivityTicker: updatedTicker,
    ));
    sendChatMessage(
      '⚡ Launched Co-Op Sprint: $deckTitle ($targetCards cards) - Let’s focus together!',
      isReaction: true,
    );

    _sprintTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      if (state.coOpSprintRemainingSeconds <= 1) {
        timer.cancel();
        endCoOpSprint();
      } else {
        emit(
          state.copyWith(
            coOpSprintRemainingSeconds: state.coOpSprintRemainingSeconds - 1,
          ),
        );
      }
    });
  }

  void completeCoOpSprintRound(int cardsCompleted) {
    final updatedMap = Map<String, int>.from(state.coOpSprintCompletedParticipants);
    updatedMap[_currentUserName] = cardsCompleted;
    final message = '🏆 Sprint finished! You completed $cardsCompleted cards!';
    final updatedTicker = [message, ...state.recentActivityTicker.take(4)];
    emit(state.copyWith(
      coOpSprintCompletedParticipants: updatedMap,
      cardsReviewedInSprint: state.cardsReviewedInSprint + cardsCompleted,
      recentActivityTicker: updatedTicker,
    ));
    sendChatMessage(
      '🏆 Sprint Completed: $cardsCompleted cards reviewed (+50 Pod XP)! 🔥',
      isReaction: true,
    );
  }

  void endCoOpSprint() {
    _sprintTimer?.cancel();
    emit(state.copyWith(
      isCoOpSprintActive: false,
      coOpSprintRemainingSeconds: 0,
    ));
  }

  void triggerMicroReaction(String emoji) {
    final message = 'You sent $emoji';
    final updatedTicker = [message, ...state.recentActivityTicker.take(4)];
    emit(state.copyWith(
      lastReactionEmoji: emoji,
      recentActivityTicker: updatedTicker,
    ));
    sendChatMessage(emoji, isReaction: true);
  }

  void updateActiveGoal(String goal) {
    final message = '🎯 Goal set: $goal';
    final updatedTicker = [message, ...state.recentActivityTicker.take(4)];
    final updatedList = state.ephemeralParticipants.map((p) {
      if (p.userId == _currentUserId) return p.copyWith(activeGoal: goal);
      return p;
    }).toList();

    emit(state.copyWith(
      activeGoal: goal,
      ephemeralParticipants: updatedList,
      recentActivityTicker: updatedTicker,
    ));
    sendChatMessage('Target: $goal', isReaction: true);
    unawaited(
      _ephemeralRepository?.broadcastGoal(
        roomId: state.room.id,
        userId: _currentUserId,
        goal: goal,
      ),
    );
  }

  Future<void> _initAmbientAudio() async {
    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.setVolume(state.ambientAudioVolume);
      if (state.isAmbientAudioPlaying) {
        await _playTrack(state.ambientSoundTrack);
      }
    } on Object catch (_) {}
  }

  Future<void> _playTrack(String track) async {
    try {
      final asset = _trackAssets[track] ?? _trackAssets['lofi']!;
      await _ambientPlayer.stop();
      await _ambientPlayer.play(AssetSource(asset));
      await _ambientPlayer.setVolume(state.ambientAudioVolume);
    } on Object catch (_) {}
  }

  void setAmbientSoundTrack(String track) {
    emit(state.copyWith(ambientSoundTrack: track));
    if (state.isAmbientAudioPlaying) {
      unawaited(_playTrack(track));
    }
  }

  void toggleAmbientAudio() {
    final nextState = !state.isAmbientAudioPlaying;
    emit(state.copyWith(isAmbientAudioPlaying: nextState));
    if (nextState) {
      unawaited(_playTrack(state.ambientSoundTrack));
    } else {
      unawaited(_ambientPlayer.pause());
    }
  }

  void setAmbientVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    emit(state.copyWith(ambientAudioVolume: clamped));
    unawaited(_ambientPlayer.setVolume(clamped));
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

  void _startSyllabotBuddyCheck() {
    _buddyTimer?.cancel();
    _buddyTimer = Timer(const Duration(seconds: 4), () {
      if (isClosed) return;
      final otherHumans = state.ephemeralParticipants.where(
        (p) => p.userId != _currentUserId && !p.isAiBuddy,
      );
      if (otherHumans.isEmpty && !state.isSyllabotBuddyActive) {
        final buddy = EphemeralParticipant(
          userId: 'syllabot_buddy_${state.room.id}',
          displayName: 'Syllabot AI (Study Buddy)',
          avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=syllabot',
          isAiBuddy: true,
          joinedAt: DateTime.now(),
        );

        final updatedList = [...state.ephemeralParticipants, buddy];
        final tickerMsg = '🤖 Syllabot joined as your study buddy! Let’s focus on ${state.room.subject}.';
        final updatedTicker = [tickerMsg, ...state.recentActivityTicker.take(4)];

        emit(state.copyWith(
          isSyllabotBuddyActive: true,
          ephemeralParticipants: updatedList,
          recentActivityTicker: updatedTicker,
        ));
      }
    });
  }

  Future<void> setLocalAwayState({required bool isAway}) async {
    if (isClosed || state.isLocalUserAway == isAway) return;

    emit(state.copyWith(isLocalUserAway: isAway));

    final updatedList = state.ephemeralParticipants.map((p) {
      if (p.userId == _currentUserId) {
        return p.copyWith(isAway: isAway);
      }
      return p;
    }).toList();

    emit(state.copyWith(ephemeralParticipants: updatedList));

    if (_ephemeralRepository != null) {
      unawaited(
        _ephemeralRepository.broadcastAwayState(
          roomId: state.room.id,
          userId: _currentUserId,
          isAway: isAway,
        ),
      );
    }

    final tickerMsg = isAway
        ? '⏳ You stepped away (focus paused)'
        : '⚡ Welcome back! Focus session resumed.';
    final updatedTicker = [tickerMsg, ...state.recentActivityTicker.take(4)];
    emit(state.copyWith(recentActivityTicker: updatedTicker));
  }

  void promptGoalVerification() {
    if (state.activeGoal != null && state.activeGoal!.trim().isNotEmpty) {
      emit(state.copyWith(showGoalVerificationModal: true));
    }
  }

  void verifyMicroGoal({required bool completed, required String goal}) {
    final tickerMsg = completed
        ? '🎯 Micro-Goal Achieved: "$goal" (+50 XP) 🔥'
        : '💪 Good progress on: "$goal". Next round awaits!';
    final updatedTicker = [tickerMsg, ...state.recentActivityTicker.take(4)];

    emit(state.copyWith(
      isGoalAchieved: completed,
      showGoalVerificationModal: false,
      recentActivityTicker: updatedTicker,
      lastReactionEmoji: completed ? '🎉' : '👏',
    ));

    sendChatMessage(tickerMsg, isReaction: true);
  }

  void dismissGoalVerification() {
    emit(state.copyWith(showGoalVerificationModal: false));
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _sprintTimer?.cancel();
    _buddyTimer?.cancel();
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
    try {
      await _ambientPlayer.stop();
      await _ambientPlayer.dispose();
    } on Object catch (_) {}
    return super.close();
  }
}
