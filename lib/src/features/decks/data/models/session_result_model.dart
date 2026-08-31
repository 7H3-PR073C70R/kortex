import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_result_model.freezed.dart';
part 'session_result_model.g.dart';

@freezed
abstract class SessionResultModel with _$SessionResultModel {
  const factory SessionResultModel({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    @Default(50) int xpEarned,
    DateTime? completedAt,
  }) = _SessionResultModel;

  factory SessionResultModel.fromJson(Map<String, dynamic> json) =>
      _$SessionResultModelFromJson(json);
}
