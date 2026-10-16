import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/save_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects_step.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveCalibrationProfileUseCase extends Mock
    implements SaveCalibrationProfileUseCase {}

Widget _wrapWithTheme({
  required Widget child,
  required CalibrationCubit cubit,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<CalibrationCubit>.value(
        value: cubit,
        child: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  late MockSaveCalibrationProfileUseCase mockSaveUseCase;
  late CalibrationCubit cubit;

  setUpAll(() {
    registerFallbackValue(const CalibrationProfile());
  });

  setUp(() {
    mockSaveUseCase = MockSaveCalibrationProfileUseCase();
    when(() => mockSaveUseCase(any()))
        .thenAnswer((_) async => const Right(null));

    cubit = CalibrationCubit(
      saveCalibrationProfileUseCase: mockSaveUseCase,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  group('HighSchoolSubjectsStep Widget Tests', () {
    testWidgets('renders title, search bar, and catalog subject cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          cubit: cubit,
          child: HighSchoolSubjectsStep(calibrationCubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HighSchoolSubjectsStep), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('English Language'), findsOneWidget);
      expect(find.text('Physics'), findsOneWidget);
    });

    testWidgets('tapping a subject card toggles selection in cubit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          cubit: cubit,
          child: HighSchoolSubjectsStep(calibrationCubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.profile.highSchoolSubjects, isEmpty);

      // Tap Mathematics card
      await tester.tap(find.text('Mathematics'));
      await tester.pumpAndSettle();

      expect(cubit.state.profile.highSchoolSubjects, contains('Mathematics'));
      expect(find.textContaining('1 of '), findsOneWidget);

      // Tap Mathematics card again to deselect
      await tester.tap(find.text('Mathematics'));
      await tester.pumpAndSettle();

      expect(cubit.state.profile.highSchoolSubjects, isEmpty);
    });

    testWidgets('search query filters courses and shows empty view if no match',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          cubit: cubit,
          child: HighSchoolSubjectsStep(calibrationCubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search term matching Physics
      await tester.enterText(find.byType(TextField), 'Physics');
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(HighSchoolSubjectCard, 'Physics'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(HighSchoolSubjectCard, 'Mathematics'),
        findsNothing,
      );

      // Enter search term with zero matches
      await tester.enterText(find.byType(TextField), 'NonExistentSubjectXYZ');
      await tester.pumpAndSettle();

      expect(find.byType(HighSchoolSubjectsEmptyView), findsOneWidget);
      expect(
        find.text('No subjects found matching "NonExistentSubjectXYZ"'),
        findsOneWidget,
      );

      // Tap reset search
      await tester.tap(find.text('Reset search & filters'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(HighSchoolSubjectCard, 'Mathematics'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(HighSchoolSubjectCard, 'Physics'),
        findsOneWidget,
      );
    });

    testWidgets('clear all button removes all selected subjects', (
      tester,
    ) async {
      cubit.setHighSchoolSubjects(['Mathematics', 'Physics']);

      await tester.pumpWidget(
        _wrapWithTheme(
          cubit: cubit,
          child: HighSchoolSubjectsStep(calibrationCubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2 of '), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(cubit.state.profile.highSchoolSubjects, isEmpty);
      expect(find.textContaining('0 of '), findsOneWidget);
    });
  });
}
