import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on initial load or retry
class DashboardStarted extends DashboardEvent {
  const DashboardStarted();
}

/// Dispatched on pull-to-refresh
class DashboardRefreshed extends DashboardEvent {
  const DashboardRefreshed();
}

/// Dispatched when user triggers an exam simulation from countdown or lobby
class DashboardExamStarted extends DashboardEvent {
  const DashboardExamStarted({
    required this.examId,
    required this.subject,
  });

  final String examId;
  final String subject;

  @override
  List<Object?> get props => [examId, subject];
}

/// Dispatched when user submits a quick query to Syllabot from the
/// dashboard bar
class DashboardQuickPromptSubmitted extends DashboardEvent {
  const DashboardQuickPromptSubmitted(this.prompt);

  final String prompt;

  @override
  List<Object?> get props => [prompt];
}
