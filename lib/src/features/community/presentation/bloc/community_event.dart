import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
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

class ToggleQuestionsOnlyFilterEvent extends CommunityEvent {
  const ToggleQuestionsOnlyFilterEvent({required this.questionsOnly});

  final bool questionsOnly;

  @override
  List<Object?> get props => [questionsOnly];
}

class CreateRoomEvent extends CommunityEvent {
  const CreateRoomEvent({
    required this.title,
    required this.subject,
    required this.category,
    required this.pomodoroMinutes,
    this.ambientSoundTrack = 'lofi',
    this.activeGoal,
    this.isSilentFocus = true,
  });

  final String title;
  final String subject;
  final String category;
  final int pomodoroMinutes;
  final String ambientSoundTrack;
  final String? activeGoal;
  final bool isSilentFocus;

  @override
  List<Object?> get props => [
    title,
    subject,
    category,
    pomodoroMinutes,
    ambientSoundTrack,
    activeGoal,
    isSilentFocus,
  ];
}

class CreateForumPostEvent extends CommunityEvent {
  const CreateForumPostEvent({
    required this.title,
    required this.content,
    required this.track,
    this.latexContent,
    this.isQuestion = false,
    this.syllabusTag = 'General',
    this.isAnonymous = false,
  });

  final String title;
  final String content;
  final String track;
  final String? latexContent;
  final bool isQuestion;
  final String syllabusTag;
  final bool isAnonymous;

  @override
  List<Object?> get props => [
    title,
    content,
    track,
    latexContent,
    isQuestion,
    syllabusTag,
    isAnonymous,
  ];
}

class ReplyToPostEvent extends CommunityEvent {
  const ReplyToPostEvent({
    required this.postId,
    required this.content,
    this.latexContent,
    this.parentReplyId,
  });

  final String postId;
  final String content;
  final String? latexContent;
  final String? parentReplyId;

  @override
  List<Object?> get props => [postId, content, latexContent, parentReplyId];
}

class VoteForumPostEvent extends CommunityEvent {
  const VoteForumPostEvent({
    required this.postId,
    required this.direction,
  });

  final String postId;
  final int direction; // 1 = upvote, -1 = downvote, 0 = clear

  @override
  List<Object?> get props => [postId, direction];
}

class VoteForumReplyEvent extends CommunityEvent {
  const VoteForumReplyEvent({
    required this.postId,
    required this.replyId,
    required this.direction,
  });

  final String postId;
  final String replyId;
  final int direction; // 1 = upvote, -1 = downvote, 0 = clear

  @override
  List<Object?> get props => [postId, replyId, direction];
}

class ForumPostRepliesIncrementedEvent extends CommunityEvent {
  const ForumPostRepliesIncrementedEvent({
    required this.postId,
    required this.reply,
  });

  final String postId;
  final ForumReplyEntity reply;

  @override
  List<Object?> get props => [postId, reply];
}

class VerifyForumReplyEvent extends CommunityEvent {
  const VerifyForumReplyEvent({
    required this.postId,
    required this.replyId,
  });

  final String postId;
  final String replyId;

  @override
  List<Object?> get props => [postId, replyId];
}

class LoadStudyCirclesEvent extends CommunityEvent {
  const LoadStudyCirclesEvent({this.track});

  final String? track;

  @override
  List<Object?> get props => [track];
}

class CreateStudyCircleEvent extends CommunityEvent {
  const CreateStudyCircleEvent({
    required this.name,
    required this.track,
    this.targetWeeklyMinutes = 600,
  });

  final String name;
  final String track;
  final int targetWeeklyMinutes;

  @override
  List<Object?> get props => [name, track, targetWeeklyMinutes];
}

class JoinStudyCircleEvent extends CommunityEvent {
  const JoinStudyCircleEvent(this.circleId);

  final String circleId;

  @override
  List<Object?> get props => [circleId];
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

class PublishDeckEvent extends CommunityEvent {
  const PublishDeckEvent({
    required this.title,
    required this.subject,
    required this.description,
    required this.category,
    this.totalCards = 10,
    this.cardsJson = const [],
    this.syllabusTag = 'General',
  });

  final String title;
  final String subject;
  final String description;
  final String category;
  final int totalCards;
  final List<Map<String, dynamic>> cardsJson;
  final String syllabusTag;

  @override
  List<Object?> get props => [
    title,
    subject,
    description,
    category,
    totalCards,
    cardsJson,
    syllabusTag,
  ];
}

class FetchMoreForumPostsEvent extends CommunityEvent {
  const FetchMoreForumPostsEvent();
}
