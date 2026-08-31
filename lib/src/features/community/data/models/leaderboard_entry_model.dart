import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';

class LeaderboardEntryModel {
  const LeaderboardEntryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.track = 'General',
    this.dailyXp = 0,
    this.weeklyXp = 0,
    this.streakDays = 1,
    this.rank = 1,
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

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      id: json['id'] as String? ?? 'lb_${json['user_name']}',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Scholar',
      avatarUrl: json['avatar_url'] as String?,
      track: json['track'] as String? ?? 'General',
      dailyXp: (json['daily_xp'] as num?)?.toInt() ?? 0,
      weeklyXp: (json['weekly_xp'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 1,
      rank: (json['rank'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'avatar_url': avatarUrl,
      'track': track,
      'daily_xp': dailyXp,
      'weekly_xp': weeklyXp,
      'streak_days': streakDays,
      'rank': rank,
    };
  }

  LeaderboardEntryEntity toEntity({String? currentUserId}) {
    return LeaderboardEntryEntity(
      id: id,
      userId: userId,
      userName: userName,
      avatarUrl: avatarUrl,
      track: track,
      dailyXp: dailyXp,
      weeklyXp: weeklyXp,
      streakDays: streakDays,
      rank: rank,
      isCurrentUser: currentUserId != null && userId == currentUserId,
    );
  }
}
