import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';

class UserProfileModel extends Equatable {
  const UserProfileModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.targetTrack = 'WAEC',
    this.dailyCardTarget = 20,
    this.retentionBenchmark = 0.85,
    this.level = 1,
    this.streakDays = 0,
    this.xpPoints = 0,
    this.subscriptionTier = 'free',
    this.isOnboarded = false,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      targetTrack: json['target_track'] as String? ?? 'WAEC',
      dailyCardTarget: (json['daily_card_target'] as num?)?.toInt() ?? 20,
      retentionBenchmark:
          (json['retention_benchmark'] as num?)?.toDouble() ?? 0.85,
      level: (json['level'] as num?)?.toInt() ?? 1,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      xpPoints: (json['xp_points'] as num?)?.toInt() ?? 0,
      subscriptionTier:
          (json['subscription_tier'] as String?)?.toLowerCase() ?? 'free',
      isOnboarded: json['is_onboarded'] as bool? ?? false,
    );
  }

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String targetTrack;
  final int dailyCardTarget;
  final double retentionBenchmark;
  final int level;
  final int streakDays;
  final int xpPoints;
  final String subscriptionTier;
  final bool isOnboarded;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'target_track': targetTrack,
      'daily_card_target': dailyCardTarget,
      'retention_benchmark': retentionBenchmark,
      'level': level,
      'streak_days': streakDays,
      'xp_points': xpPoints,
      'subscription_tier': subscriptionTier,
      'is_onboarded': isOnboarded,
    };
  }

  UserProfileEntity toEntity() {
    return UserProfileEntity(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      targetTrack: targetTrack,
      dailyCardTarget: dailyCardTarget,
      retentionBenchmark: retentionBenchmark,
      level: level,
      streakDays: streakDays,
      xpPoints: xpPoints,
      subscriptionTier: subscriptionTier,
      isOnboarded: isOnboarded,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    photoUrl,
    targetTrack,
    dailyCardTarget,
    retentionBenchmark,
    level,
    streakDays,
    xpPoints,
    subscriptionTier,
    isOnboarded,
  ];
}
