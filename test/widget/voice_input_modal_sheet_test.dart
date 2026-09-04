import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_cubit.dart';
import 'package:kortex/src/shared/audio/widgets/voice_input_modal_sheet.dart';

void main() {
  group('VoiceInputModalSheet Widget Test Suite', () {
    late AudioWorkspaceCubit cubit;

    setUp(() {
      cubit = AudioWorkspaceCubit();
    });

    tearDown(() async {
      await cubit.close();
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
        home: BlocProvider<AudioWorkspaceCubit>.value(
          value: cubit,
          child: Scaffold(
            body: child,
          ),
        ),
      );
    }

    testWidgets('renders listening banner, wave visualizer, and Done button', (
      tester,
    ) async {
      var transcribedResult = '';

      await tester.pumpWidget(
        createTestApp(
          VoiceInputModalSheet(
            onTranscribed: (text) {
              transcribedResult = text;
            },
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text('Listening... Speak your academic question clearly'),
        findsOneWidget,
      );
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      cubit.updateTranscribedText('Summarize chapter 4');
      await tester.pump();

      expect(find.text('Summarize chapter 4'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(transcribedResult, equals('Summarize chapter 4'));
    });
  });
}
