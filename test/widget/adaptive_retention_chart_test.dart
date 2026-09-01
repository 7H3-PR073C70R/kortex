import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/domain/logic/ebbinghaus_decay_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/adaptive_retention_chart.dart';

import '../helpers/pump_app.dart';

void main() {
  group('AdaptiveRetentionChart Widget Test Suite', () {
    const tPoints = [
      DailyRetentionPoint(
        day: 0,
        predictedRetention: 1,
        actualRetention: 1,
        dueCardsCount: 5,
      ),
      DailyRetentionPoint(
        day: 1,
        predictedRetention: 0.92,
        actualRetention: 0.94,
        dueCardsCount: 2,
      ),
      DailyRetentionPoint(
        day: 2,
        predictedRetention: 0.85,
        actualRetention: 0.88,
        dueCardsCount: 3,
      ),
    ];

    testWidgets('renders chart and responds to day selection', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              height: 500,
              child: AdaptiveRetentionChart(points: tPoints),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('7-Day Projected Review Workload'), findsOneWidget);
      expect(find.text('Predicted'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
      expect(find.text('D0'), findsOneWidget);
      expect(find.text('D1'), findsOneWidget);

      await tester.tap(find.text('D1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Day 1: 92% Retention'), findsOneWidget);
    });
  });
}
