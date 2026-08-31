import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';

class CalculateDailyCramTargetUseCase {
  const CalculateDailyCramTargetUseCase({
    CramWorkloadCalculator? calculator,
  }) : _calculator = calculator ?? const CramWorkloadCalculator();

  final CramWorkloadCalculator _calculator;

  int call({
    required int remainingCards,
    required int lapses,
    required int daysRemaining,
  }) {
    return _calculator.calculateDailyTarget(
      remainingCards: remainingCards,
      lapses: lapses,
      daysRemaining: daysRemaining,
    );
  }
}
