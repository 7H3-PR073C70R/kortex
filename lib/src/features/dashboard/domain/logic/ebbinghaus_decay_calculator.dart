import 'dart:math';

class DailyRetentionPoint {
  const DailyRetentionPoint({
    required this.day,
    required this.predictedRetention,
    required this.actualRetention,
    required this.dueCardsCount,
  });

  final int day;
  final double predictedRetention; // 0.0 to 1.0 (e.g. 0.85 = 85%)
  final double actualRetention; // 0.0 to 1.0
  final int dueCardsCount;
}

/// Computes adaptive Ebbinghaus memory decay curves and workload projections.
class EbbinghausDecayCalculator {
  const EbbinghausDecayCalculator();

  /// Calculates retrievability at day `daysElapsed` given stability
  /// `stability`.
  /// Uses exponential power formula: R(t) = exp(-t / S).
  double calculateRetention({
    required double stability,
    required int daysElapsed,
  }) {
    if (stability <= 0) return 0;
    if (daysElapsed <= 0) return 1;
    final r = exp(-daysElapsed / stability);
    return r.clamp(0.0, 1.0);
  }

  /// Calculates a 7-day projected vs actual memory retention curve.
  List<DailyRetentionPoint> calculateSevenDayProjection({
    required List<double> cardStabilities,
    List<double>? empiricalRecallRates,
  }) {
    final points = <DailyRetentionPoint>[];
    final defaultRates = empiricalRecallRates ??
        [1.0, 0.94, 0.89, 0.84, 0.81, 0.77, 0.74];

    for (var day = 0; day < 7; day++) {
      double avgPredicted;
      if (cardStabilities.isEmpty) {
        // Baseline decay curve
        avgPredicted = exp(-day / 4.5);
      } else {
        final sum = cardStabilities.fold<double>(
          0,
          (acc, s) => acc + calculateRetention(stability: s, daysElapsed: day),
        );
        avgPredicted = sum / cardStabilities.length;
      }

      final actual = day < defaultRates.length
          ? defaultRates[day]
          : avgPredicted * 0.98;

      // Project due workload for that day
      final dueCount = cardStabilities
          .where((s) => s.round() == day || (day == 0 && s <= 1.0))
          .length;

      points.add(
        DailyRetentionPoint(
          day: day,
          predictedRetention: double.parse(avgPredicted.toStringAsFixed(3)),
          actualRetention: double.parse(actual.toStringAsFixed(3)),
          dueCardsCount: dueCount,
        ),
      );
    }

    return points;
  }
}
