import 'package:equatable/equatable.dart';

/// Represents a gamified user standing on the streak & XP leaderboard.
class LeaderboardEntryEntity extends Equatable {
  const LeaderboardEntryEntity({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.track = 'General',
    this.dailyXp = 0,
    this.weeklyXp = 0,
    this.streakDays = 1,
    this.rank = 1,
    this.isCurrentUser = false,
  });

  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String track;
  final int dailyXp;
  final int weeklyXp;
  final int streakDays;
  final int rank;
  final bool isCurrentUser;

  LeaderboardEntryEntity copyWith({
    String? id,
    String? userId,
    String? userName,
    String? avatarUrl,
    String? track,
    int? dailyXp,
    int? weeklyXp,
    int? streakDays,
    int? rank,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntryEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      track: track ?? this.track,
      dailyXp: dailyXp ?? this.dailyXp,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      streakDays: streakDays ?? this.streakDays,
      rank: rank ?? this.rank,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    userName,
    avatarUrl,
    track,
    dailyXp,
    weeklyXp,
    streakDays,
    rank,
    isCurrentUser,
  ];
}
