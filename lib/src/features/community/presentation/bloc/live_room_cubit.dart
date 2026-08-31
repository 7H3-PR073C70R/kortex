import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

class LiveRoomState extends Equatable {
  const LiveRoomState({
    required this.room,
    this.remainingSeconds = 1500,
    this.isConnected = true,
    this.participants = const [],
  });

  final StudyRoomEntity room;
  final int remainingSeconds;
  final bool isConnected;
  final List<String> participants;

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
  }) {
    return LiveRoomState(
      room: room ?? this.room,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isConnected: isConnected ?? this.isConnected,
      participants: participants ?? this.participants,
    );
  }

  @override
  List<Object?> get props => [
        room,
        remainingSeconds,
        isConnected,
        participants,
      ];
}

class LiveRoomCubit extends Cubit<LiveRoomState> {
  LiveRoomCubit({
    required StudyRoomEntity initialRoom,
    required CommunityRepository repository,
  })  : _repository = repository,
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
  }

  final CommunityRepository _repository;
  Timer? _timer;
  StreamSubscription<StudyRoomEntity>? _roomSubscription;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds > 0) {
        emit(state.copyWith(remainingSeconds: state.remainingSeconds - 1));
      } else {
        // Toggle Pomodoro state
        final nextState = state.room.isFocusing ? 'break' : 'focusing';
        final nextDuration = nextState == 'break'
            ? 5
            : state.room.pomodoroDurationMinutes;
        emit(
          state.copyWith(
            room: state.room.copyWith(pomodoroState: nextState),
            remainingSeconds: nextDuration * 60,
          ),
        );
      }
    });
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription =
        _repository.watchStudyRoom(roomId).listen((updatedRoom) {
      if (!isClosed) {
        emit(state.copyWith(room: updatedRoom));
      }
    });
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
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _roomSubscription?.cancel();
    return super.close();
  }
}
