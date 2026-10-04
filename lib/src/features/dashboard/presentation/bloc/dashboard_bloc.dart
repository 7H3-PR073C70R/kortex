import 'package:bloc/bloc.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_dashboard_feed_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/quick_start_mock_exam_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required this.getDashboardFeedUseCase,
    required this.quickStartMockExamUseCase,
  }) : super(const DashboardState()) {
    on<DashboardStarted>(_onStarted);
    on<DashboardRefreshed>(_onRefreshed);
    on<DashboardExamStarted>(_onExamStarted);
    on<DashboardDeckDeleted>(_onDeckDeleted);
  }

  final GetDashboardFeedUseCase getDashboardFeedUseCase;
  final QuickStartMockExamUseCase quickStartMockExamUseCase;

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<DashboardState> emit,
  ) async {
    // If we already have a valid feed (e.g. from a previous load in the same
    // session), surface it immediately as aboveFoldReady so the UI skips the
    // full shimmer pass and starts a silent background revalidation instead.
    if (state.feed != null) {
      emit(
        state.copyWith(
          status: DashboardStatus.loaded,
          sectionStatus: DashboardSectionStatus.revalidating,
          previousFeed: state.feed,
        ),
      );      // Background revalidation — does not show loading shimmer.
      final result = await getDashboardFeedUseCase(
        const GetDashboardFeedParams(),
      );
      result.fold(
        (_) {
          // Silently ignore — keep showing the previous feed.
          emit(
            state.copyWith(
              sectionStatus: DashboardSectionStatus.fullyLoaded,
            ),
          );
        },
        (feed) => emit(
          state.copyWith(
            status: DashboardStatus.loaded,
            sectionStatus: DashboardSectionStatus.fullyLoaded,
            feed: feed,
          ),
        ),
      );
      return;
    }

    // Cold start — show loading shimmer, then transition to content.
    emit(state.copyWith(status: DashboardStatus.loading));
    final result = await getDashboardFeedUseCase(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DashboardStatus.error,
          sectionStatus: DashboardSectionStatus.error,
          errorMessage: failure.message ?? 'Failed to load dashboard feed.',
        ),
      ),
      (feed) => emit(
        state.copyWith(
          status: DashboardStatus.loaded,
          sectionStatus: DashboardSectionStatus.fullyLoaded,
          feed: feed,
        ),
      ),
    );
  }

  Future<void> _onRefreshed(
    DashboardRefreshed event,
    Emitter<DashboardState> emit,
  ) async {
    // Stale-while-revalidate: mark as revalidating so the UI keeps showing
    // the existing feed while the fresh data loads in the background.
    emit(
      state.copyWith(
        sectionStatus: DashboardSectionStatus.revalidating,
        previousFeed: state.feed,
      ),
    );

    final result = await getDashboardFeedUseCase(
      const GetDashboardFeedParams(forceRefresh: true),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          errorMessage: failure.message,
          sectionStatus: DashboardSectionStatus.fullyLoaded,
        ),
      ),
      (feed) => emit(
        state.copyWith(
          status: DashboardStatus.loaded,
          sectionStatus: DashboardSectionStatus.fullyLoaded,
          feed: feed,
        ),
      ),
    );
  }

  Future<void> _onExamStarted(
    DashboardExamStarted event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(isExamLaunching: true));

    final result = await quickStartMockExamUseCase(
      QuickStartMockExamParams(
        examId: event.examId,
        subject: event.subject,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          isExamLaunching: false,
          errorMessage: failure.message ?? 'Could not start exam simulation.',
        ),
      ),
      (sessionId) => emit(
        state.copyWith(
          isExamLaunching: false,
          launchedExamSessionId: sessionId,
        ),
      ),
    );
  }

  void _onDeckDeleted(
    DashboardDeckDeleted event,
    Emitter<DashboardState> emit,
  ) {
    final currentFeed = state.feed;
    if (currentFeed == null) return;

    final updatedDecks = currentFeed.dueStudyDecks
        .where((d) => d.id != event.deckId)
        .toList();

    emit(
      state.copyWith(
        feed: currentFeed.copyWith(
          dueStudyDecks: updatedDecks,
        ),
      ),
    );
  }
}
