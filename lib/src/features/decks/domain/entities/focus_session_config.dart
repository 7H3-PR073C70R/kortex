import 'package:equatable/equatable.dart';

enum FocusSessionType {
  cardCount,
  timed,
}

enum FocusAmbientSound {
  none,
  brownNoise,
  binauralBeats,
  lofiRain,
}

class FocusSessionConfig extends Equatable {
  const FocusSessionConfig({
    this.type = FocusSessionType.cardCount,
    this.targetCardCount = 10,
    this.targetDurationMinutes = 10,
    this.isSoftCatchUp = true,
    this.ambientSound = FocusAmbientSound.none,
    this.ttsAutoRead = false,
    this.hideCardCounter = false,
  });

  final FocusSessionType type;
  final int targetCardCount;
  final int targetDurationMinutes;
  final bool isSoftCatchUp;
  final FocusAmbientSound ambientSound;
  final bool ttsAutoRead;
  final bool hideCardCounter;

  FocusSessionConfig copyWith({
    FocusSessionType? type,
    int? targetCardCount,
    int? targetDurationMinutes,
    bool? isSoftCatchUp,
    FocusAmbientSound? ambientSound,
    bool? ttsAutoRead,
    bool? hideCardCounter,
  }) {
    return FocusSessionConfig(
      type: type ?? this.type,
      targetCardCount: targetCardCount ?? this.targetCardCount,
      targetDurationMinutes:
          targetDurationMinutes ?? this.targetDurationMinutes,
      isSoftCatchUp: isSoftCatchUp ?? this.isSoftCatchUp,
      ambientSound: ambientSound ?? this.ambientSound,
      ttsAutoRead: ttsAutoRead ?? this.ttsAutoRead,
      hideCardCounter: hideCardCounter ?? this.hideCardCounter,
    );
  }

  @override
  List<Object?> get props => [
        type,
        targetCardCount,
        targetDurationMinutes,
        isSoftCatchUp,
        ambientSound,
        ttsAutoRead,
        hideCardCounter,
      ];
}
