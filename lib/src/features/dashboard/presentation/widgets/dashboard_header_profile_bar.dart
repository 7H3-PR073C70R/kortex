import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';

/// Scoped BlocBuilder wrapper for the Dashboard Header Profile Bar that isolates
/// rebuilding to changes in the student's analytics summary or calibration status.
class DashboardHeaderProfileBar extends StatelessWidget {
  const DashboardHeaderProfileBar({
    this.targetTrack,
    super.key,
  });

  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc?>()?.state;
    final userName =
        authState?.userProfile?.displayName ?? authState?.user?.displayName;
    final userPhotoUrl =
        authState?.userProfile?.photoUrl ?? authState?.user?.photoUrl;

    return BlocBuilder<DashboardBloc, DashboardState>(
      buildWhen: (previous, current) {
        final prevFeed = previous.displayFeed;
        final currFeed = current.displayFeed;
        if (prevFeed == null || currFeed == null) {
          return previous != current;
        }
        return prevFeed.analyticsSummary != currFeed.analyticsSummary ||
            prevFeed.isProfileUncalibratedFor(targetTrack) !=
                currFeed.isProfileUncalibratedFor(targetTrack);
      },
      builder: (context, state) {
        final feed = state.displayFeed;
        if (feed == null) return const SizedBox.shrink();

        return HeaderProfileBar(
          key: AppTourKeys.headerProfileKey,
          analytics: feed.analyticsSummary,
          isProfileUncalibrated: feed.isProfileUncalibratedFor(targetTrack),
          userName: userName,
          userPhotoUrl: userPhotoUrl,
        );
      },
    );
  }
}
