import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';

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
    this.leagueTier = 'Bronze',
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
  final String leagueTier;
  final int rank;

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    final weeklyXp = (json['weekly_xp'] as num?)?.toInt() ??
        (json['xp_points'] as num?)?.toInt() ??
        (json['xp'] as num?)?.toInt() ??
        0;

    final parsedStreak = (json['streak_days'] as num?)?.toInt() ??
        (json['streak_count'] as num?)?.toInt() ??
        (json['current_streak'] as num?)?.toInt() ??
        (json['streak'] as num?)?.toInt();

    final effectiveStreak = (parsedStreak != null && parsedStreak > 0)
        ? parsedStreak
        : (weeklyXp > 0
            ? (weeklyXp >= 500
                ? 7
                : (weeklyXp >= 200 ? 4 : (weeklyXp >= 50 ? 2 : 1)))
            : 1);

    final trackVal = (json['track'] as String?)?.trim() ??
        (json['target_track'] as String?)?.trim() ??
        'General';

    final nameVal = (json['user_name'] as String?)?.trim() ??
        (json['display_name'] as String?)?.trim() ??
        (json['username'] as String?)?.trim() ??
        'Scholar';

    final avatar = (json['avatar_url'] as String?) ?? (json['photo_url'] as String?);

    return LeaderboardEntryModel(
      id: json['id'] as String? ?? 'lb_${json['user_id'] ?? nameVal}',
      userId: json['user_id'] as String? ?? '',
      userName: nameVal.isNotEmpty ? nameVal : 'Scholar',
      avatarUrl: avatar,
      track: trackVal.isNotEmpty ? trackVal : 'General',
      dailyXp: (json['daily_xp'] as num?)?.toInt() ?? 0,
      weeklyXp: weeklyXp,
      streakDays: effectiveStreak,
      leagueTier: json['league_tier'] as String? ?? 'Bronze',
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
      'league_tier': leagueTier,
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
      leagueTier: leagueTier,
      rank: rank,
      isCurrentUser: currentUserId != null && userId == currentUserId,
    );
  }
}
