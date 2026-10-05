import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/decks/presentation/pages/decks_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksBloc extends Mock implements DecksBloc {}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDecksBloc bloc;

  setUp(() {
    bloc = MockDecksBloc();
    when(() => bloc.state).thenReturn(
      const DecksState(
        status: DecksStatus.loading,
      ),
    );
    when(() => bloc.stream).thenAnswer((_) => const Stream<DecksState>.empty());
    registerFallbackValue(const DecksStarted());
    registerFallbackValue(const DecksRefreshed());
    locator.registerSingleton<DecksBloc>(bloc);
  });

  tearDown(() async {
    await locator.reset();
  });

  testWidgets(
    'DecksPage shimmer loading state renders without overflow in height-constrained viewport (284px)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 284);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildTestApp(
          const Scaffold(
            body: DecksPage(),
          ),
        ),
      );
      await tester.pump();

      // Ensure no overflow errors occurred during layout
      expect(tester.takeException(), isNull);
      expect(find.byType(ShimmerPlaceholder), findsWidgets);
    },
  );

  testWidgets(
    'DecksPage shimmer adapts to screen size and renders a grid (Wrap) on wide screens (>= 640px)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildTestApp(
          const Scaffold(
            body: DecksPage(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // On wide screens (>= 640), deck card skeletons are organized in a Wrap grid
      expect(find.byType(Wrap), findsOneWidget);
    },
  );

  testWidgets(
    'DecksPage shimmer adapts to narrow screens (< 640px) without a grid',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildTestApp(
          const Scaffold(
            body: DecksPage(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // On mobile screens (< 640), cards are a simple vertical stack
      expect(find.byType(Wrap), findsNothing);
    },
  );
}
