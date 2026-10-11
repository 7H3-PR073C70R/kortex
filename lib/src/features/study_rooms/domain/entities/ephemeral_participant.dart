import 'package:equatable/equatable.dart';

class EphemeralParticipant extends Equatable {
  const EphemeralParticipant({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.isHandRaised = false,
    this.isMuted = true,
    this.isAway = false,
    this.isAiBuddy = false,
    this.joinedAt,
    this.activeGoal,
    this.cardsReviewed = 0,
    this.currentDeckTitle,
  });

  factory EphemeralParticipant.fromJson(Map<String, dynamic> json) {
    return EphemeralParticipant(
      userId: json['userId'] as String? ?? 'unknown',
      displayName: json['displayName'] as String? ?? 'Scholar',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      isHandRaised: json['isHandRaised'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? true,
      isAway: json['isAway'] as bool? ?? false,
      isAiBuddy: json['isAiBuddy'] as bool? ?? false,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String)
          : null,
      activeGoal: json['activeGoal'] as String?,
      cardsReviewed: json['cardsReviewed'] as int? ?? 0,
      currentDeckTitle: json['currentDeckTitle'] as String?,
    );
  }

  final String userId;
  final String displayName;
  final String avatarUrl;
  final bool isHandRaised;
  final bool isMuted;
  final bool isAway;
  final bool isAiBuddy;
  final DateTime? joinedAt;

  /// The micro-goal this participant set for the current session.
  /// Broadcast via the ephemeral presence channel so peers can see it.
  final String? activeGoal;

  /// Number of flashcards reviewed in this room sprint.
  final int cardsReviewed;

  /// The active deck title being studied.
  final String? currentDeckTitle;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isHandRaised': isHandRaised,
      'isMuted': isMuted,
      'isAway': isAway,
      'isAiBuddy': isAiBuddy,
      'joinedAt': (joinedAt ?? DateTime.now()).toIso8601String(),
      if (activeGoal != null) 'activeGoal': activeGoal,
      'cardsReviewed': cardsReviewed,
      if (currentDeckTitle != null) 'currentDeckTitle': currentDeckTitle,
    };
  }

  EphemeralParticipant copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    bool? isHandRaised,
    bool? isMuted,
    bool? isAway,
    bool? isAiBuddy,
    DateTime? joinedAt,
    String? activeGoal,
    int? cardsReviewed,
    String? currentDeckTitle,
  }) {
    return EphemeralParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isMuted: isMuted ?? this.isMuted,
      isAway: isAway ?? this.isAway,
      isAiBuddy: isAiBuddy ?? this.isAiBuddy,
      joinedAt: joinedAt ?? this.joinedAt,
      activeGoal: activeGoal ?? this.activeGoal,
      cardsReviewed: cardsReviewed ?? this.cardsReviewed,
      currentDeckTitle: currentDeckTitle ?? this.currentDeckTitle,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    displayName,
    avatarUrl,
    isHandRaised,
    isMuted,
    isAway,
    isAiBuddy,
    joinedAt,
    activeGoal,
    cardsReviewed,
    currentDeckTitle,
  ];
}
