import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/lms_import_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestionBloc extends Mock implements IngestionBloc {}

void main() {
  group('LMS OAuth 2.0 & Import UI Test Suite', () {
    late MockIngestionBloc mockBloc;

    setUp(() {
      mockBloc = MockIngestionBloc();
      when(() => mockBloc.state).thenReturn(const IngestionState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget createTestApp(Widget child) {
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
          body: BlocProvider<IngestionBloc>.value(
            value: mockBloc,
            child: child,
          ),
        ),
      );
    }

    testWidgets(
      'LmsImportModalSheet triggers OAuth flow and handles connection',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const LmsImportModalSheet(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign in with Google Classroom'), findsOneWidget);
        expect(
          find.textContaining('Secured with OAuth 2.0 PKCE'),
          findsOneWidget,
        );

        // Tap the OAuth SSO button
        await tester.tap(find.text('Sign in with Google Classroom'));
        await tester.pumpAndSettle();

        // Connected status shows connected account
        expect(find.textContaining('Connected as'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
      },
    );

    testWidgets(
      'LmsImportModalSheet displays OAuth SSO button without manual token fields',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const LmsImportModalSheet(),
          ),
        );

        await tester.pumpAndSettle();

        // Platform toggle exists
        expect(find.text('Google Classroom'), findsOneWidget);
        expect(find.text('Canvas LMS'), findsOneWidget);

        // Manual token text fields are REMOVED
        expect(find.text('Canvas API Token'), findsNothing);
        expect(find.text('Google OAuth Token'), findsNothing);
        expect(find.text('Enter API access token'), findsNothing);

        // OAuth SSO button is prominent
        expect(
          find.text('Sign in with Google Classroom'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Secured with OAuth 2.0 PKCE'),
          findsOneWidget,
        );

        // Switch to Canvas platform
        await tester.tap(find.text('Canvas LMS'));
        await tester.pumpAndSettle();

        expect(find.text('Connect with Canvas LMS'), findsOneWidget);
        expect(find.text('Select Institution'), findsOneWidget);
      },
    );

    testWidgets(
      'LmsImportModalSheet renders courses list when loaded',
      (tester) async {
        const tCourses = [
          LmsCourse(
            id: 'c1',
            name: 'Linear Algebra',
            section: 'MAT201',
            platform: 'google_classroom',
          ),
        ];

        when(() => mockBloc.state).thenReturn(
          const IngestionState(lmsCourses: tCourses),
        );

        await tester.pumpWidget(
          createTestApp(
            const LmsImportModalSheet(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Available Courses (1)'), findsOneWidget);
        expect(find.text('Linear Algebra'), findsOneWidget);
        expect(find.text('MAT201 • Classroom'), findsOneWidget);
        expect(find.text('Import'), findsOneWidget);
      },
    );
  });
}
