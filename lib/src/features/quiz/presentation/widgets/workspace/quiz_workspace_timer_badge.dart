import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';

/// Live Session Timer Badge (authentic CBT countdown)
class QuizTimerBadge extends StatelessWidget {
  const QuizTimerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocSelector<
      QuizSessionCubit,
      QuizSessionState,
      ({String timer, bool isLow})
    >(
      selector: (state) => (
        timer: state.formattedTimer,
        isLow: state.isTimeRunningLow,
      ),
      builder: (context, data) {
        return Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: data.isLow
                ? colors.error.withValues(alpha: isDark ? 0.2 : 0.1)
                : colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.badge),
            border: Border.all(
              color: data.isLow
                  ? colors.error.withValues(alpha: 0.5)
                  : colors.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: data.isLow ? colors.error : colors.success,
              ),
              const SizedBox(width: 5),
              Text(
                data.timer,
                style: typography.caption.bold.copyWith(
                  color: data.isLow ? colors.error : colors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
