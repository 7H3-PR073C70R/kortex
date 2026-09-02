import 'package:equatable/equatable.dart';

/// Represents a persistent user profile with track preferences,
/// study goals, and subscription tier.
class UserProfileEntity extends Equatable {
  const UserProfileEntity({
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

  bool get isPro => subscriptionTier.toLowerCase() == 'pro';

  UserProfileEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? targetTrack,
    int? dailyCardTarget,
    double? retentionBenchmark,
    int? level,
    int? streakDays,
    int? xpPoints,
    String? subscriptionTier,
    bool? isOnboarded,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      targetTrack: targetTrack ?? this.targetTrack,
      dailyCardTarget: dailyCardTarget ?? this.dailyCardTarget,
      retentionBenchmark: retentionBenchmark ?? this.retentionBenchmark,
      level: level ?? this.level,
      streakDays: streakDays ?? this.streakDays,
      xpPoints: xpPoints ?? this.xpPoints,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      isOnboarded: isOnboarded ?? this.isOnboarded,
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
