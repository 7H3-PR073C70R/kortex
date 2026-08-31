import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';

class LiveRoomState extends Equatable {
  const LiveRoomState({
    required this.room,
    this.remainingSeconds = 1500,
    this.isConnected = true,
    this.participants = const [],
    this.ephemeralParticipants = const [],
    this.isHandRaised = false,
    this.completedPomodoros = 0,
  });

  final StudyRoomEntity room;
  final int remainingSeconds;
  final bool isConnected;
  final List<String> participants;
  final List<EphemeralParticipant> ephemeralParticipants;
  final bool isHandRaised;
  final int completedPomodoros;

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
    List<String>? participants,
    List<EphemeralParticipant>? ephemeralParticipants,
    bool? isHandRaised,
    int? completedPomodoros,
  }) {
    return LiveRoomState(
      room: room ?? this.room,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isConnected: isConnected ?? this.isConnected,
      participants: participants ?? this.participants,
      ephemeralParticipants:
          ephemeralParticipants ?? this.ephemeralParticipants,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
    );
  }

  @override
  List<Object?> get props => [
        room,
        remainingSeconds,
        isConnected,
        participants,
        ephemeralParticipants,
        isHandRaised,
        completedPomodoros,
      ];
}

class LiveRoomCubit extends Cubit<LiveRoomState> {
  LiveRoomCubit({
    required StudyRoomEntity initialRoom,
    required CommunityRepository repository,
    EphemeralRoomRepository? ephemeralRepository,
    String? currentUserId,
    String? currentUserName,
    String? currentUserAvatar,
  })  : _repository = repository,
        _ephemeralRepository = ephemeralRepository,
        _currentUserId = currentUserId ?? 'user_local',
        _currentUserName = currentUserName ?? 'Scholar',
        _currentUserAvatar = currentUserAvatar ?? '',
        super(
          LiveRoomState(
            room: initialRoom,
            remainingSeconds: initialRoom.pomodoroDurationMinutes * 60,
            participants: const [
              'Adeola V.',
              'Chukwudi O.',
              'Elena R.',
              'Tariq M.',
              'Zainab B.',
            ],
          ),
        ) {
    _startTimer();
    _subscribeToRoom(initialRoom.id);
    _initEphemeralPresence(initialRoom.id);
  }

  final CommunityRepository _repository;
  final EphemeralRoomRepository? _ephemeralRepository;
  final String _currentUserId;
  final String _currentUserName;
  final String _currentUserAvatar;

  Timer? _timer;
  StreamSubscription<StudyRoomEntity>? _roomSubscription;
  StreamSubscription<List<EphemeralParticipant>>? _presenceSubscription;
  StreamSubscription<PomodoroSyncEvent>? _syncSubscription;

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
    final nextDuration =
        nextState == 'break' ? 5 : state.room.pomodoroDurationMinutes;

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

  void _initEphemeralPresence(String roomId) {
    if (_ephemeralRepository == null) return;

    unawaited(
      _ephemeralRepository.joinRoomPresence(
        roomId: roomId,
        userId: _currentUserId,
        displayName: _currentUserName,
        avatarUrl: _currentUserAvatar,
      ),
    );

    _presenceSubscription =
        _ephemeralRepository.watchParticipants(roomId).listen((participants) {
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

    _syncSubscription =
        _ephemeralRepository.watchPomodoroSync(roomId).listen((syncEvent) {
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
  }

  void toggleHandRaise() {
    final nextState = !state.isHandRaised;
    emit(state.copyWith(isHandRaised: nextState));

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
    await _ephemeralRepository?.leaveRoomPresence(state.room.id);
    return super.close();
  }
}
