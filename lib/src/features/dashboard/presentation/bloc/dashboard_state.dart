import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';

enum DashboardStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Tracks whether analytics-heavy widgets (retention heatmap, CBT gauge) have
/// finished computing. The UI uses this to progressively reveal below-fold
/// content without blocking the above-fold skeleton → content transition.
enum DashboardSectionStatus {
  /// Nothing has been resolved yet.
  initial,

  /// Fast data (decks, courses) is available from cache or local storage.
  /// Below-fold analytics widgets still show their own shimmer.
  aboveFoldReady,

  /// All data including analytics is fully loaded and validated.
  fullyLoaded,

  /// A non-blocking background refresh is in-flight while stale data is shown.
  revalidating,

  /// Terminal error — no data available at all.
  error,
}

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.sectionStatus = DashboardSectionStatus.initial,
    this.feed,
    this.previousFeed,
    this.errorMessage,
    this.isExamLaunching = false,
    this.launchedExamSessionId,
  });

  final DashboardStatus status;

  /// Granular section readiness — used by the UI to progressively reveal
  /// analytics-heavy widgets once their data is confirmed ready.
  final DashboardSectionStatus sectionStatus;

  final DashboardFeedEntity? feed;

  /// Holds the last successfully loaded feed during a background revalidation
  /// so the UI can remain interactive with stale-but-valid data.
  final DashboardFeedEntity? previousFeed;

  final String? errorMessage;
  final bool isExamLaunching;
  final String? launchedExamSessionId;

  bool get isInitial => status == DashboardStatus.initial;
  bool get isLoading => status == DashboardStatus.loading;
  bool get isLoaded => status == DashboardStatus.loaded;
  bool get isError => status == DashboardStatus.error;

  /// True when at least a partial feed is available to display above-fold
  /// content (even during background revalidation).
  bool get hasDisplayableFeed => feed != null || previousFeed != null;

  /// The effective feed for display: live feed if available, else stale
  /// previous feed during revalidation.
  DashboardFeedEntity? get displayFeed => feed ?? previousFeed;

  /// True when analytics sections (heatmap, CBT gauge) are fully ready.
  bool get isAnalyticsReady =>
      sectionStatus == DashboardSectionStatus.fullyLoaded;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSectionStatus? sectionStatus,
    DashboardFeedEntity? feed,
    DashboardFeedEntity? previousFeed,
    String? errorMessage,
    bool? isExamLaunching,
    String? launchedExamSessionId,
  }) {
    return DashboardState(
      status: status ?? this.status,
      sectionStatus: sectionStatus ?? this.sectionStatus,
      feed: feed ?? this.feed,
      previousFeed: previousFeed ?? this.previousFeed,
      errorMessage: errorMessage ?? this.errorMessage,
      isExamLaunching: isExamLaunching ?? this.isExamLaunching,
      launchedExamSessionId:
          launchedExamSessionId ?? this.launchedExamSessionId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sectionStatus,
    feed,
    previousFeed,
    errorMessage,
    isExamLaunching,
    launchedExamSessionId,
  ];
}
