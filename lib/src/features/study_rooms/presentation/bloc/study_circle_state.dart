import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';

enum StudyCircleStatus { initial, loading, loaded, failure }

class StudyCircleState extends Equatable {
  const StudyCircleState({
    this.status = StudyCircleStatus.initial,
    this.circles = const [],
    this.selectedTrack = 'All',
    this.errorMessage,
  });

  final StudyCircleStatus status;
  final List<StudyCircleEntity> circles;
  final String selectedTrack;
  final String? errorMessage;

  StudyCircleState copyWith({
    StudyCircleStatus? status,
    List<StudyCircleEntity>? circles,
    String? selectedTrack,
    String? errorMessage,
  }) {
    return StudyCircleState(
      status: status ?? this.status,
      circles: circles ?? this.circles,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, circles, selectedTrack, errorMessage];
}
