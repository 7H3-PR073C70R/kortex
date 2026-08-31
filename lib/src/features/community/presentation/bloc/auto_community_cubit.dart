import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/community/domain/use_cases/auto_provision_community_use_case.dart';
import 'package:kortex/src/features/community/domain/use_cases/fetch_course_community_stats_use_case.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_state.dart';

class AutoCommunityCubit extends Cubit<AutoCommunityState> {
  AutoCommunityCubit({
    required AutoProvisionCommunityUseCase autoProvisionCommunityUseCase,
    required FetchCourseCommunityStatsUseCase fetchCourseCommunityStatsUseCase,
  })  : _autoProvisionCommunityUseCase = autoProvisionCommunityUseCase,
        _fetchCourseCommunityStatsUseCase = fetchCourseCommunityStatsUseCase,
        super(const AutoCommunityState());

  final AutoProvisionCommunityUseCase _autoProvisionCommunityUseCase;
  final FetchCourseCommunityStatsUseCase _fetchCourseCommunityStatsUseCase;

  /// Idempotently provisions or joins peer community when user selects
  /// an onboarding track.
  Future<void> provisionForTrack(String track) async {
    final normalizedTrack = track.trim().toUpperCase();
    final courseCode = '$normalizedTrack-STUDY-HUB';
    final title = '$normalizedTrack Peer Study Hub';

    emit(state.copyWith(status: AutoCommunityStatus.provisioning));

    final result = await _autoProvisionCommunityUseCase(
      courseCode: courseCode,
      title: title,
      department: normalizedTrack,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AutoCommunityStatus.error,
          errorMessage: failure.message ?? 'Could not provision track hub.',
        ),
      ),
      (community) => emit(
        state.copyWith(
          status: AutoCommunityStatus.provisioned,
          community: community,
          isBannerDismissed: false,
        ),
      ),
    );
  }

  /// Auto-provisions or joins peer hub when a new course document is ingested.
  Future<void> provisionForDocument({
    required String courseCode,
    required String title,
    String? department,
  }) async {
    final normalizedCode = courseCode.trim().toUpperCase();

    emit(state.copyWith(status: AutoCommunityStatus.provisioning));

    final result = await _autoProvisionCommunityUseCase(
      courseCode: normalizedCode,
      title: title,
      department: department ?? 'General',
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AutoCommunityStatus.error,
          errorMessage:
              failure.message ?? 'Could not auto-provision course hub.',
        ),
      ),
      (community) => emit(
        state.copyWith(
          status: AutoCommunityStatus.provisioned,
          community: community,
          isBannerDismissed: false,
        ),
      ),
    );
  }

  /// Refreshes peer counts and active study room stats.
  Future<void> fetchStats(String courseCode) async {
    final result = await _fetchCourseCommunityStatsUseCase(courseCode);
    result.fold(
      (_) {},
      (community) => emit(
        state.copyWith(
          community: community,
        ),
      ),
    );
  }

  /// Dismisses the auto-community banner for the current session.
  void dismissBanner() {
    emit(state.copyWith(isBannerDismissed: true));
  }
}
