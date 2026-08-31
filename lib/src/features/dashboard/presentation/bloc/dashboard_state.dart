import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';

enum DashboardStatus {
  initial,
  loading,
  loaded,
  error,
}

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.feed,
    this.errorMessage,
    this.isExamLaunching = false,
    this.launchedExamSessionId,
  });

  final DashboardStatus status;
  final DashboardFeedEntity? feed;
  final String? errorMessage;
  final bool isExamLaunching;
  final String? launchedExamSessionId;

  bool get isInitial => status == DashboardStatus.initial;
  bool get isLoading => status == DashboardStatus.loading;
  bool get isLoaded => status == DashboardStatus.loaded;
  bool get isError => status == DashboardStatus.error;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardFeedEntity? feed,
    String? errorMessage,
    bool? isExamLaunching,
    String? launchedExamSessionId,
  }) {
    return DashboardState(
      status: status ?? this.status,
      feed: feed ?? this.feed,
      errorMessage: errorMessage ?? this.errorMessage,
      isExamLaunching: isExamLaunching ?? this.isExamLaunching,
      launchedExamSessionId:
          launchedExamSessionId ?? this.launchedExamSessionId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    feed,
    errorMessage,
    isExamLaunching,
    launchedExamSessionId,
  ];
}
