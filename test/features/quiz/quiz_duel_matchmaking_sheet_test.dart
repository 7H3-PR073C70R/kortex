import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_matchmaking_sheet.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockQuizDuelCubit extends MockCubit<QuizDuelState>
    implements QuizDuelCubit {}

Widget createTestApp({
  required Widget child,
  required QuizDuelCubit cubit,
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<QuizDuelCubit>.value(
        value: cubit,
        child: child,
      ),
    ),
  );
}

void main() {
  group('QuizDuelMatchmakingSheet Widget Tests', () {
    late MockQuizDuelCubit mockCubit;

    setUp(() {
      mockCubit = MockQuizDuelCubit();
      when(() => mockCubit.state).thenReturn(const QuizDuelState());
    });

    testWidgets(
      'renders default subjects banner and add-course chip when no courses exist',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            cubit: mockCubit,
            child: const QuizDuelMatchmakingSheet(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify default subjects banner exists
        expect(find.text('Default Foundational Subjects'), findsOneWidget);
        expect(find.text('Add Courses'), findsOneWidget);
        expect(find.text('create a deck'), findsOneWidget);

        // Verify core default subjects are present
        expect(find.text('Mathematics'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Biology'), findsOneWidget);
        expect(find.text('Physics'), findsOneWidget);
        expect(find.text('Chemistry'), findsOneWidget);
        expect(find.text('Economics'), findsOneWidget);

        // Verify add course chip in wrap
        expect(find.text('Add Course'), findsOneWidget);
      },
    );
  });
}
