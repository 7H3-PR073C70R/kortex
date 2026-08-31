import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';

abstract class CommunityEvent extends Equatable {
  const CommunityEvent();

  @override
  List<Object?> get props => [];
}

class LoadCommunityHubEvent extends CommunityEvent {
  const LoadCommunityHubEvent({this.track, this.category});

  final String? track;
  final String? category;

  @override
  List<Object?> get props => [track, category];
}

class SwitchCommunityTabEvent extends CommunityEvent {
  const SwitchCommunityTabEvent(this.tabIndex);

  final int tabIndex;

  @override
  List<Object?> get props => [tabIndex];
}

class ChangeTrackFilterEvent extends CommunityEvent {
  const ChangeTrackFilterEvent(this.track);

  final String track;

  @override
  List<Object?> get props => [track];
}

class CreateRoomEvent extends CommunityEvent {
  const CreateRoomEvent({
    required this.title,
    required this.subject,
    required this.category,
    required this.pomodoroMinutes,
  });

  final String title;
  final String subject;
  final String category;
  final int pomodoroMinutes;

  @override
  List<Object?> get props => [title, subject, category, pomodoroMinutes];
}

class CreateForumPostEvent extends CommunityEvent {
  const CreateForumPostEvent({
    required this.title,
    required this.content,
    required this.track,
    this.latexContent,
  });

  final String title;
  final String content;
  final String track;
  final String? latexContent;

  @override
  List<Object?> get props => [title, content, track, latexContent];
}

class ReplyToPostEvent extends CommunityEvent {
  const ReplyToPostEvent({
    required this.postId,
    required this.content,
    this.latexContent,
  });

  final String postId;
  final String content;
  final String? latexContent;

  @override
  List<Object?> get props => [postId, content, latexContent];
}

class CloneDeckEvent extends CommunityEvent {
  const CloneDeckEvent(this.sharedDeckId);

  final String sharedDeckId;

  @override
  List<Object?> get props => [sharedDeckId];
}

class LeaderboardUpdatedEvent extends CommunityEvent {
  const LeaderboardUpdatedEvent(this.entries);

  final List<LeaderboardEntryEntity> entries;

  @override
  List<Object?> get props => [entries];
}
