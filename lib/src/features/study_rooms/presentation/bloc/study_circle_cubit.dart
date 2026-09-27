import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/study_circle_state.dart';

class StudyCircleCubit extends Cubit<StudyCircleState> {
  StudyCircleCubit({
    required CommunityRepository repository,
  })  : _repository = repository,
        super(const StudyCircleState());

  final CommunityRepository _repository;

  Future<void> loadStudyCircles({String? track}) async {
    final effectiveTrack = (track ?? state.selectedTrack) == 'All' ? null : (track ?? state.selectedTrack);
    emit(state.copyWith(status: StudyCircleStatus.loading, selectedTrack: track ?? state.selectedTrack));

    final res = await _repository.fetchStudyCircles(track: effectiveTrack);
    res.fold(
      (failure) => emit(state.copyWith(status: StudyCircleStatus.failure, errorMessage: failure.message)),
      (circles) => emit(state.copyWith(status: StudyCircleStatus.loaded, circles: circles)),
    );
  }

  Future<void> createStudyCircle({
    required String name,
    required String track,
    required int targetWeeklyMinutes,
  }) async {
    final res = await _repository.createStudyCircle(
      name: name,
      track: track,
      targetWeeklyMinutes: targetWeeklyMinutes,
    );
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (newCircle) {
        emit(state.copyWith(circles: [newCircle, ...state.circles]));
      },
    );
  }

  Future<void> joinStudyCircle(String circleId) async {
    final res = await _repository.joinStudyCircle(circleId);
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (updatedCircle) {
        final updatedList = state.circles.map((c) => c.id == circleId ? updatedCircle : c).toList();
        emit(state.copyWith(circles: updatedList));
      },
    );
  }

  Future<void> leaveStudyCircle(String circleId) async {
    final res = await _repository.leaveStudyCircle(circleId);
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (updatedCircle) {
        final updatedList = state.circles.map((c) => c.id == circleId ? updatedCircle : c).toList();
        emit(state.copyWith(circles: updatedList));
      },
    );
  }

  Future<void> nudgeMember({required String circleId}) async {
    final res = await _repository.nudgeStudyCircle(circleId);
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {},
    );
  }

  Future<void> recordFocusMinutes({required String circleId, required int minutes}) async {
    final res = await _repository.recordPodFocusMinutes(circleId: circleId, minutes: minutes);
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => loadStudyCircles(),
    );
  }
}
